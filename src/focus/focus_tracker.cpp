#include "focus_tracker.hpp"
#include <QTimer>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <cmath>
#include <chrono>
#include <ctime>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

FocusService::FocusService(QObject* parent) : QObject(parent), db(nullptr) {
    std::string db_dir = std::getenv("QS_STATE_FOCUSTIME") ? std::getenv("QS_STATE_FOCUSTIME") : 
                         std::string(std::getenv("HOME")) + "/.local/state/quickshell/focustime";
    fs::create_directories(db_dir);
    db_path = db_dir + "/focustime.db";
    db = focus_common::init_db(db_path);

    run_dir = std::getenv("QS_RUN_FOCUSTIME") ? std::getenv("QS_RUN_FOCUSTIME") : "/tmp/quickshell/focustime";
    fs::create_directories(run_dir);

    // Initial active window query
    updateActiveWindow();

    // Start Niri listener socket thread
    daemon_thread = std::thread([this]() {
        this->daemonLoop();
    });

    // Start logging logic timer (every 1 second)
    QTimer* timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, [this]() {
        auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        std::tm* now_tm = std::localtime(&now);
        char date_buf[16];
        std::strftime(date_buf, sizeof(date_buf), "%Y-%m-%d", now_tm);
        
        LogEntry entry;
        {
            std::lock_guard<std::mutex> lock(state_mutex);
            entry = {date_buf, now_tm->tm_hour, current_class, current_title, 1};
        }
        
        bool need_flush = false;
        if (!entry.app_class.empty() && entry.app_class != "Locked") {
            std::lock_guard<std::mutex> lock(buf_mutex);
            buffer.push_back(entry);
            if (buffer.size() >= 15) {
                need_flush = true;
            }
        }

        if (need_flush) {
            flushBuffer();
        }
    });
    timer->start(1000);
}

FocusService::~FocusService() {
    stop_daemon = true;
    if (daemon_thread.joinable()) {
        daemon_thread.detach();
    }
    flushBuffer();
    if (db) sqlite3_close(db);
}

std::string FocusService::getNiriSocketPath() {
    const char* niri_socket = std::getenv("NIRI_SOCKET");
    if (niri_socket && fs::exists(niri_socket)) return niri_socket;

    uid_t uid = getuid();
    std::string run_user = "/run/user/" + std::to_string(uid);
    if (fs::exists(run_user)) {
        try {
            for (const auto& entry : fs::directory_iterator(run_user)) {
                std::string filename = entry.path().filename().string();
                if (filename.rfind("niri", 0) == 0 && entry.path().extension() == ".sock") {
                    return entry.path().string();
                }
            }
        } catch (...) {}
    }
    return "";
}

bool FocusService::isLocked() {
    return system("pgrep -f '[L]ock.qml' > /dev/null") == 0;
}

void FocusService::updateActiveWindow() {
    if (isLocked()) {
        std::lock_guard<std::mutex> lock(state_mutex);
        current_class = "Locked";
        current_title = "Locked";
        return;
    }

    std::string sock_path = getNiriSocketPath();
    if (sock_path.empty()) {
        std::lock_guard<std::mutex> lock(state_mutex);
        current_class = "Desktop";
        current_title = "Desktop";
        return;
    }

    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) return;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sock_path.c_str(), sizeof(addr.sun_path) - 1);

    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&tv, sizeof(tv));

    if (::connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return;
    }

    std::string req = "\"FocusedWindow\"\n";
    if (send(sock, req.c_str(), req.length(), 0) < 0) {
        close(sock);
        return;
    }

    char buf[4096];
    std::string response = "";
    ssize_t n = recv(sock, buf, sizeof(buf) - 1, 0);
    if (n > 0) {
        buf[n] = '\0';
        response = buf;
    }
    close(sock);

    if (response.empty()) return;

    try {
        auto data = json::parse(response);
        if (data.contains("Ok") && data["Ok"].contains("FocusedWindow")) {
            auto focused = data["Ok"]["FocusedWindow"];
            if (focused.is_null()) {
                std::lock_guard<std::mutex> lock(state_mutex);
                current_class = "Desktop";
                current_title = "Desktop";
            } else {
                std::string cls = focused.value("app_id", "");
                if (cls.empty()) cls = "Unknown";
                std::string title = focused.value("title", "");
                if (title.empty()) title = cls;

                if (cls.find("quickshell") != std::string::npos) {
                    cls = "Quickshell";
                    title = "Quickshell";
                }
                std::string clean_title = focus_common::resolve_app_name(cls, title);
                std::lock_guard<std::mutex> lock(state_mutex);
                current_class = cls;
                current_title = clean_title;
            }
        }
    } catch (...) {
    }
}

