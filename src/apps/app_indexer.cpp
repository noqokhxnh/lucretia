#include "app_indexer.hpp"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <filesystem>
#include <cctype>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

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

#include <QDateTime>

void AppIndexer::scanDesktopApps() {
    desktopApps.clear();
    std::map<std::string, DesktopApp> appsMap;

    std::vector<fs::path> dirs = {
        "/usr/share/applications",
        "/usr/local/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        fs::path(getenv("HOME") ? getenv("HOME") : "") / ".local/share/applications",
        fs::path(getenv("HOME") ? getenv("HOME") : "") / ".local/share/flatpak/exports/share/applications"
    };

    const char* xdgDataDirs = getenv("XDG_DATA_DIRS");
    if (xdgDataDirs) {
        std::stringstream ss(xdgDataDirs);
        std::string item;
        while (std::getline(ss, item, ':')) {
            if (!item.empty()) {
                dirs.push_back(fs::path(item) / "applications");
            }
        }
    }

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
        std::error_code ec;
        if (!fs::exists(dirPath, ec)) continue;
        for (const auto& entry : fs::directory_iterator(dirPath, ec)) {
            if (ec) break;
            if (entry.is_regular_file(ec) && entry.path().extension() == ".desktop") {
                std::ifstream file(entry.path());
                if (!file.is_open()) continue;

                DesktopApp app;
                app.desktopFile = entry.path().filename().string();
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
                        } else if (key == "Keywords" && app.keywords.empty()) {
                            app.keywords = trim_str(value);
                        } else if (key == "Comment" && app.comment.empty()) {
                            app.comment = trim_str(value);
                        } else if (key == "Categories" && app.categories.empty()) {
                            app.categories = trim_str(value);
                        } else if (key == "Terminal") {
                            std::string val = to_lower_str(trim_str(value));
                            if (val == "true" || val == "1") app.terminal = true;
                        } else if (key == "NoDisplay") {
                            std::string val = to_lower_str(trim_str(value));
                            if (val == "true" || val == "1") no_display = true;
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

std::vector<RunningWindowInfo> AppIndexer::fetchNiriWindows() {
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - lastNiriFetchTime < 1000 && !cachedWindows.empty()) {
        return cachedWindows;
    }

    std::vector<RunningWindowInfo> windows;
    QProcess proc;
    proc.start("niri", QStringList() << "msg" << "-j" << "windows");
    if (proc.waitForFinished(200)) {
        QByteArray output = proc.readAllStandardOutput();
        QJsonDocument doc = QJsonDocument::fromJson(output);
        if (doc.isArray()) {
            QJsonArray arr = doc.array();
            for (const auto& val : arr) {
                QJsonObject o = val.toObject();
                RunningWindowInfo info;
                info.id = o["id"].toInt(-1);
                info.appId = o["app_id"].toString().toLower().toStdString();
                info.title = o["title"].toString().toStdString();
                info.workspaceId = o["workspace_id"].toInt(1);
                if (info.id != -1) {
                    windows.push_back(info);
                }
            }
        }
    }
    cachedWindows = windows;
    lastNiriFetchTime = now;
    return windows;
}

int AppIndexer::computeFuzzyScore(const DesktopApp& app, const std::string& query) {
    if (query.empty()) return 0;
    std::string n = to_lower_str(app.name);
    std::string q = to_lower_str(query);
    std::string e = to_lower_str(app.exec);
    std::string kw = to_lower_str(app.keywords);
    std::string cat = to_lower_str(app.categories);

    int score = 0;

    // Exact or Prefix Match on Name
    if (n == q) score += 3000;
    else if (n.find(q) == 0) score += 2000 + (q.length() * 10);
    else if (n.find(" " + q) != std::string::npos) score += 1600 + (q.length() * 5);
    else if (n.find(q) != std::string::npos) score += 1200 + q.length();

    // Acronym / Initials Matching (e.g., "vsc" -> "Visual Studio Code")
    std::string initials = "";
    std::stringstream ss(n);
    std::string word;
    while (ss >> word) {
        if (!word.empty()) initials += word[0];
    }
    if (!initials.empty() && initials.find(q) == 0) {
        score += 1800;
    }

    // Match on Exec / Desktop file
    if (e.find(q) == 0) score += 1000;
    else if (e.find(q) != std::string::npos) score += 600;

    // Match on Keywords / Categories
    if (!kw.empty() && kw.find(q) != std::string::npos) score += 800;
    if (!cat.empty() && cat.find(q) != std::string::npos) score += 400;

    // Subsequence fuzzy search fallback
    int fuzzy = 0;
    int lastIdx = -1;
    bool match = true;
    for (size_t i = 0; i < q.length(); i++) {
        size_t idx = n.find(q[i], lastIdx + 1);
        if (idx == std::string::npos) { match = false; break; }
        if (lastIdx != -1) {
            int dist = idx - lastIdx;
            if (dist == 1) fuzzy += 40; 
            else fuzzy += std::max(0, 20 - dist);
        } else {
            if (idx == 0) fuzzy += 80;
        }
        lastIdx = idx;
    }

    if (score == 0 && !match) return 0;
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
            o["terminal"] = app.terminal;
            arr.append(o);
        }
        return arr;
    }

    std::vector<RunningWindowInfo> runningWins = fetchNiriWindows();

    struct ScoreApp {
        DesktopApp app;
        int score;
        bool isRunning = false;
        int runningWindowId = -1;
        int runningWorkspaceId = -1;
    };
    std::vector<ScoreApp> results;
    std::string stdQuery = query.toStdString();

    for (const auto& app : desktopApps) {
        int score = computeFuzzyScore(app, stdQuery);
        if (score > 0) {
            ScoreApp sa;
            sa.app = app;
            sa.score = score;

            std::string lowerExec = to_lower_str(app.exec);
            std::string lowerName = to_lower_str(app.name);

            // Match running window
            for (const auto& win : runningWins) {
                if (!win.appId.empty() && 
                    (lowerExec.find(win.appId) != std::string::npos || 
                     win.appId.find(lowerName) != std::string::npos ||
                     lowerName.find(win.appId) != std::string::npos)) {
                    sa.isRunning = true;
                    sa.runningWindowId = win.id;
                    sa.runningWorkspaceId = win.workspaceId;
                    sa.score += 500; // Boost running app score
                    break;
                }
            }

            results.push_back(sa);
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
        o["terminal"] = r.app.terminal;
        o["is_running"] = r.isRunning;
        if (r.isRunning) {
            o["running_window_id"] = r.runningWindowId;
            o["running_workspace_id"] = r.runningWorkspaceId;
        }
        arr.append(o);
    }
    return arr;
}

