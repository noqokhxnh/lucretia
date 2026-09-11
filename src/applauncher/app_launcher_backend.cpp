#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <set>
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
    int score = 0;
    bool is_favorite = false;
};

std::string trim(const std::string& s) {
    size_t first = s.find_first_not_of(" \t\r\n");
    if (std::string::npos == first) return s;
    size_t last = s.find_last_not_of(" \t\r\n");
    return s.substr(first, (last - first + 1));
}

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
    return trim(exec);
}

std::string strip_icon_ext(std::string icon) {
    icon = trim(icon);
    if (icon.empty()) return icon;
    // Absolute or relative paths with a directory separator: leave as-is.
    // Only strip extensions from plain icon names (no slashes) so that
    // paths like /usr/share/icons/hicolor/scalable/apps/firefox.svg are
    // preserved and can be loaded via file:// in QML.
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
        line = trim(line);
        if (line.empty() || line[0] == '#') continue;
        
        if (line[0] == '[') {
            is_desktop = (line == "[Desktop Entry]");
            continue;
        }

        if (is_desktop) {
            size_t sep = line.find('=');
            if (sep == std::string::npos) continue;
            
            std::string key = line.substr(0, sep);
            std::string value = line.substr(sep + 1);

            if (key == "Name" && app.name.empty()) {
                app.name = trim(value);
            } else if (key == "Exec" && app.exec.empty()) {
                app.exec = strip_placeholders(value);
            } else if (key == "Icon" && app.icon.empty()) {
                std::string raw_icon = trim(value);
                if (raw_icon.size() > 0 && raw_icon[0] == '~') {
                    app.icon = expand_home(raw_icon);
                } else {
                    app.icon = strip_icon_ext(raw_icon);
                }
            } else if (key == "NoDisplay") {
                if (value == "true" || value == "1") no_display = true;
            }
        }
    }

    if (!app.name.empty() && !app.exec.empty() && !no_display) {
        // Use filename as a fallback unique ID to prevent name collisions from hiding apps
        // but prioritize existing entries if they are already in the map (handled by dir order)
        if (apps.find(app.name) == apps.end()) {
            apps[app.name] = app;
        }
    }
}

std::string to_lower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
    return s;
}

int fuzzy_score(const std::string& name, const std::string& exec, const std::string& query) {
    if (query.empty()) return 0;
    std::string n = to_lower(name);
    std::string q = to_lower(query);
    
    int score = 0;
    
    // Primary matches (Name)
    if (n == q) score += 2000;
    else if (n.find(q) == 0) score += 1500 + (q.length() * 10);
    else if (n.find(" " + q) != std::string::npos) score += 1200 + (q.length() * 5);
    else if (n.find(q) != std::string::npos) score += 1000 + q.length();
    
    // Fuzzy match character sequence
    int fuzzyScore = 0;
    int lastIdx = -1;
    bool match = true;
    for (size_t i = 0; i < q.length(); i++) {
        size_t idx = n.find(q[i], lastIdx + 1);
        if (idx == std::string::npos) {
            match = false;
            break;
        }
        if (lastIdx != -1) {
            int dist = idx - lastIdx;
            if (dist == 1) fuzzyScore += 50; 
            else fuzzyScore += std::max(0, 30 - dist);
        } else {
            if (idx == 0) fuzzyScore += 100;
        }
        lastIdx = idx;
    }
    
    if (!match) return score > 0 ? score : 0;
    return score + fuzzyScore;
}

int main(int argc, char* argv[]) {
    // Priority: User > Nix/Flatpak > System
    std::vector<std::string> dirs = {
        "~/.local/share/applications",
        "~/.local/share/flatpak/exports/share/applications",
        "~/.nix-profile/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications",
        "/var/lib/flatpak/exports/share/applications",
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

    // Load favorites and hidden apps from settings cache
    std::set<std::string> favorites;
    std::set<std::string> hidden;
    const char* home = std::getenv("HOME");
    if (home) {
        fs::path settingsPath = fs::path(home) / ".cache/applauncher_settings.json";
        if (fs::exists(settingsPath)) {
            try {
                std::ifstream sf(settingsPath);
                if (sf.is_open()) {
                    json sj;
                    sf >> sj;
                    if (sj.contains("favorites") && sj["favorites"].is_array()) {
                        for (const auto& fav : sj["favorites"]) {
                            if (fav.is_string()) favorites.insert(fav.get<std::string>());
                        }
                    }
                    if (sj.contains("hidden") && sj["hidden"].is_array()) {
                        for (const auto& hid : sj["hidden"]) {
                            if (hid.is_string()) hidden.insert(hid.get<std::string>());
                        }
                    }
                }
            } catch (...) {}
        }
    }

    std::vector<AppInfo> allApps;
    for (auto const& [name, info] : apps) {
        if (hidden.count(info.name)) continue;
        AppInfo item = info;
        item.is_favorite = (favorites.count(info.name) > 0);
        allApps.push_back(item);
    }

    if (argc > 1) {
        std::string query = argv[1];
        if (query == "--list") {
            std::sort(allApps.begin(), allApps.end(), [](const AppInfo& a, const AppInfo& b) {
                if (a.is_favorite != b.is_favorite) return a.is_favorite > b.is_favorite;
                return a.name < b.name;
            });
            json res = json::array();
            for (const auto& app : allApps) {
                res.push_back({
                    {"name", app.name},
                    {"exec", app.exec},
                    {"icon", app.icon},
                    {"is_favorite", app.is_favorite},
                    {"pinned", app.is_favorite}
                });
            }
            std::cout << res.dump() << std::endl;
            return 0;
        }

        std::vector<AppInfo> results;
        for (const auto& app : allApps) {
            int score = fuzzy_score(app.name, app.exec, query);
            if (score > 0) {
                AppInfo res = app;
                res.score = score + (app.is_favorite ? 10000 : 0);
                results.push_back(res);
            }
        }
        std::sort(results.begin(), results.end(), [](const AppInfo& a, const AppInfo& b) {
            return a.score > b.score;
        });
        json res = json::array();
        for (const auto& app : results) {
            res.push_back({
                {"name", app.name},
                {"exec", app.exec},
                {"icon", app.icon},
                {"score", app.score},
                {"is_favorite", app.is_favorite},
                {"pinned", app.is_favorite}
            });
        }
        std::cout << res.dump() << std::endl;
        return 0;
    }

    return 0;
}