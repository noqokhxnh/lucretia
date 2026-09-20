#include <iostream>
#include <string>
#include <regex>
#include <cstdlib>
#include <fstream>
#include <filesystem>
#include <ctime>
#include <algorithm>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

struct CurlResponse {
    std::string data;
    long status_code;
};

size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

CurlResponse fetch_url(CURL* curl, const std::string& url, bool head_only = false) {
    std::string readBuffer;
    long response_code = 0;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "updater");
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    if (head_only) {
        curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, nullptr);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, nullptr);
    } else {
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
    }

    CURLcode res = curl_easy_perform(curl);
    if (res == CURLE_OK) {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
    }

    // Reset NOBODY flag for next request (WRITEDATA will be set by next caller)
    if (head_only) {
        curl_easy_setopt(curl, CURLOPT_NOBODY, 0L);
        curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
    }

    return {readBuffer, response_code};
}

// Parse version string into a tuple for comparison
const std::tuple<int,int,int> ZERO_VER = {0, 0, 0};

std::tuple<int,int,int> parse_ver(const std::string& v) {
    std::regex re("(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?");
    std::smatch m;
    if (std::regex_search(v, m, re)) {
        int major = m[1].matched ? std::stoi(m[1]) : 0;
        int minor = m[2].matched ? std::stoi(m[2]) : 0;
        int patch = m[3].matched ? std::stoi(m[3]) : 0;
        return {major, minor, patch};
    }
    return {0, 0, 0};
}

std::string read_local_version(const std::string& state_dir) {
    const char* home = std::getenv("HOME");
    std::string home_str = home ? home : "";

    // 1. Check install.sh for DOTS_VERSION or DOT_VERSION
    if (!home_str.empty()) {
        std::ifstream fi(home_str + "/.config/niri/install.sh");
        if (fi.is_open()) {
            std::string line;
            while (std::getline(fi, line)) {
                if (line.rfind("DOTS_VERSION=", 0) == 0 || line.rfind("DOT_VERSION=", 0) == 0) {
                    auto val = line.substr(line.find('=') + 1);
                    while (!val.empty() && (val.front() == '"' || val.front() == '\'')) val.erase(0, 1);
                    while (!val.empty() && (val.back() == '"' || val.back() == '\'')) val.pop_back();
                    if (!val.empty()) return val;
                }
            }
        }
    }

    // 2. Check lucretia-version
    if (!home_str.empty()) {
        std::ifstream f(home_str + "/.local/state/lucretia-version");
        if (f.is_open()) {
            std::string line;
            while (std::getline(f, line)) {
                if (line.rfind("LOCAL_VERSION=", 0) == 0) {
                    auto val = line.substr(14);
                    while (!val.empty() && (val.front() == '"' || val.front() == '\'')) val.erase(0, 1);
                    while (!val.empty() && (val.back() == '"' || val.back() == '\'')) val.pop_back();
                    if (!val.empty() && val != "Not Installed") return val;
                }
            }
        }
    }

    // 3. Check version file in state_dir
    std::ifstream fv(state_dir + "/version");
    if (fv.is_open()) {
        std::string line;
        while (std::getline(fv, line)) {
            if (line.rfind("SERPANTINUM_VERSION=", 0) == 0) {
                auto val = line.substr(20);
                while (!val.empty() && (val.front() == '"' || val.front() == '\'')) val.erase(0, 1);
                while (!val.empty() && (val.back() == '"' || val.back() == '\'')) val.pop_back();
                if (!val.empty()) return val;
            }
        }
    }

    return "2.0.4";
}

std::string get_last_notified(const std::string& state_dir) {
    std::ifstream f(state_dir + "/last_notified");
    if (f.is_open()) {
        std::string line;
        if (std::getline(f, line)) {
            while (!line.empty() && (line.back() == '\r' || line.back() == '\n' || line.back() == ' ')) {
                line.pop_back();
            }
            return line;
        }
    }
    return "";
}

