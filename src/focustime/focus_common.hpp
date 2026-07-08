#pragma once
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <regex>
#include <sqlite3.h>
#include <nlohmann/json.hpp>

namespace fs = std::filesystem;
using json = nlohmann::json;

namespace focus_common {

struct AppInfo {
    std::string name;
    std::string icon;
};

static std::map<std::string, AppInfo> desktop_cache;
static bool cache_built = false;

inline std::vector<std::string> get_xdg_search_dirs() {
    std::vector<std::string> dirs;
    const char* xdg_data_home = std::getenv("XDG_DATA_HOME");
    if (xdg_data_home) {
        dirs.push_back(std::string(xdg_data_home) + "/applications");
    } else {
        const char* home = std::getenv("HOME");
        if (home) dirs.push_back(std::string(home) + "/.local/share/applications");
    }

    const char* xdg_data_dirs = std::getenv("XDG_DATA_DIRS");
    std::string data_dirs = xdg_data_dirs ? xdg_data_dirs : "/usr/local/share:/usr/share";
    std::stringstream ss(data_dirs);
    std::string segment;
    while (std::getline(ss, segment, ':')) {
        if (!segment.empty()) dirs.push_back(segment + "/applications");
    }

    dirs.push_back("/var/lib/flatpak/exports/share/applications");
    dirs.push_back("/var/lib/snapd/desktop/applications");
    return dirs;
}

inline void build_desktop_cache() {
    if (cache_built) return;
    for (const auto& dir : get_xdg_search_dirs()) {
        if (!fs::exists(dir)) continue;
        try {
            for (const auto& entry : fs::directory_iterator(dir)) {
                if (entry.path().extension() == ".desktop") {
                    std::ifstream file(entry.path());
                    std::string line, name, icon, wmclass;
                    while (std::getline(file, line)) {
                        if (line.starts_with("Name=") && name.empty()) name = line.substr(5);
                        else if (line.starts_with("Icon=") && icon.empty()) icon = line.substr(5);
                        else if (line.starts_with("StartupWMClass=") && wmclass.empty()) {
                            wmclass = line.substr(15);
                            std::transform(wmclass.begin(), wmclass.end(), wmclass.begin(), ::tolower);
                        }
                    }
                    if (!name.empty()) {
                        std::string base = entry.path().stem().string();
                        std::transform(base.begin(), base.end(), base.begin(), ::tolower);
                        desktop_cache[base] = {name, icon};
                        if (!wmclass.empty()) desktop_cache[wmclass] = {name, icon};
                    }
                }
            }
        } catch (...) {}
    }
    cache_built = true;
}

inline std::string resolve_app_name(const std::string& app_class, const std::string& raw_title) {
    if (app_class == "Desktop" || app_class == "Locked" || app_class == "Quickshell" || app_class == "Unknown") return app_class;
    
    build_desktop_cache();
    std::string cls_lower = app_class;
    std::transform(cls_lower.begin(), cls_lower.end(), cls_lower.begin(), ::tolower);
    
    if (desktop_cache.count(cls_lower)) return desktop_cache[cls_lower].name;

    // Fallback: cleaning title
    std::string name = raw_title;
    std::regex re("(\\s+[-—|]\\s+.*)$");
    name = std::regex_replace(name, re, "");
    if (name.length() > 25) return app_class;
    return name;
}

inline std::string get_app_icon(const std::string& app_class) {
    if (app_class == "Desktop" || app_class == "Locked" || app_class == "Quickshell" || app_class == "Unknown") return "";
    build_desktop_cache();
    std::string cls_lower = app_class;
    std::transform(cls_lower.begin(), cls_lower.end(), cls_lower.begin(), ::tolower);
    if (desktop_cache.count(cls_lower)) return desktop_cache[cls_lower].icon;
    return "";
}

inline sqlite3* init_db(const std::string& db_path) {
    sqlite3* db;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK) return nullptr;

    const char* sql = 
        "CREATE TABLE IF NOT EXISTS focus_log (log_date TEXT, app_class TEXT, seconds INTEGER, app_title TEXT, PRIMARY KEY (log_date, app_class));"
        "CREATE INDEX IF NOT EXISTS idx_log_date ON focus_log(log_date);"
        "CREATE TABLE IF NOT EXISTS focus_hourly (log_date TEXT, hour INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, hour, app_class));"
        "CREATE TABLE IF NOT EXISTS focus_intervals (log_date TEXT, interval_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, interval_idx, app_class));"
        "CREATE TABLE IF NOT EXISTS focus_minutes (log_date TEXT, minute_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, minute_idx, app_class));";
    
    char* err_msg = nullptr;
    if (sqlite3_exec(db, sql, nullptr, nullptr, &err_msg) != SQLITE_OK) {
        sqlite3_free(err_msg);
        return nullptr;
    }
    return db;
}

} // namespace focus_common
