#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <set>
#include <filesystem>
#include <thread>
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <algorithm>
#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

std::vector<std::string> exec_command(const std::string& cmd) {
    std::vector<std::string> lines;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) {
        return lines;
    }
    char buffer[2048];
    std::string current_line;
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        current_line += buffer;
        if (current_line.back() == '\n') {
            current_line.pop_back();
            lines.push_back(current_line);
            current_line.clear();
        }
    }
    if (!current_line.empty()) {
        lines.push_back(current_line);
    }
    return lines;
}

void cleanup_cache(const std::vector<std::string>& all_lines, const std::string& cache_dir) {
    std::set<std::string> valid_ids;
    size_t count = 0;
    for (const auto& line : all_lines) {
        if (count >= 200) break; // Keep more cache than fetch limit
        size_t tab_pos = line.find('\t');
        if (tab_pos != std::string::npos) {
            valid_ids.insert(line.substr(0, tab_pos));
            count++;
        }
    }

    try {
        if (fs::exists(cache_dir)) {
            for (const auto& entry : fs::directory_iterator(cache_dir)) {
                if (entry.path().extension() == ".png") {
                    std::string iid = entry.path().stem().string();
                    if (valid_ids.find(iid) == valid_ids.end()) {
                        fs::remove(entry.path());
                    }
                }
            }
        }
    } catch (...) {}
}

std::set<std::string> load_pinned(const std::string& cache_dir) {
    std::set<std::string> pinned;
    std::string pinned_path = (fs::path(cache_dir) / "pinned.json").string();
    if (fs::exists(pinned_path)) {
        try {
            std::ifstream f(pinned_path);
            json j;
            f >> j;
            if (j.is_array()) {
                for (const auto& id : j) {
                    if (id.is_string()) pinned.insert(id.get<std::string>());
                }
            }
        } catch (...) {}
    }
    return pinned;
}

void save_pinned(const std::string& cache_dir, const std::set<std::string>& pinned) {
    std::string pinned_path = (fs::path(cache_dir) / "pinned.json").string();
    try {
        json j = json::array();
        for (const auto& id : pinned) {
            j.push_back(id);
        }
        std::ofstream f(pinned_path);
        f << j.dump();
    } catch (...) {}
}

int main(int argc, char* argv[]) {
    std::string action = "fetch";
    int offset = 0;
    int limit = 24;
    std::string cache_dir;

    if (argc > 1) {
        std::string arg1 = argv[1];
        if (arg1 == "toggle-pin") {
            action = "toggle-pin";
        } else if (isdigit(arg1[0])) {
            offset = std::stoi(arg1);
        } else {
            action = arg1;
        }
    }

    if (action == "fetch") {
        if (argc > 2) limit = std::stoi(argv[2]);
        if (argc > 3) cache_dir = argv[3];
    } else if (action == "toggle-pin" || action == "delete") {
        if (argc > 3) cache_dir = argv[3];
    }

    if (cache_dir.empty()) {
        const char* qs_cache = std::getenv("QS_CACHE_CLIPBOARD");
        if (qs_cache) {
            cache_dir = qs_cache;
        } else {
            const char* home = std::getenv("HOME");
            if (home) {
                cache_dir = std::string(home) + "/.cache/quickshell/clipboard";
            } else {
                cache_dir = "/tmp/quickshell/clipboard";
            }
        }
    }

    try {
        fs::create_directories(cache_dir);
    } catch (...) {}

    if (action == "toggle-pin") {
        if (argc < 3) return 1;
        std::string id = argv[2];
        std::set<std::string> pinned = load_pinned(cache_dir);
        if (pinned.count(id)) {
            pinned.erase(id);
        } else {
            pinned.insert(id);
        }
        save_pinned(cache_dir, pinned);
        std::cout << "{\"status\":\"ok\"}" << std::endl;
        return 0;
    } else if (action == "delete") {
        if (argc < 3) return 1;
        std::string id = argv[2];
        std::vector<std::string> all_lines = exec_command("cliphist list");
        std::string line_to_delete;
        for (const auto& line : all_lines) {
            size_t tab_pos = line.find('\t');
            if (tab_pos != std::string::npos && line.substr(0, tab_pos) == id) {
                line_to_delete = line;
                break;
            }
        }
        
        if (!line_to_delete.empty()) {
            std::unique_ptr<FILE, decltype(&pclose)> pipe(popen("cliphist delete", "w"), pclose);
            if (pipe) {
                line_to_delete += "\n";
                fputs(line_to_delete.c_str(), pipe.get());
            }
        }
        std::cout << "{\"status\":\"ok\"}" << std::endl;
        return 0;
    }

    // Default fetch action
    std::vector<std::string> all_lines = exec_command("cliphist list");
    if (all_lines.empty()) {
        std::cout << "[]" << std::endl;
        return 0;
    }

    std::set<std::string> pinned_ids = load_pinned(cache_dir);
    
    // Separate pinned and unpinned
    std::vector<std::string> sorted_lines;
    std::vector<std::string> unpinned_lines;
    
    for (const auto& line : all_lines) {
        size_t tab_pos = line.find('\t');
        if (tab_pos == std::string::npos) continue;
        std::string id = line.substr(0, tab_pos);
        if (pinned_ids.count(id)) {
            sorted_lines.push_back(line);
        } else {
            unpinned_lines.push_back(line);
        }
    }
    
    // Combine: pinned first, then unpinned
    sorted_lines.insert(sorted_lines.end(), unpinned_lines.begin(), unpinned_lines.end());

    // Launch cleanup thread if offset is 0
    if (offset == 0) {
        std::thread(cleanup_cache, all_lines, cache_dir).detach();
    }

    std::vector<json> items;
    int end = std::min((int)sorted_lines.size(), offset + limit);
    for (int i = offset; i < end; ++i) {
        const std::string& line = sorted_lines[i];
        size_t tab_pos = line.find('\t');
        if (tab_pos == std::string::npos) continue;

        std::string iid = line.substr(0, tab_pos);
        std::string content = line.substr(tab_pos + 1);
        std::string item_type = "text";
        std::string display_content = content;

        if (content.find("[[ binary data") != std::string::npos) {
            item_type = "image";
            std::string img_path = (fs::path(cache_dir) / (iid + ".png")).string();
            if (!fs::exists(img_path)) {
                std::string decode_cmd = "cliphist decode " + iid + " > \"" + img_path + "\"";
                std::system(decode_cmd.c_str());
            }
            display_content = img_path;
        }

        items.push_back({
            {"id", iid},
            {"content", display_content},
            {"type", item_type},
            {"pinned", pinned_ids.count(iid) > 0}
        });
    }

    std::cout << json(items).dump() << std::endl;

    return 0;
}

