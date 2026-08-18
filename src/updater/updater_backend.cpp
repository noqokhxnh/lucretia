#include <iostream>
#include <string>
#include <vector>
#include <regex>
#include <cstdlib>
#include <fstream>
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
    std::regex re("(\\d+)\\.(\\d+)\\.(\\d+)");
    std::smatch m;
    if (std::regex_search(v, m, re)) {
        return {std::stoi(m[1]), std::stoi(m[2]), std::stoi(m[3])};
    }
    return {0, 0, 0};
}

std::string read_local_version() {
    const char* home = std::getenv("HOME");
    if (!home) return "0.0.0";
    std::ifstream f(std::string(home) + "/.local/state/lucretia-version");
    if (!f.is_open()) return "0.0.0";
    std::string line;
    while (std::getline(f, line)) {
        if (line.rfind("LOCAL_VERSION=", 0) == 0) {
            auto val = line.substr(14);
            if (!val.empty() && val.front() == '"') val.erase(0, 1);
            if (!val.empty() && val.back() == '"') val.pop_back();
            return val;
        }
    }
    return "0.0.0";
}

// ─────────────────────────────────────────────
// --version: fetch remote DOTS_VERSION from install.sh
// ─────────────────────────────────────────────
void cmd_version(CURL* curl) {
    auto resp = fetch_url(curl,
        "https://raw.githubusercontent.com/noqokhxnh/lucretia/main/install.sh");
    std::regex re("\nDOTS_VERSION=\"([^\"]+)\"");
    std::smatch m;
    if (std::regex_search(resp.data, m, re)) {
        std::cout << m[1] << std::endl;
    }
}

// ─────────────────────────────────────────────
// --video: resolve the best video URL from updates.json
// ─────────────────────────────────────────────
void cmd_video(CURL* curl) {
    auto local = read_local_version();
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
void cmd_commits(CURL* curl) {
    std::string repo = "noqokhxnh/lucretia";
    auto local = read_local_version();
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
    if (argc < 2) return 1;
    std::string cmd = argv[1];

    curl_global_init(CURL_GLOBAL_ALL);
    CURL* curl = curl_easy_init();
    if (!curl) return 1;

    if (cmd == "--version") cmd_version(curl);
    else if (cmd == "--video") cmd_video(curl);
    else if (cmd == "--commits") cmd_commits(curl);

    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return 0;
}
