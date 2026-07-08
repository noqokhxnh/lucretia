#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <filesystem>
#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

struct AppInfo {
    std::string name;
    std::string exec;
    std::string icon;
};

std::string expand_home(std::string path) {
    if (!path.empty() && path[0] == '~') {
        const char* home = std::getenv("HOME");
        if (home) {
            return std::string(home) + path.substr(1);
        }
    }
    return path;
}

std::string strip_placeholders(std::string exec) {
    size_t pos = exec.find(" %");
    if (pos != std::string::npos) exec = exec.substr(0, pos);
    pos = exec.find(" @@");
    if (pos != std::string::npos) exec = exec.substr(0, pos);
    return exec;
}

std::string strip_icon_ext(std::string icon) {
    if (icon.empty()) return icon;
    // Absolute or relative paths with a directory separator: leave as-is.
    if (icon[0] == '/' || icon.find('/') != std::string::npos) return icon;
    std::vector<std::string> exts = {".png", ".svg", ".xpm", ".ico"};
    for (const auto& ext : exts) {
        if (icon.size() > ext.size() && 
            std::equal(ext.rbegin(), ext.rend(), icon.rbegin(), [](char a, char b) {
                return std::tolower(a) == std::tolower(b);
            })) {
            return icon.substr(0, icon.size() - ext.size());
        }
    }
    return icon;
}

void parse_desktop_file(const fs::path& path, std::map<std::string, AppInfo>& apps) {
    std::ifstream file(path);
    if (!file.is_open()) return;

    AppInfo app;
    bool is_desktop = false;
    bool no_display = false;
    std::string line;

    while (std::getline(file, line)) {
        if (line.empty()) continue;
        if (line[0] == '[') {
            is_desktop = (line == "[Desktop Entry]");
            continue;
        }

        if (is_desktop) {
            if (line.compare(0, 5, "Name=") == 0 && app.name.empty()) {
                app.name = line.substr(5);
            } else if (line.compare(0, 5, "Exec=") == 0 && app.exec.empty()) {
                app.exec = strip_placeholders(line.substr(5));
            } else if (line.compare(0, 5, "Icon=") == 0 && app.icon.empty()) {
                app.icon = strip_icon_ext(line.substr(5));
            } else if (line == "NoDisplay=true" || line == "NoDisplay=1") {
                no_display = true;
            }
        }
    }

    if (!app.name.empty() && !app.exec.empty() && !no_display) {
        if (apps.find(app.name) == apps.end()) {
            apps[app.name] = app;
        }
    }
}

int main() {
    std::vector<std::string> dirs = {
        "/usr/share/applications",
        "/usr/local/share/applications",
        "~/.local/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        "~/.local/share/flatpak/exports/share/applications",
        "~/.nix-profile/share/applications",
        "/run/current-system/sw/share/applications"
    };

    std::map<std::string, AppInfo> apps;

    for (auto& d : dirs) {
        fs::path p = expand_home(d);
        if (!fs::exists(p)) continue;

        try {
            for (const auto& entry : fs::recursive_directory_iterator(p)) {
                if (entry.path().extension() == ".desktop") {
                    parse_desktop_file(entry.path(), apps);
                }
            }
        } catch (...) {}
    }

    std::vector<json> res;
    for (const auto& pair : apps) {
        res.push_back({
            {"name", pair.second.name},
            {"exec", pair.second.exec},
            {"icon", pair.second.icon}
        });
    }

    // Map is already sorted by key (name)
    std::cout << json(res).dump() << std::endl;

    return 0;
}
