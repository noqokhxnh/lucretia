#include "service_manager.hpp"
#include <QProcess>
#include <sstream>
#include <algorithm>
#include <memory>
#include <cstdio>

static std::vector<std::string> exec_cmd_lines(const std::string& cmd) {
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

static std::string trim_service(const std::string& s) {
    auto start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    auto end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

ServiceManager::ServiceManager(QObject* parent) : QObject(parent) {}

QJsonArray ServiceManager::listServices() {
    std::vector<ServiceEntry> services;
    auto fetch = [&](bool is_user) {
        std::string cmd = "systemctl list-units --type=service --all --no-pager --no-legend";
        if (is_user) cmd += " --user";
        std::vector<std::string> lines = exec_cmd_lines(cmd);
        for (const auto& line : lines) {
            if (line.empty()) continue;
            std::stringstream ss(line);
            std::string unit, load, active, sub;
            if (!(ss >> unit >> load >> active >> sub)) continue;
            std::string desc;
            std::getline(ss, desc);
            desc = trim_service(desc);

            if (load == "not-found") continue;
            if (unit.find('@') != std::string::npos && active == "inactive") continue;

            std::string name = unit;
            size_t dot = name.find_last_of('.');
            if (dot != std::string::npos) name = name.substr(0, dot);
            services.push_back({unit, name, load, active, sub, desc.empty() ? name : desc, is_user});
        }
    };

    fetch(true);
    fetch(false);

    std::sort(services.begin(), services.end(), [](const ServiceEntry& a, const ServiceEntry& b) {
        if ((a.active == "active") != (b.active == "active")) {
            return a.active == "active";
        }
        return a.name < b.name;
    });

    QJsonArray arr;
    for (const auto& s : services) {
        QJsonObject sObj;
        sObj["unit"] = QString::fromStdString(s.unit);
        sObj["name"] = QString::fromStdString(s.name);
        sObj["load"] = QString::fromStdString(s.load);
        sObj["active"] = QString::fromStdString(s.active);
        sObj["sub"] = QString::fromStdString(s.sub);
        sObj["desc"] = QString::fromStdString(s.desc);
        sObj["is_user"] = s.is_user;
        arr.append(sObj);
    }
    return arr;
}

void ServiceManager::controlService(const QString& unit, const QString& action, bool isUser) {
    QStringList args;
    if (isUser) args << "--user";
    args << action << unit;
    QProcess::startDetached("systemctl", args);
}
