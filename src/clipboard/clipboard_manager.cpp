#include "clipboard_manager.hpp"
#include <QProcess>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <memory>
#include <cstdio>
#include <cstdlib>
#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

static std::vector<std::string> exec_cmd_lines_clip(const std::string& cmd) {
    std::vector<std::string> lines;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen((cmd + " 2>/dev/null").c_str(), "r"), pclose);
    if (!pipe) return lines;
    char buffer[4096];
    std::string current_line;
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        current_line += buffer;
        if (current_line.back() == '\n') {
            current_line.pop_back();
            lines.push_back(current_line);
            current_line.clear();
        }
    }
    if (!current_line.empty()) lines.push_back(current_line);
    return lines;
}

static std::string exec_cmd_sync_clip(const std::string& cmd) {
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen((cmd + " 2>/dev/null").c_str(), "r"), pclose);
    if (!pipe) return "";
    char buffer[4096];
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        result += buffer;
    }
    return result;
}

static bool is_valid_png(const std::string& path) {
    if (!fs::exists(path)) return false;
    std::error_code ec;
    auto sz = fs::file_size(path, ec);
    if (ec || sz == 0) return false;
    std::ifstream f(path, std::ios::binary);
    char magic[4];
    f.read(magic, 4);
    return f.gcount() == 4 && magic[0] == '\x89' && magic[1] == 'P' && magic[2] == 'N' && magic[3] == 'G';
}

ClipboardManager::ClipboardManager(QObject* parent) : QObject(parent) {}

std::set<std::string> ClipboardManager::loadPinned(const QString& cacheDir) {
    std::set<std::string> pinned;
    std::string pinned_path = (fs::path(cacheDir.toStdString()) / "pinned.json").string();
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

QJsonArray ClipboardManager::fetchClipboard(int offset, int limit, const QString& cacheDir) {
    QJsonArray arr;
    std::vector<std::string> all_lines = exec_cmd_lines_clip("cliphist list");
    if (all_lines.empty()) return arr;

    std::set<std::string> pinned_ids = loadPinned(cacheDir);
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
    sorted_lines.insert(sorted_lines.end(), unpinned_lines.begin(), unpinned_lines.end());

    int end = std::min((int)sorted_lines.size(), offset + limit);
    for (int i = offset; i < end; ++i) {
        const std::string& line = sorted_lines[i];
        size_t tab_pos = line.find('\t');
        if (tab_pos == std::string::npos) continue;

        std::string iid = line.substr(0, tab_pos);
        std::string content = line.substr(tab_pos + 1);
        std::string item_type = "text";
        std::string display_content = content;

        if (content.compare(0, 14, "[[ binary data") == 0) {
            std::string img_path = (fs::path(cacheDir.toStdString()) / (iid + ".png")).string();
            if (!is_valid_png(img_path)) {
                std::remove(img_path.c_str());
                std::string tmp_path = img_path + ".tmp";
                std::string decode_cmd = "cliphist decode " + iid + " > \"" + tmp_path + "\" && mv \"" + tmp_path + "\" \"" + img_path + "\"";
                if (std::system(decode_cmd.c_str()) != 0 || !is_valid_png(img_path)) {
                    std::remove(tmp_path.c_str());
                    std::remove(img_path.c_str());
                }
            }
            if (is_valid_png(img_path)) {
                item_type = "image";
                display_content = img_path;
            }
        }

        QJsonObject item;
        item["id"] = QString::fromStdString(iid);
        item["content"] = QString::fromStdString(display_content);
        item["type"] = QString::fromStdString(item_type);
        item["pinned"] = pinned_ids.count(iid) > 0;
        arr.append(item);
    }
    return arr;
}

void ClipboardManager::togglePin(const QString& id, const QString& cacheDir) {
    std::set<std::string> pinned = loadPinned(cacheDir);
    std::string stdId = id.toStdString();
    if (pinned.count(stdId)) {
        pinned.erase(stdId);
    } else {
        pinned.insert(stdId);
    }
    
    std::string pinned_path = (fs::path(cacheDir.toStdString()) / "pinned.json").string();
    try {
        json j = json::array();
        for (const auto& pid : pinned) j.push_back(pid);
        std::ofstream f(pinned_path);
        f << j.dump();
    } catch (...) {}
}

void ClipboardManager::deleteItem(const QString& id) {
    std::vector<std::string> all_lines = exec_cmd_lines_clip("cliphist list");
    std::string line_to_delete;
    std::string stdId = id.toStdString();
    for (const auto& line : all_lines) {
        size_t tab_pos = line.find('\t');
        if (tab_pos != std::string::npos && line.substr(0, tab_pos) == stdId) {
            line_to_delete = line;
            break;
        }
    }
    
    if (!line_to_delete.empty()) {
        auto* proc = new QProcess(this);
        connect(proc, &QProcess::started, proc, [proc, line_to_delete]() {
            proc->write((line_to_delete + "\n").c_str());
            proc->closeWriteChannel();
        });
        connect(proc, &QProcess::finished, proc, &QObject::deleteLater);
        proc->start("cliphist", {"delete"});
    }
}

QString ClipboardManager::decodeItem(const QString& id) {
    std::string res = exec_cmd_sync_clip("cliphist decode " + id.toStdString());
    return QString::fromStdString(res);
}