void FocusService::daemonLoop() {
    updateActiveWindow();

    while (!stop_daemon) {
        std::string sock_path = getNiriSocketPath();
        if (sock_path.empty()) {
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        int sock = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sock < 0) {
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        struct sockaddr_un addr;
        memset(&addr, 0, sizeof(addr));
        addr.sun_family = AF_UNIX;
        strncpy(addr.sun_path, sock_path.c_str(), sizeof(addr.sun_path) - 1);

        if (::connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            close(sock);
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        std::string req = "\"EventStream\"\n";
        if (send(sock, req.c_str(), req.length(), 0) < 0) {
            close(sock);
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        char buf[4096];
        std::string stream_data = "";
        while (!stop_daemon) {
            ssize_t n = recv(sock, buf, sizeof(buf) - 1, 0);
            if (n <= 0) break;
            buf[n] = '\0';
            stream_data += buf;

            size_t pos;
            while ((pos = stream_data.find('\n')) != std::string::npos) {
                std::string line = stream_data.substr(0, pos);
                stream_data.erase(0, pos + 1);

                if (!line.empty()) {
                    if (line.find("WindowFocusChanged") != std::string::npos ||
                        line.find("WindowOpenedOrChanged") != std::string::npos ||
                        line.find("WindowClosed") != std::string::npos ||
                        line.find("WorkspaceActivated") != std::string::npos ||
                        line.find("WorkspacesChanged") != std::string::npos) {
                        updateActiveWindow();
                    }
                }
            }
        }
        close(sock);
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

void FocusService::flushBuffer() {
    if (!db) return;
    std::vector<LogEntry> entries;
    {
        std::lock_guard<std::mutex> lock(buf_mutex);
        if (buffer.empty()) return;
        entries = std::move(buffer);
        buffer.clear();
    }

    std::map<std::pair<std::string, std::string>, int> daily;
    std::map<std::tuple<std::string, int, std::string>, int> hourly;
    std::map<std::pair<std::string, std::string>, std::string> titles;
    for (const auto& e : entries) {
        daily[{e.date, e.app_class}] += e.seconds;
        hourly[{e.date, e.hour, e.app_class}] += e.seconds;
        if (!e.app_title.empty()) {
            titles[{e.date, e.app_class}] = e.app_title;
        }
    }

    sqlite3_exec(db, "BEGIN TRANSACTION;", nullptr, nullptr, nullptr);
    for (auto const& [key, secs] : daily) {
        std::string title = titles.count(key) ? titles[key] : key.second;
        sqlite3_stmt* stmt;
        sqlite3_prepare_v2(db, "INSERT INTO focus_log (log_date, app_class, seconds, app_title) VALUES (?, ?, ?, ?) ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?, app_title = excluded.app_title", -1, &stmt, nullptr);
        sqlite3_bind_text(stmt, 1, key.first.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, key.second.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 3, secs);
        sqlite3_bind_text(stmt, 4, title.c_str(), -1, SQLITE_STATIC); 
        sqlite3_bind_int(stmt, 5, secs);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    for (auto const& [key, secs] : hourly) {
        sqlite3_stmt* stmt;
        sqlite3_prepare_v2(db, "INSERT INTO focus_hourly (log_date, hour, app_class, seconds) VALUES (?, ?, ?, ?) ON CONFLICT(log_date, hour, app_class) DO UPDATE SET seconds = seconds + ?", -1, &stmt, nullptr);
        sqlite3_bind_text(stmt, 1, std::get<0>(key).c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 2, std::get<1>(key));
        sqlite3_bind_text(stmt, 3, std::get<2>(key).c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_int(stmt, 4, secs);
        sqlite3_bind_int(stmt, 5, secs);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    sqlite3_exec(db, "COMMIT;", nullptr, nullptr, nullptr);
}

QJsonObject FocusService::handleStats(const QJsonObject& req) {
    QJsonObject root;
    if (!db) return root;

    flushBuffer();

    QString dateStr = req.value("date").toString();
    QString appFilter = req.value("app").toString();

    std::string app_filter_std = appFilter.toStdString();
    std::string target_date_str = dateStr.toStdString();
    if (target_date_str.empty()) {
        auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        std::tm tm = *std::localtime(&now);
        std::ostringstream oss;
        oss << std::put_time(&tm, "%Y-%m-%d");
        target_date_str = oss.str();
    }

    auto from_iso_date = [](const std::string& ds) {
        std::tm tm = {};
        std::istringstream iss(ds);
        iss >> std::get_time(&tm, "%Y-%m-%d");
        return std::mktime(&tm);
    };

    auto get_iso_date = [](std::time_t t) {
        std::tm tm = *std::localtime(&t);
        std::ostringstream oss;
        oss << std::put_time(&tm, "%Y-%m-%d");
        return oss.str();
    };

    std::time_t target_time = from_iso_date(target_date_str);
    std::tm* target_tm = std::localtime(&target_time);
    
    std::time_t yesterday_time = target_time - 24 * 3600;
    std::string yesterday_str = get_iso_date(yesterday_time);

    int weekday = (target_tm->tm_wday == 0) ? 6 : (target_tm->tm_wday - 1);
    std::time_t monday_time = target_time - weekday * 24 * 3600;
    std::time_t sunday_time = monday_time + 6 * 24 * 3600;
    std::string monday_str = get_iso_date(monday_time);
    std::string sunday_str = get_iso_date(sunday_time);

    std::tm* mon_tm = std::localtime(&monday_time);
    char buf1[64], buf2[64];
    std::strftime(buf1, sizeof(buf1), "%b %d", mon_tm);
    std::tm* sun_tm = std::localtime(&sunday_time);
    std::strftime(buf2, sizeof(buf2), "%b %d", sun_tm);
    std::string week_range_str = std::string(buf1) + " - " + std::string(buf2);

    auto build_query = [&](const std::string& base) {
        if (app_filter_std.empty()) return base;
        std::string res = base;
        if (res.find("WHERE") != std::string::npos) res += " AND app_class = ?";
        else res += " WHERE app_class = ?";
        return res;
    };

    sqlite3_stmt* stmt;
    auto get_sum = [&](const std::string& sql, const std::vector<std::string>& params) -> int {
        std::string q = build_query(sql);
        if (sqlite3_prepare_v2(db, q.c_str(), -1, &stmt, nullptr) != SQLITE_OK) return 0;
        for (size_t i = 0; i < params.size(); ++i) sqlite3_bind_text(stmt, i + 1, params[i].c_str(), -1, SQLITE_STATIC);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, params.size() + 1, app_filter_std.c_str(), -1, SQLITE_STATIC);
        int res = 0;
        if (sqlite3_step(stmt) == SQLITE_ROW) res = sqlite3_column_int(stmt, 0);
        sqlite3_finalize(stmt);
        return res;
    };

    int yesterday_seconds = get_sum("SELECT SUM(seconds) FROM focus_log WHERE log_date = ?", {yesterday_str});
    int total_seconds = get_sum("SELECT SUM(seconds) FROM focus_log WHERE log_date = ?", {target_date_str});

    int total_week = 0, days_count = 0;
    std::string q_avg = build_query("SELECT COUNT(DISTINCT log_date), SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? AND seconds > 0");
    if (sqlite3_prepare_v2(db, q_avg.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 3, app_filter_std.c_str(), -1, SQLITE_STATIC);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            days_count = sqlite3_column_int(stmt, 0);
            total_week = sqlite3_column_int(stmt, 1);
        }
    }
    sqlite3_finalize(stmt);
    int average_seconds = (days_count > 0) ? (total_week / days_count) : 0;

    // Apps list for target date
    QJsonArray appsArray;
    std::string q_apps = build_query("SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date = ?");
    q_apps += " GROUP BY app_class ORDER BY secs DESC";
    if (sqlite3_prepare_v2(db, q_apps.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, target_date_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 2, app_filter_std.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            std::string cls = (const char*)sqlite3_column_text(stmt, 0);
            std::string name = (const char*)sqlite3_column_text(stmt, 1);
            int secs = sqlite3_column_int(stmt, 2);
            QJsonObject appObj;
            appObj["class"] = QString::fromStdString(cls);
            appObj["name"] = QString::fromStdString(name);
            appObj["icon"] = QString::fromStdString(focus_common::get_app_icon(cls));
            appObj["seconds"] = secs;
            appObj["percent"] = total_seconds > 0 ? std::round((secs * 1000.0) / total_seconds) / 10.0 : 0.0;
            appsArray.append(appObj);
        }
    }
    sqlite3_finalize(stmt);

    // Week Apps list
    QJsonArray weekAppsArray;
    std::string q_wapps = build_query("SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date >= ? AND log_date <= ?");
    q_wapps += " GROUP BY app_class ORDER BY secs DESC";
    if (sqlite3_prepare_v2(db, q_wapps.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 3, app_filter_std.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            std::string cls = (const char*)sqlite3_column_text(stmt, 0);
            std::string name = (const char*)sqlite3_column_text(stmt, 1);
            int secs = sqlite3_column_int(stmt, 2);
            QJsonObject appObj;
            appObj["class"] = QString::fromStdString(cls);
            appObj["name"] = QString::fromStdString(name);
            appObj["icon"] = QString::fromStdString(focus_common::get_app_icon(cls));
            appObj["seconds"] = secs;
            appObj["percent"] = total_week > 0 ? std::round((secs * 1000.0) / total_week) / 10.0 : 0.0;
            weekAppsArray.append(appObj);
        }
    }
    sqlite3_finalize(stmt);

    // Week data
    QJsonArray weekArray;
    std::map<std::string, int> week_map;
    std::string q_week = build_query("SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ?");
    q_week += " GROUP BY log_date";
    if (sqlite3_prepare_v2(db, q_week.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 3, app_filter_std.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) week_map[(const char*)sqlite3_column_text(stmt, 0)] = sqlite3_column_int(stmt, 1);
    }
    sqlite3_finalize(stmt);
    std::vector<std::string> days_abbr = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
    for (int i = 0; i < 7; ++i) {
        std::string d_str = get_iso_date(monday_time + i * 24 * 3600);
        QJsonObject dayObj;
        dayObj["date"] = QString::fromStdString(d_str);
        dayObj["day"] = QString::fromStdString(days_abbr[i]);
        dayObj["total"] = week_map[d_str];
        dayObj["is_target"] = (d_str == target_date_str);
        weekArray.append(dayObj);
    }

    // Hourly
    QJsonArray hourlyArray;
    std::vector<int> hourly_data(48, 0);
    std::string q_hour = build_query("SELECT hour, SUM(seconds) FROM focus_hourly WHERE log_date = ?");
    if (sqlite3_prepare_v2(db, (q_hour + " GROUP BY hour").c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, target_date_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 2, app_filter_std.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            int hr = sqlite3_column_int(stmt, 0);
            if (hr >= 0 && hr < 24) hourly_data[hr * 2] += sqlite3_column_int(stmt, 1);
        }
    }
    sqlite3_finalize(stmt);
    for(int h : hourly_data) hourlyArray.append(h);

    // Week Heatmap (7 days, 24 hours per day)
    std::vector<std::vector<int>> heatmap_matrix(7, std::vector<int>(24, 0));
    std::string q_heatmap = build_query("SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date >= ? AND log_date <= ?");
    q_heatmap += " GROUP BY log_date, hour";
    if (sqlite3_prepare_v2(db, q_heatmap.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 3, app_filter_std.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            std::string d_str = (const char*)sqlite3_column_text(stmt, 0);
            int hr = sqlite3_column_int(stmt, 1);
            int secs = sqlite3_column_int(stmt, 2);
            
            std::time_t t = from_iso_date(d_str);
            std::tm* t_tm = std::localtime(&t);
            int wday = (t_tm->tm_wday == 0) ? 6 : (t_tm->tm_wday - 1);
            if (wday >= 0 && wday < 7 && hr >= 0 && hr < 24) {
                heatmap_matrix[wday][hr] = secs;
            }
        }
    }
    sqlite3_finalize(stmt);

    QJsonArray weekHeatmapArray;
    for (int d = 0; d < 7; ++d) {
        QJsonArray dayArray;
        for (int h = 0; h < 24; ++h) {
            dayArray.append(heatmap_matrix[d][h]);
        }
        weekHeatmapArray.append(dayArray);
    }

    // Month Data
    QJsonArray monthArray;
    int year = target_tm->tm_year + 1900;
    int mon = target_tm->tm_mon; // 0-11

    std::tm first_tm = {};
    first_tm.tm_year = year - 1900;
    first_tm.tm_mon = mon;
    first_tm.tm_mday = 1;
    first_tm.tm_hour = 12; // noon to avoid timezone shifts
    std::time_t first_time = std::mktime(&first_tm);
    std::tm* first_tm_res = std::localtime(&first_time);
    int first_wday = first_tm_res->tm_wday; // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    int start_pad = (first_wday == 0) ? 6 : (first_wday - 1);

    for (int i = 0; i < start_pad; ++i) {
        QJsonObject padObj;
        padObj["date"] = "";
        padObj["total"] = -1;
        padObj["is_target"] = false;
        monthArray.append(padObj);
    }

    int days_in_month[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    if (mon == 1) { // Feb leap year check
        if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
            days_in_month[1] = 29;
        }
    }
    int num_days = days_in_month[mon];

    char like_pattern[32];
    std::sprintf(like_pattern, "%04d-%02d-%%", year, mon + 1);

    std::map<std::string, int> month_totals;
    std::string q_month = build_query("SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date LIKE ?");
    q_month += " GROUP BY log_date";

    if (sqlite3_prepare_v2(db, q_month.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, like_pattern, -1, SQLITE_TRANSIENT);
        if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 2, app_filter_std.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            std::string date_str = (const char*)sqlite3_column_text(stmt, 0);
            int secs = sqlite3_column_int(stmt, 1);
            month_totals[date_str] = secs;
        }
    }
    sqlite3_finalize(stmt);

    for (int d = 1; d <= num_days; ++d) {
        char d_str[32];
        std::sprintf(d_str, "%04d-%02d-%02d", year, mon + 1, d);
        std::string date_str(d_str);
        int total = month_totals.count(date_str) ? month_totals[date_str] : 0;
        bool is_tgt = (date_str == target_date_str);
        
        QJsonObject dayObj;
        dayObj["date"] = QString::fromStdString(date_str);
        dayObj["total"] = total;
        dayObj["is_target"] = is_tgt;
        monthArray.append(dayObj);
    }

    int total_items = start_pad + num_days;
    int end_pad = (7 - (total_items % 7)) % 7;
    for (int i = 0; i < end_pad; ++i) {
        QJsonObject padObj;
        padObj["date"] = "";
        padObj["total"] = -1;
        padObj["is_target"] = false;
        monthArray.append(padObj);
    }

    std::string cur;
    {
        std::lock_guard<std::mutex> lock(state_mutex);
        cur = current_title.empty() ? "Desktop" : current_title;
    }

    root["selected_date"] = QString::fromStdString(target_date_str);
    root["total"] = total_seconds;
    root["average"] = average_seconds;
    root["week_range"] = QString::fromStdString(week_range_str);
    root["yesterday"] = yesterday_seconds;
    root["current"] = appFilter.isEmpty() ? QString::fromStdString(cur) : appFilter;
    root["apps"] = appsArray;
    root["week_apps"] = weekAppsArray;
    root["week"] = weekArray;
    root["hourly"] = hourlyArray;
    root["week_heatmap"] = weekHeatmapArray;
    root["peak_usage_str"] = "N/A";
    root["month"] = monthArray;

    return root;
}