std::string fetch_remote_version(CURL* curl) {
    auto resp = fetch_url(curl,
        "https://raw.githubusercontent.com/noqokhxnh/lucretia/main/install.sh");
    if (resp.status_code == 200 && !resp.data.empty()) {
        std::regex re("(?:^|\n)(?:DOTS_VERSION|DOT_VERSION)=[\"']?([^\"'\r\n]+)");
        std::smatch m;
        if (std::regex_search(resp.data, m, re)) {
            return m[1];
        }
    }
    return "";
}

// ─────────────────────────────────────────────
// --version: fetch remote DOTS_VERSION from install.sh
// ─────────────────────────────────────────────
void cmd_version(CURL* curl) {
    std::string ver = fetch_remote_version(curl);
    if (!ver.empty()) {
        std::cout << ver << std::endl;
    }
}

// ─────────────────────────────────────────────
// --check: output complete status JSON
// ─────────────────────────────────────────────
void cmd_check(CURL* curl, const std::string& state_dir) {
    std::string local_ver = read_local_version(state_dir);
    std::string remote_ver = fetch_remote_version(curl);
    if (remote_ver.empty()) {
        remote_ver = local_ver;
    }

    bool has_update = parse_ver(remote_ver) > parse_ver(local_ver);
    std::string last_notified = get_last_notified(state_dir);

    try {
        std::filesystem::create_directories(state_dir);
        std::ofstream fc(state_dir + "/last_check");
        if (fc.is_open()) {
            fc << std::time(nullptr);
        }
    } catch (...) {}

    json out = {
        {"local", local_ver},
        {"remote", remote_ver},
        {"has_update", has_update},
        {"last_notified", last_notified}
    };
    std::cout << out.dump() << std::endl;
}

// ─────────────────────────────────────────────
// --delay: output remaining ms delay
// ─────────────────────────────────────────────
void cmd_delay(const std::string& state_dir) {
    std::string path = state_dir + "/last_check";
    std::ifstream f(path);
    if (f.is_open()) {
        double last_ts = 0;
        if (f >> last_ts) {
            double elapsed = std::difftime(std::time(nullptr), static_cast<std::time_t>(last_ts));
            long long remaining = static_cast<long long>(std::max(0.0, 3600.0 - elapsed) * 1000.0);
            std::cout << remaining << std::endl;
            return;
        }
    }
    std::cout << 0 << std::endl;
}

// ─────────────────────────────────────────────
// --save-notified: persist notified version
// ─────────────────────────────────────────────
void cmd_save_notified(const std::string& state_dir, const std::string& ver) {
    try {
        std::filesystem::create_directories(state_dir);
        std::ofstream f(state_dir + "/last_notified");
        if (f.is_open()) {
            f << ver;
        }
    } catch (...) {}
}

// ─────────────────────────────────────────────
// --video: resolve the best video URL from updates.json
// ─────────────────────────────────────────────
void cmd_video(CURL* curl, const std::string& state_dir) {
    auto local = read_local_version(state_dir);
    auto local_v = parse_ver(local);

    auto resp = fetch_url(curl,
        "https://raw.githubusercontent.com/noqokhxnh/lucretia/main/updates.json");
    if (resp.status_code != 200 || resp.data.empty()) return;

    try {
        auto data = json::parse(resp.data);
        std::string best_url;
        std::tuple<int,int,int> best_v = {0, 0, 0};

        for (const auto& item : data["videos"]) {
            auto tv = parse_ver(item["version"].get<std::string>());
            if (tv > local_v && tv > best_v) {
                best_v = tv;
                best_url = item["url"].get<std::string>();
            }
        }

        if (!best_url.empty()) {
            // HEAD-check the URL (don't download the full video)
            auto head = fetch_url(curl, best_url, true);
            if (head.status_code >= 200 && head.status_code < 400) {
                std::cout << best_url << std::endl;
            }
        }
    } catch (...) {}
}

