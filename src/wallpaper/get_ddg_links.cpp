#include <iostream>
#include <string>
#include <vector>
#include <regex>
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <thread>
#include <fstream>
#include <filesystem>

using json = nlohmann::json;
namespace fs = std::filesystem;

struct CurlResponse {
    std::string data;
    long status_code;
};

size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

CurlResponse fetch_url(CURL* curl, const std::string& url, const std::vector<std::string>& headers_list = {}) {
    std::string readBuffer;
    long response_code = 0;
    
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    struct curl_slist* headers = NULL;
    for (const auto& h : headers_list) {
        headers = curl_slist_append(headers, h.c_str());
    }
    if (headers) curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    CURLcode res = curl_easy_perform(curl);
    if (res == CURLE_OK) {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
    }
    
    if (headers) curl_slist_free_all(headers);
    return {readBuffer, response_code};
}

std::string get_control_state() {
    const char* run_wp = std::getenv("QS_RUN_WALLPAPER_PICKER");
    std::string path = run_wp ? std::string(run_wp) + "/ddg_search_control" : "/tmp/quickshell/wallpaper_picker/ddg_search_control";
    std::ifstream f(path);
    if (!f.is_open()) return "run";
    std::string state;
    f >> state;
    return state;
}

int main(int argc, char* argv[]) {
    if (argc < 2) return 1;
    std::string query = argv[1];
    query += " wallpaper";

    curl_global_init(CURL_GLOBAL_ALL);
    CURL* curl = curl_easy_init();
    if (!curl) return 1;

    char* encoded_query = curl_easy_escape(curl, query.c_str(), query.length());
    std::string search_url = "https://duckduckgo.com/?q=" + std::string(encoded_query) + "&iar=images&iax=images&ia=images&kp=-1";
    curl_free(encoded_query);

    // 1. Get VQD token
    std::string vqd;
    auto resp = fetch_url(curl, search_url);
    std::regex vqd_regex("vqd=['\"]?([0-9a-zA-Z_-]+)['\"]?");
    std::smatch match;
    if (std::regex_search(resp.data, match, vqd_regex)) {
        vqd = match[1];
    }

    if (vqd.empty()) {
        curl_easy_cleanup(curl);
        return 1;
    }

    // 2. Fetch image results
    std::string next_url = "";
    int links_found = 0;

    for (int page = 0; page < 5; ++page) {
        std::string state = get_control_state();
        if (state == "stop") break;
        while (state == "pause") {
            std::this_thread::sleep_for(std::chrono::seconds(1));
            state = get_control_state();
        }

        std::string url;
        if (next_url.empty()) {
            char* q_esc = curl_easy_escape(curl, query.c_str(), query.length());
            url = "https://duckduckgo.com/i.js?l=us-en&o=json&q=" + std::string(q_esc) + "&vqd=" + vqd + "&f=,,,&p=-1&ex=-1";
            curl_free(q_esc);
        } else {
            url = "https://duckduckgo.com" + next_url;
            if (url.find("p=-1") == std::string::npos) url += "&p=-1";
            if (url.find("vqd=") == std::string::npos) url += "&vqd=" + vqd;
        }

        auto json_resp = fetch_url(curl, url, {"Accept: application/json"});
        try {
            auto data = json::parse(json_resp.data);
            if (data.contains("results")) {
                for (auto& res : data["results"]) {
                    int w = res.value("width", 0);
                    int h = res.value("height", 0);
                    if (w >= 1920 && h >= 1080) {
                        std::string thumb = res.value("thumbnail", "");
                        std::string img = res.value("image", "");
                        if (!thumb.empty() && !img.empty()) {
                            std::cout << thumb << "|" << img << std::endl;
                            links_found++;
                        }
                    }
                }
            }
            if (data.contains("next")) {
                next_url = data["next"];
            } else {
                break;
            }
        } catch (...) {
            break;
        }
    }

    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return 0;
}
