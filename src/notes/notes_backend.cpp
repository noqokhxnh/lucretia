#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>
#include <filesystem>
#include <chrono>
#include <nlohmann/json.hpp>
#include <cstdlib>

using json = nlohmann::json;
namespace fs = std::filesystem;

std::string get_notes_file_path() {
    const char* home = std::getenv("HOME");
    if (!home) return "notes.json";
    fs::path p = fs::path(home) / ".local/share/quickshell/notes.json";
    return p.string();
}

json load_notes(const std::string& path) {
    if (!fs::exists(path)) return json::array();
    std::ifstream f(path);
    if (!f.is_open()) return json::array();
    try {
        json j;
        f >> j;
        return j;
    } catch (...) {
        return json::array();
    }
}

void save_notes(const std::string& path, const json& notes) {
    fs::create_directories(fs::path(path).parent_path());
    std::ofstream f(path);
    if (f.is_open()) {
        f << notes.dump(2);
    }
}

std::string generate_uuid() {
    std::ifstream f("/proc/sys/kernel/random/uuid");
    std::string uuid;
    if (f >> uuid) return uuid;
    return "manual-uuid-" + std::to_string(std::chrono::system_clock::now().time_since_epoch().count());
}

double get_now() {
    auto now = std::chrono::system_clock::now();
    return std::chrono::duration<double>(now.time_since_epoch()).count();
}

int main(int argc, char* argv[]) {
    if (argc < 2) return 0;

    std::string op = argv[1];
    std::string path = get_notes_file_path();
    json notes = load_notes(path);

    if (op == "list") {
        std::vector<json> sorted_notes = notes.get<std::vector<json>>();
        std::sort(sorted_notes.begin(), sorted_notes.end(), [](const json& a, const json& b) {
            double ta = a.value("updated_at", 0.0);
            double tb = b.value("updated_at", 0.0);
            return ta > tb;
        });
        std::cout << json(sorted_notes).dump() << std::endl;

    } else if (op == "add") {
        std::string id = generate_uuid();
        double now = get_now();
        json new_note = {
            {"id", id},
            {"content", ""},
            {"created_at", now},
            {"updated_at", now}
        };
        notes.push_back(new_note);
        save_notes(path, notes);
        std::cout << id << std::endl;

    } else if (op == "update") {
        if (argc < 4) return 1;
        std::string note_id = argv[2];
        std::string content_file = argv[3];

        std::string content;
        std::ifstream cf(content_file);
        if (cf.is_open()) {
            content.assign((std::istreambuf_iterator<char>(cf)), std::istreambuf_iterator<char>());
        }

        bool found = false;
        for (auto& n : notes) {
            if (n["id"] == note_id) {
                n["content"] = content;
                n["updated_at"] = get_now();
                found = true;
                break;
            }
        }
        if (found) {
            save_notes(path, notes);
        }

    } else if (op == "delete") {
        if (argc < 3) return 1;
        std::string note_id = argv[2];
        json new_notes = json::array();
        for (const auto& n : notes) {
            if (n["id"] != note_id) {
                new_notes.push_back(n);
            }
        }
        save_notes(path, new_notes);
    }

    return 0;
}