// ─────────────────────────────────────────────
// --commits: fetch commit log since last release
// ─────────────────────────────────────────────
void cmd_commits(CURL* curl, const std::string& state_dir) {
    std::string repo = "noqokhxnh/lucretia";
    auto local = read_local_version(state_dir);
    auto local_v = parse_ver(local);

    std::string found_ref;

    if (local_v > ZERO_VER) {
        // 1. Try tags first (fast, small payload)
        {
            auto resp = fetch_url(curl,
                "https://api.github.com/repos/" + repo + "/tags?per_page=30");
            if (resp.status_code == 200) {
                try {
                    auto tags = json::parse(resp.data);
                    std::tuple<int,int,int> best = {0, 0, 0};
                    for (const auto& t : tags) {
                        auto tv = parse_ver(t["name"].get<std::string>());
                        if (tv > ZERO_VER && tv <= local_v && tv > best) {
                            best = tv;
                            found_ref = t["name"].get<std::string>();
                        }
                    }
                } catch (...) {}
            }
        }

        // 2. Fallback: releases (only if no tag found)
        if (found_ref.empty()) {
            auto resp = fetch_url(curl,
                "https://api.github.com/repos/" + repo + "/releases?per_page=10");
            if (resp.status_code == 200) {
                try {
                    auto releases = json::parse(resp.data);
                    for (const auto& r : releases) {
                        auto rv = parse_ver(r["tag_name"].get<std::string>());
                        if (rv <= local_v && rv > ZERO_VER) {
                            found_ref = r["tag_name"].get<std::string>();
                            break;
                        }
                    }
                } catch (...) {}
            }
        }
    }

    // 3. If a valid ref was found, compare found_ref...main
    if (!found_ref.empty()) {
        auto resp = fetch_url(curl,
            "https://api.github.com/repos/" + repo + "/compare/" + found_ref + "...main");
        if (resp.status_code == 200) {
            try {
                auto data = json::parse(resp.data);
                if (data.contains("commits") && data["commits"].is_array() && !data["commits"].empty()) {
                    auto commits = data["commits"];
                    int start = std::max(0, (int)commits.size() - 20);
                    for (int i = start; i < (int)commits.size(); i++) {
                        std::cout << commits[i]["commit"]["message"].get<std::string>() << std::endl;
                        std::cout << "---SPLIT---" << std::endl;
                    }
                    return;
                }
            } catch (...) {}
        }
    }

    // 4. Fallback: No matching tag/release found or compare failed — fetch recent commits on main directly
    auto resp = fetch_url(curl,
        "https://api.github.com/repos/" + repo + "/commits?per_page=20");
    if (resp.status_code == 200) {
        try {
            auto commits = json::parse(resp.data);
            if (commits.is_array() && !commits.empty()) {
                int count = (int)commits.size();
                for (int i = count - 1; i >= 0; i--) {
                    if (commits[i].contains("commit") && commits[i]["commit"].contains("message")) {
                        std::cout << commits[i]["commit"]["message"].get<std::string>() << std::endl;
                        std::cout << "---SPLIT---" << std::endl;
                    }
                }
                return;
            }
        } catch (...) {}
    }

    std::cout << "No changelog available" << std::endl;
}

int main(int argc, char* argv[]) {
    const char* home = std::getenv("HOME");
    std::string state_dir = home ? std::string(home) + "/.local/state/lucretia" : "/tmp";

    std::string cmd = "";
    std::string save_ver = "";

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--state-dir" && i + 1 < argc) {
            state_dir = argv[++i];
        } else if (arg == "--save-notified" && i + 1 < argc) {
            cmd = "--save-notified";
            save_ver = argv[++i];
        } else if (arg == "--delay" || arg == "--check" || arg == "--version" || arg == "--video" || arg == "--commits") {
            cmd = arg;
        }
    }

    if (cmd == "--save-notified") {
        cmd_save_notified(state_dir, save_ver);
        return 0;
    }
    if (cmd == "--delay") {
        cmd_delay(state_dir);
        return 0;
    }

    curl_global_init(CURL_GLOBAL_ALL);
    CURL* curl = curl_easy_init();
    if (!curl) return 1;

    if (cmd == "--version") {
        cmd_version(curl);
    } else if (cmd == "--video") {
        cmd_video(curl, state_dir);
    } else if (cmd == "--commits") {
        cmd_commits(curl, state_dir);
    } else {
        // Default or --check
        cmd_check(curl, state_dir);
    }

    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return 0;
}
