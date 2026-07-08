#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

std::string http_get(const std::string& url) {
    CURL* curl;
    CURLcode res;
    std::string readBuffer;

    curl = curl_easy_init();
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
        curl_easy_setopt(curl, CURLOPT_USERAGENT, "Mozilla/5.0");
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 6L);
        res = curl_easy_perform(curl);
        curl_easy_cleanup(curl);
        if (res != CURLE_OK) return "";
    }
    return readBuffer;
}

std::string url_encode(const std::string& value) {
    CURL* curl = curl_easy_init();
    char* output = curl_easy_escape(curl, value.c_str(), value.length());
    std::string res(output);
    curl_free(output);
    curl_easy_cleanup(curl);
    return res;
}

std::map<std::string, std::string> LANG_MAP = {
    {"vi", "vi"}, {"viet", "vi"}, {"vietnamese", "vi"}, {"tieng viet", "vi"},
    {"en", "en"}, {"english", "en"}, {"anh", "en"},
    {"es", "es"}, {"sp", "es"}, {"spanish", "es"},
    {"fr", "fr"}, {"french", "fr"},
    {"de", "de"}, {"german", "de"},
    {"ja", "ja"}, {"jp", "ja"}, {"japanese", "ja"},
    {"ko", "ko"}, {"kr", "ko"}, {"korean", "ko"},
    {"zh", "zh"}, {"cn", "zh"}, {"chinese", "zh"},
    {"it", "it"}, {"pt", "pt"}, {"ru", "ru"}, {"ar", "ar"}, {"th", "th"}
};

std::string get_lang_code(const std::string& lang) {
    if (lang.empty()) return "vi";
    std::string l = lang;
    std::transform(l.begin(), l.end(), l.begin(), ::tolower);
    if (LANG_MAP.count(l)) return LANG_MAP[l];
    return l;
}

int main(int argc, char* argv[]) {
    if (argc < 3) return 1;

    std::string mode = argv[1];
    std::string query = argv[2];
    std::string extra = (argc > 3) ? argv[3] : "";

    if (mode == "tran") {
        std::string target = get_lang_code(extra);
        std::string url = "https://api.mymemory.translated.net/get?q=" + url_encode(query) + "&langpair=autodetect|" + target;
        std::string response = http_get(url);
        
        try {
            auto data = json::parse(response);
            std::string translated = data["responseData"]["translatedText"];
            if (translated.find("MYMEMORY WARNING") != std::string::npos || translated.find("PLEASE SELECT") != std::string::npos) {
                translated = "API quota exceeded, try again later.";
            }
            std::cout << json({{"result", translated}, {"mode", "tran"}, {"target", target}}).dump() << std::endl;
        } catch (...) {
            std::cout << json({{"result", "Error parsing response"}, {"mode", "tran"}}).dump() << std::endl;
        }

    } else if (mode == "df") {
        std::string url = "https://api.dictionaryapi.dev/api/v2/entries/en/" + url_encode(query);
        std::string response = http_get(url);
        
        try {
            auto data = json::parse(response);
            if (data.is_array() && !data.empty()) {
                auto entry = data[0];
                std::string phonetic = entry.value("phonetic", "");
                std::vector<std::string> results;
                
                int m_count = 0;
                for (auto& meaning : entry["meanings"]) {
                    if (m_count >= 2) break;
                    std::string part = meaning.value("partOfSpeech", "");
                    if (meaning.contains("definitions") && !meaning["definitions"].empty()) {
                        std::string defn = meaning["definitions"][0].value("definition", "");
                        if (!defn.empty()) {
                            results.push_back("(" + part + ") " + defn);
                            m_count++;
                        }
                    }
                }
                
                std::string final_res = (phonetic.empty() ? query : phonetic) + "\n";
                for (size_t i = 0; i < results.size(); ++i) {
                    final_res += results[i] + (i == results.size() - 1 ? "" : "\n");
                }
                std::cout << json({{"result", final_res}, {"mode", "df"}}).dump() << std::endl;
            } else {
                std::cout << json({{"result", "No definition found."}, {"mode", "df"}}).dump() << std::endl;
            }
        } catch (...) {
            std::cout << json({{"result", "No definition found or error."}, {"mode", "df"}}).dump() << std::endl;
        }
    }

    return 0;
}
