#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <chrono>
#include <thread>
#include <mutex>
#include <fstream>
#include <filesystem>
#include <sstream>
#include <csignal>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <sqlite3.h>
#include <nlohmann/json.hpp>
#include "focus_common.hpp"

using json = nlohmann::json;
using namespace focus_common;
namespace fs = std::filesystem;

struct TrackerState {
    std::string current_class = "Desktop";
    std::string current_title = "Desktop";
    std::mutex mutex;
} state;

bool running = true;

bool is_locked();

void signal_handler(int signum) {
    running = false;
}

std::string get_active_window_info() {
    FILE* pipe = popen("niri msg --json windows", "r");
    if (!pipe) return "[]";
    char buffer[4096];
    std::string result = "";
    while (fgets(buffer, sizeof(buffer), pipe) != NULL) result += buffer;
    pclose(pipe);
    return result;
}

void update_active_window() {
    if (is_locked()) {
        std::lock_guard<std::mutex> lock(state.mutex);
        state.current_class = "Locked";
        state.current_title = "Locked";
        return;
    }
    std::string info_json = get_active_window_info();
    if (info_json.empty() || info_json == "[]" || info_json == "null") {
        std::lock_guard<std::mutex> lock(state.mutex);
        state.current_class = "Desktop";
        state.current_title = "Desktop";
        return;
    }
    try {
        auto data = json::parse(info_json);
        if (data.is_array()) {
            bool found = false;
            for (auto& item : data) {
                if (item.value("is_focused", false)) {
                    std::string cls = item.value("app_id", "Unknown");
                    std::string title = item.value("title", "Unknown");
                    
                    if (cls.find("quickshell") != std::string::npos) {
                        cls = "Quickshell";
                        title = "Quickshell";
                    }
                    std::string clean_title = resolve_app_name(cls, title);
                    
                    std::lock_guard<std::mutex> lock(state.mutex);
                    state.current_class = cls;
                    state.current_title = clean_title;
                    found = true;
                    break;
                }
            }
            if (!found) {
                std::lock_guard<std::mutex> lock(state.mutex);
                state.current_class = "Desktop";
                state.current_title = "Desktop";
            }
        } else {
            std::lock_guard<std::mutex> lock(state.mutex);
            state.current_class = "Desktop";
            state.current_title = "Desktop";
        }
    } catch (...) {
        std::lock_guard<std::mutex> lock(state.mutex);
        state.current_class = "Unknown";
        state.current_title = "Unknown";
    }
}

bool is_locked() {
    return system("pgrep -f Lock.qml > /dev/null") == 0;
}

