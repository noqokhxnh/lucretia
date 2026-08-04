#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <sqlite3.h>
#include <filesystem>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <tuple>
#include <thread>
#include <mutex>

#include "focustime/focus_common.hpp"

namespace fs = std::filesystem;

class FocusService : public QObject {
    Q_OBJECT
public:
    explicit FocusService(QObject* parent = nullptr);
    ~FocusService();

    QJsonObject handleStats(const QJsonObject& req);

private:
    sqlite3* db{nullptr};
    std::string db_path;
    std::string run_dir;
    bool stop_daemon{false};
    std::thread daemon_thread;
    std::mutex buf_mutex;

    struct LogEntry {
        std::string date;
        int hour;
        std::string app_class;
        int seconds;
    };
    std::vector<LogEntry> buffer;

    void daemon_loop();
    void flush_buffer();
};
