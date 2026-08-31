#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <set>
#include <filesystem>
#include <thread>
#include <chrono>
#include <cstdio>
#include <cctype>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <algorithm>
#include <sys/wait.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

int parse_int(const std::string& s, int fallback) {
    try {
        return std::stoi(s);
    } catch (...) {
        return fallback;
    }
}

std::vector<std::string> exec_command(const std::string& cmd, int* exit_code = nullptr) {
    std::vector<std::string> lines;
    int status = -1;
    FILE* f = popen(cmd.c_str(), "r");
    if (f) {
        char buffer[2048];
        std::string current_line;
        while (fgets(buffer, sizeof(buffer), f) != nullptr) {
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
        status = pclose(f);
    }
    if (exit_code) {
        *exit_code = (status < 0) ? -1 : WEXITSTATUS(status);
    }
    return lines;
}

bool is_valid_png(const std::string& path) {
    if (!fs::exists(path)) return false;
    std::error_code ec;
    auto sz = fs::file_size(path, ec);
    if (ec || sz == 0) return false;
    std::ifstream f(path, std::ios::binary);
    char magic[4];
    f.read(magic, 4);
    return f.gcount() == 4 && magic[0] == '\x89' && magic[1] == 'P' && magic[2] == 'N' && magic[3] == 'G';
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

    // Only delete files older than an hour so we never race with a
    // concurrent cliphist decode writing a fresh thumbnail.
    auto cutoff = fs::file_time_type::clock::now() - std::chrono::hours(1);
    try {
        if (fs::exists(cache_dir)) {
            for (const auto& entry : fs::directory_iterator(cache_dir)) {
                if (entry.path().extension() == ".png") {
                    std::string iid = entry.path().stem().string();
                    if (valid_ids.find(iid) != valid_ids.end()) continue;
                    try {
                        if (fs::last_write_time(entry.path()) < cutoff) {
                            fs::remove(entry.path());
                        }
                    } catch (...) {}
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
        } else if (std::isdigit(static_cast<unsigned char>(arg1[0]))) {
            offset = parse_int(arg1, 0);
        } else {
            action = arg1;
        }
    }

    if (action == "fetch") {
        if (argc > 2) limit = parse_int(argv[2], limit);
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
    std::vector<std::string> all_lines;
    int cliphist_exit = -1;
    for (int attempt = 0; attempt < 3; ++attempt) {
        all_lines = exec_command("cliphist list", &cliphist_exit);
        if (cliphist_exit == 0) break;
        if (attempt < 2) std::this_thread::sleep_for(std::chrono::milliseconds(60));
    }
    if (cliphist_exit != 0) {
        // Transient failure (e.g. sqlite lock contention). Print nothing and
        // exit non-zero so the QML side can retry.
        return 1;
    }
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

    // Run cleanup synchronously before decoding so it never races with our
    // own thumbnail writes (age gate in cleanup_cache protects concurrent runs).
    if (offset == 0) {
        cleanup_cache(all_lines, cache_dir);
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
            if (!is_valid_png(img_path)) {
                std::remove(img_path.c_str());
                std::string tmp_path = img_path + ".tmp";
                std::string decode_cmd = "cliphist decode " + iid + " > \"" + tmp_path + "\" && mv \"" + tmp_path + "\" \"" + img_path + "\"";
                if (std::system(decode_cmd.c_str()) != 0) {
                    std::remove(tmp_path.c_str());
                }
            }
            display_content = img_path;
        }

        items.push_back({
            {"clipId", iid},
            {"id", iid},
            {"content", display_content},
            {"type", item_type},
            {"pinned", pinned_ids.count(iid) > 0}
        });
    }

    std::cout << json(items).dump() << std::endl;

    return 0;
}