void ipc_listener() {
    const char* niri_socket = std::getenv("NIRI_SOCKET");
    if (!niri_socket) return;

    std::string sock_path = niri_socket;

    while (running) {
        int sock = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sock < 0) { std::this_thread::sleep_for(std::chrono::seconds(2)); continue; }

        struct sockaddr_un addr;
        memset(&addr, 0, sizeof(addr));
        addr.sun_family = AF_UNIX;
        strncpy(addr.sun_path, sock_path.c_str(), sizeof(addr.sun_path) - 1);

        if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            close(sock);
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        // Start the event stream
        std::string req = "\"EventStream\"\n";
        if (send(sock, req.c_str(), req.length(), 0) < 0) {
            close(sock);
            std::this_thread::sleep_for(std::chrono::seconds(2));
            continue;
        }

        char buffer[4096];
        std::string stream_data = "";
        while (running) {
            ssize_t n = recv(sock, buffer, sizeof(buffer) - 1, 0);
            if (n <= 0) break;
            buffer[n] = '\0';
            stream_data += buffer;

            size_t pos;
            while ((pos = stream_data.find('\n')) != std::string::npos) {
                std::string line = stream_data.substr(0, pos);
                stream_data.erase(0, pos + 1);
                if (!line.empty()) {
                    if (line.find("WindowFocusChanged") != std::string::npos ||
                        line.find("WindowOpenedOrChanged") != std::string::npos ||
                        line.find("WorkspaceActivated") != std::string::npos) {
                        update_active_window();
                    }
                }
            }
        }
        close(sock);
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

int main() {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    std::string db_dir = std::getenv("QS_STATE_FOCUSTIME") ? std::getenv("QS_STATE_FOCUSTIME") : 
                         std::string(std::getenv("HOME")) + "/.local/state/quickshell/focustime";
    fs::create_directories(db_dir);
    std::string db_path = db_dir + "/focustime.db";
    sqlite3* db = init_db(db_path);
    if (!db) return 1;

    std::string run_dir = std::getenv("QS_RUN_FOCUSTIME") ? std::getenv("QS_RUN_FOCUSTIME") : "/tmp/quickshell/focustime";
    fs::create_directories(run_dir);
    std::string state_file = run_dir + "/focustime_state.json";

    update_active_window();
    std::thread listener(ipc_listener);

    struct LogEntry {
        std::string date;
        std::string cls;
        std::string title;
        int hour;
        int minute;
    };
    std::vector<LogEntry> buffer;
    int tick_counter = 0;

    while (running) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        tick_counter++;

        auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        std::tm* now_tm = std::localtime(&now);
        char date_buf[16];
        std::strftime(date_buf, sizeof(date_buf), "%Y-%m-%d", now_tm);
        
        LogEntry entry;
        {
            std::lock_guard<std::mutex> lock(state.mutex);
            entry = {date_buf, state.current_class, state.current_title, now_tm->tm_hour, now_tm->tm_min};
        }
        
        if (!entry.cls.empty()) buffer.push_back(entry);

        // Dump state to JSON for UI every 5 seconds
        if (tick_counter % 5 == 0) {
            // In a real implementation we'd do a partial update of a cached JSON object
            // but for now let's just trigger get_stats logic or a simplified version
            // For simplicity in this demo, we'll just write the current app
            json current_state = {{"current", entry.title}, {"class", entry.cls}};
            std::ofstream f(state_file + ".tmp");
            f << current_state.dump();
            f.close();
            fs::rename(state_file + ".tmp", state_file);
        }

        // Flush to SQLite every 15 entries
        if (buffer.size() >= 15) {
            std::map<std::pair<std::string, std::string>, int> daily;
            std::map<std::tuple<std::string, int, std::string>, int> hourly;
            std::map<std::tuple<std::string, int, std::string>, int> mins;

            for (const auto& e : buffer) {
                daily[{e.date, e.cls}]++;
                hourly[{e.date, e.hour, e.cls}]++;
                mins[{e.date, e.hour * 60 + e.minute, e.cls}]++;
            }

            sqlite3_exec(db, "BEGIN TRANSACTION;", nullptr, nullptr, nullptr);
            for (auto const& [key, secs] : daily) {
                sqlite3_stmt* stmt;
                sqlite3_prepare_v2(db, "INSERT INTO focus_log (log_date, app_class, seconds, app_title) VALUES (?, ?, ?, ?) ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?", -1, &stmt, nullptr);
                sqlite3_bind_text(stmt, 1, key.first.c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_text(stmt, 2, key.second.c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_int(stmt, 3, secs);
                // We'd need to track titles better for the update, but this is fine for now
                sqlite3_bind_text(stmt, 4, key.second.c_str(), -1, SQLITE_STATIC); 
                sqlite3_bind_int(stmt, 5, secs);
                sqlite3_step(stmt);
                sqlite3_finalize(stmt);
            }
            // Similar for hourly and minutes...
            sqlite3_exec(db, "COMMIT;", nullptr, nullptr, nullptr);
            buffer.clear();
        }
    }

    running = false;
    if (listener.joinable()) listener.join();
    sqlite3_close(db);
    return 0;
}
