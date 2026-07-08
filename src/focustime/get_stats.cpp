#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <iomanip>
#include <chrono>
#include <ctime>
#include <sqlite3.h>
#include <nlohmann/json.hpp>
#include "focus_common.hpp"

using json = nlohmann::json;
using namespace focus_common;

std::string get_iso_date(std::time_t t) {
    std::tm tm = *std::localtime(&t);
    std::ostringstream oss;
    oss << std::put_time(&tm, "%Y-%m-%d");
    return oss.str();
}

std::time_t from_iso_date(const std::string& date_str) {
    std::tm tm = {};
    std::istringstream iss(date_str);
    iss >> std::get_time(&tm, "%Y-%m-%d");
    return std::mktime(&tm);
}

int main(int argc, char* argv[]) {
    std::string target_date_str;
    std::string app_filter = "";

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--app" && i + 1 < argc) {
            app_filter = argv[++i];
        } else if (target_date_str.empty() && arg.find("-") != std::string::npos) {
            target_date_str = arg;
        }
    }

    if (target_date_str.empty()) {
        auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        target_date_str = get_iso_date(now);
    }

    std::string db_dir = std::getenv("QS_STATE_FOCUSTIME") ? std::getenv("QS_STATE_FOCUSTIME") : 
                         std::string(std::getenv("HOME")) + "/.local/state/quickshell/focustime";
    std::string db_path = db_dir + "/focustime.db";

    sqlite3* db = init_db(db_path);
    if (!db) {
        std::cout << "{}" << std::endl;
        return 1;
    }

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
        if (app_filter.empty()) return base;
        std::string res = base;
        if (res.find("WHERE") != std::string::npos) res += " AND app_class = ?";
        else res += " WHERE app_class = ?";
        return res;
    };

    sqlite3_stmt* stmt;
    auto get_sum = [&](const std::string& sql, const std::vector<std::string>& params) -> int {
        std::string q = build_query(sql);
        if (sqlite3_prepare_v2(db, q.c_str(), -1, &stmt, nullptr) != SQLITE_OK) return 0;
        for (int i = 0; i < params.size(); ++i) sqlite3_bind_text(stmt, i + 1, params[i].c_str(), -1, SQLITE_STATIC);
        if (!app_filter.empty()) sqlite3_bind_text(stmt, params.size() + 1, app_filter.c_str(), -1, SQLITE_STATIC);
        int res = 0;
        if (sqlite3_step(stmt) == SQLITE_ROW) res = sqlite3_column_int(stmt, 0);
        sqlite3_finalize(stmt);
        return res;
    };

    int yesterday_seconds = get_sum("SELECT SUM(seconds) FROM focus_log WHERE log_date = ?", {yesterday_str});
    int total_seconds = get_sum("SELECT SUM(seconds) FROM focus_log WHERE log_date = ?", {target_date_str});

    // Average
    int total_week = 0, days_count = 0;
    std::string q_avg = build_query("SELECT COUNT(DISTINCT log_date), SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? AND seconds > 0");
    if (sqlite3_prepare_v2(db, q_avg.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter.empty()) sqlite3_bind_text(stmt, 3, app_filter.c_str(), -1, SQLITE_STATIC);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            days_count = sqlite3_column_int(stmt, 0);
            total_week = sqlite3_column_int(stmt, 1);
        }
    }
    sqlite3_finalize(stmt);
    int average_seconds = (days_count > 0) ? (total_week / days_count) : 0;

    // Apps list
    std::vector<json> apps;
    std::string q_apps = build_query("SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date = ?");
    q_apps += " GROUP BY app_class ORDER BY secs DESC";
    if (sqlite3_prepare_v2(db, q_apps.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, target_date_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter.empty()) sqlite3_bind_text(stmt, 2, app_filter.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            std::string cls = (const char*)sqlite3_column_text(stmt, 0);
            std::string name = (const char*)sqlite3_column_text(stmt, 1);
            int secs = sqlite3_column_int(stmt, 2);
            apps.push_back({{"class", cls}, {"name", name}, {"icon", get_app_icon(cls)}, {"seconds", secs}, {"percent", total_seconds > 0 ? std::round((secs * 1000.0) / total_seconds) / 10.0 : 0.0}});
        }
    }
    sqlite3_finalize(stmt);

    // Week data
    std::vector<json> week_data;
    std::map<std::string, int> week_map;
    std::string q_week = build_query("SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ?");
    q_week += " GROUP BY log_date";
    if (sqlite3_prepare_v2(db, q_week.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter.empty()) sqlite3_bind_text(stmt, 3, app_filter.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) week_map[(const char*)sqlite3_column_text(stmt, 0)] = sqlite3_column_int(stmt, 1);
    }
    sqlite3_finalize(stmt);
    std::vector<std::string> days_abbr = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
    for (int i = 0; i < 7; ++i) {
        std::string d_str = get_iso_date(monday_time + i * 24 * 3600);
        week_data.push_back({{"date", d_str}, {"day", days_abbr[i]}, {"total", week_map[d_str]}, {"is_target", d_str == target_date_str}});
    }

    // Hourly
    std::vector<int> hourly_data(48, 0);
    std::string q_hour = build_query("SELECT hour, SUM(seconds) FROM focus_hourly WHERE log_date = ?");
    if (sqlite3_prepare_v2(db, (q_hour + " GROUP BY hour").c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, target_date_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter.empty()) sqlite3_bind_text(stmt, 2, app_filter.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            int hr = sqlite3_column_int(stmt, 0);
            if (hr >= 0 && hr < 24) hourly_data[hr * 2] += sqlite3_column_int(stmt, 1);
        }
    }
    sqlite3_finalize(stmt);

    // Week Heatmap (7 days, 24 hours per day)
    std::vector<std::vector<int>> heatmap_matrix(7, std::vector<int>(24, 0));
    std::string q_heatmap = build_query("SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date >= ? AND log_date <= ?");
    q_heatmap += " GROUP BY log_date, hour";
    if (sqlite3_prepare_v2(db, q_heatmap.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
        if (!app_filter.empty()) sqlite3_bind_text(stmt, 3, app_filter.c_str(), -1, SQLITE_STATIC);
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

    json week_heatmap_json = json::array();
    for (int d = 0; d < 7; ++d) {
        json day_arr = json::array();
        for (int h = 0; h < 24; ++h) {
            day_arr.push_back(heatmap_matrix[d][h]);
        }
        week_heatmap_json.push_back(day_arr);
    }

    // Month Data
    std::vector<json> month_data;
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
        month_data.push_back({{"date", ""}, {"total", -1}, {"is_target", false}});
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

    int rc = sqlite3_prepare_v2(db, q_month.c_str(), -1, &stmt, nullptr);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, like_pattern, -1, SQLITE_TRANSIENT);
        if (!app_filter.empty()) sqlite3_bind_text(stmt, 2, app_filter.c_str(), -1, SQLITE_TRANSIENT);
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
        month_data.push_back({{"date", date_str}, {"total", total}, {"is_target", is_tgt}});
    }

    int total_items = start_pad + num_days;
    int end_pad = (7 - (total_items % 7)) % 7;
    for (int i = 0; i < end_pad; ++i) {
        month_data.push_back({{"date", ""}, {"total", -1}, {"is_target", false}});
    }

    json result = {
        {"selected_date", target_date_str}, {"total", total_seconds}, {"average", average_seconds},
        {"week_range", week_range_str}, {"yesterday", yesterday_seconds}, {"current", app_filter.empty() ? "History" : app_filter},
        {"apps", apps}, {"week", week_data}, {"hourly", hourly_data},
        {"week_heatmap", week_heatmap_json}, {"peak_usage_str", "N/A"}, {"month", month_data}
    };
    std::cout << result.dump() << std::endl;

    sqlite3_close(db);
    return 0;
}
