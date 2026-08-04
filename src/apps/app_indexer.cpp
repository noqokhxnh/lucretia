#include "app_indexer.hpp"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <filesystem>
#include <cctype>

namespace fs = std::filesystem;

static std::string trim_str(const std::string& s) {
    auto start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    auto end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

static std::string to_lower_str(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
    return s;
}

AppIndexer::AppIndexer(QObject* parent) : QObject(parent) {
    scanDesktopApps();
}

void AppIndexer::scanDesktopApps() {
    desktopApps.clear();
    std::map<std::string, DesktopApp> appsMap;

    std::vector<fs::path> dirs = {
        "/usr/share/applications",
        "/usr/local/share/applications",
        fs::path(getenv("HOME") ? getenv("HOME") : "") / ".local/share/applications"
    };

    auto stripIconExt = [](std::string icon) {
        icon = trim_str(icon);
        if (icon.empty()) return icon;
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
    };

    for (const auto& dirPath : dirs) {
        if (!fs::exists(dirPath)) continue;
        for (const auto& entry : fs::directory_iterator(dirPath)) {
            if (entry.is_regular_file() && entry.path().extension() == ".desktop") {
                std::ifstream file(entry.path());
                if (!file.is_open()) continue;

                DesktopApp app;
                bool is_desktop = false;
                bool no_display = false;
                std::string line;

                while (std::getline(file, line)) {
                    line = trim_str(line);
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
                            app.name = trim_str(value);
                        } else if (key == "Exec" && app.exec.empty()) {
                            std::string exec = trim_str(value);
                            size_t pos = exec.find(" %");
                            if (pos != std::string::npos) exec = exec.substr(0, pos);
                            pos = exec.find(" @@");
                            if (pos != std::string::npos) exec = exec.substr(0, pos);
                            app.exec = trim_str(exec);
                        } else if (key == "Icon" && app.icon.empty()) {
                            std::string raw_icon = trim_str(value);
                            app.icon = stripIconExt(raw_icon);
                        } else if (key == "NoDisplay") {
                            if (value == "true" || value == "1") no_display = true;
                        }
                    }
                }

                if (!app.name.empty() && !app.exec.empty() && !no_display) {
                    if (appsMap.find(app.name) == appsMap.end()) {
                        appsMap[app.name] = app;
                    }
                }
            }
        }
    }

    for (const auto& pair : appsMap) {
        desktopApps.push_back(pair.second);
    }
}

int AppIndexer::computeFuzzyScore(const std::string& name, const std::string& query) {
    if (query.empty()) return 0;
    std::string n = to_lower_str(name);
    std::string q = to_lower_str(query);
    
    int score = 0;
    if (n == q) score += 2000;
    else if (n.find(q) == 0) score += 1500 + (q.length() * 10);
    else if (n.find(" " + q) != std::string::npos) score += 1200 + (q.length() * 5);
    else if (n.find(q) != std::string::npos) score += 1000 + q.length();
    
    int fuzzy = 0;
    int lastIdx = -1;
    bool match = true;
    for (size_t i = 0; i < q.length(); i++) {
        size_t idx = n.find(q[i], lastIdx + 1);
        if (idx == std::string::npos) { match = false; break; }
        if (lastIdx != -1) {
            int dist = idx - lastIdx;
            if (dist == 1) fuzzy += 50; 
            else fuzzy += std::max(0, 30 - dist);
        } else {
            if (idx == 0) fuzzy += 100;
        }
        lastIdx = idx;
    }
    if (!match) return score > 0 ? score : 0;
    return score + fuzzy;
}

QJsonArray AppIndexer::searchApps(const QString& query) {
    if (desktopApps.empty()) {
        scanDesktopApps();
    }
    QJsonArray arr;
    if (query == "--list") {
        for (const auto& app : desktopApps) {
            QJsonObject o;
            o["name"] = QString::fromStdString(app.name);
            o["exec"] = QString::fromStdString(app.exec);
            o["icon"] = QString::fromStdString(app.icon);
            arr.append(o);
        }
        return arr;
    }

    struct ScoreApp {
        DesktopApp app;
        int score;
    };
    std::vector<ScoreApp> results;
    std::string stdQuery = query.toStdString();
    for (const auto& app : desktopApps) {
        int score = computeFuzzyScore(app.name, stdQuery);
        if (score > 0) {
            results.push_back({app, score});
        }
    }
    
    std::sort(results.begin(), results.end(), [](const ScoreApp& a, const ScoreApp& b) {
        return a.score > b.score;
    });

    for (const auto& r : results) {
        QJsonObject o;
        o["name"] = QString::fromStdString(r.app.name);
        o["exec"] = QString::fromStdString(r.app.exec);
        o["icon"] = QString::fromStdString(r.app.icon);
        o["score"] = r.score;
        arr.append(o);
    }
    return arr;
}
