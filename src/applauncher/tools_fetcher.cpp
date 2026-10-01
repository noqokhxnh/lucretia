#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <sstream>
#include <csignal>
#include <filesystem>
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

std::string shell_escape(const std::string& str) {
    std::string res = "'";
    for (char c : str) {
        if (c == '\'') res += "'\\''";
        else res += c;
    }
    res += "'";
    return res;
}

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

    } else if (mode == "file" || mode == "dir") {
        const char* home = std::getenv("HOME");
        std::string home_str = home ? home : "";
        std::string type_arg = (mode == "file") ? "--type f" : "--type d";
        std::string cmd = "/usr/bin/fd " + type_arg + " --hidden --exclude .git --exclude node_modules --exclude .cache --max-results 25 " + shell_escape(query) + " " + shell_escape(home_str) + " 2>/dev/null";

        FILE* pipe = popen(cmd.c_str(), "r");
        json items = json::array();
        if (pipe) {
            char buffer[2048];
            while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
                std::string line = buffer;
                while (!line.empty() && (line.back() == '\n' || line.back() == '\r')) line.pop_back();
                if (line.empty()) continue;
                std::string clean_line = line;
                while (clean_line.length() > 1 && clean_line.back() == '/') clean_line.pop_back();
                fs::path p(clean_line);
                std::string ext = p.has_extension() ? p.extension().string() : "";
                if (!ext.empty() && ext[0] == '.') ext = ext.substr(1);
                std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
                items.push_back({
                    {"name", p.filename().string()},
                    {"path", line},
                    {"ext", ext},
                    {"isDir", (mode == "dir")}
                });
            }
            pclose(pipe);
        }
        std::cout << json({{"mode", mode}, {"items", items}}).dump() << std::endl;

    } else if (mode == "kill_search") {
        json items = json::array();
        std::string q = query;
        // Strip leading whitespace or colon if port
        while (!q.empty() && (q.front() == ' ' || q.front() == '\t')) q.erase(q.begin());

        bool is_port_search = false;
        std::string port_str = "";
        if (!q.empty() && q.front() == ':') {
            is_port_search = true;
            port_str = q.substr(1);
        } else if (!q.empty() && std::all_of(q.begin(), q.end(), ::isdigit)) {
            is_port_search = true;
            port_str = q;
        }

        if (is_port_search && !port_str.empty()) {
            std::string cmd = "lsof -i:" + shell_escape(port_str) + " -n -P 2>/dev/null";
            FILE* pipe = popen(cmd.c_str(), "r");
            if (pipe) {
                char buffer[2048];
                bool is_header = true;
                std::vector<int> seen_pids;
                while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
                    if (is_header) {
                        is_header = false;
                        continue;
                    }
                    std::stringstream ss(buffer);
                    std::string comm, pid_str, user, fd, type, device, size_off, node, name;
                    ss >> comm >> pid_str >> user >> fd >> type >> device >> size_off >> node >> name;
                    try {
                        int pid_num = std::stoi(pid_str);
                        if (std::find(seen_pids.begin(), seen_pids.end(), pid_num) == seen_pids.end()) {
                            seen_pids.push_back(pid_num);
                            items.push_back({
                                {"pid", pid_num},
                                {"name", comm},
                                {"cmd", comm + " [Port " + port_str + "]"},
                                {"port", port_str},
                                {"user", user},
                                {"isPort", true}
                            });
                        }
                    } catch (...) {}
                }
                pclose(pipe);
            }
        } else {
            // Process name search owned by current user
            std::string q_lower = q;
            std::transform(q_lower.begin(), q_lower.end(), q_lower.begin(), ::tolower);

            std::string cmd = "ps -u $USER -o pid=,comm=,%cpu=,%mem=,args= --sort=-%cpu 2>/dev/null";
            FILE* pipe = popen(cmd.c_str(), "r");
            if (pipe) {
                char buffer[4096];
                int count = 0;
                while (fgets(buffer, sizeof(buffer), pipe) != nullptr && count < 25) {
                    std::stringstream ss(buffer);
                    std::string pid_str, comm, cpu_str, mem_str, args;
                    ss >> pid_str >> comm >> cpu_str >> mem_str;
                    std::getline(ss, args);
                    while (!args.empty() && (args.front() == ' ' || args.front() == '\t')) args.erase(args.begin());
                    while (!args.empty() && (args.back() == '\n' || args.back() == '\r')) args.pop_back();

                    if (comm == "ps" || comm == "tools_fetcher") continue;

                    std::string comm_lower = comm;
                    std::transform(comm_lower.begin(), comm_lower.end(), comm_lower.begin(), ::tolower);
                    std::string args_lower = args;
                    std::transform(args_lower.begin(), args_lower.end(), args_lower.begin(), ::tolower);

                    if (q_lower.empty() || comm_lower.find(q_lower) != std::string::npos || args_lower.find(q_lower) != std::string::npos) {
                        try {
                            int pid_num = std::stoi(pid_str);
                            items.push_back({
                                {"pid", pid_num},
                                {"name", comm},
                                {"cpu", cpu_str},
                                {"mem", mem_str},
                                {"cmd", args.empty() ? comm : args},
                                {"isPort", false}
                            });
                            count++;
                        } catch (...) {}
                    }
                }
                pclose(pipe);
            }
        }
        std::cout << json({{"mode", "kill_search"}, {"items", items}}).dump() << std::endl;

    } else if (mode == "kill_proc") {
        bool ok = false;
        int pid_num = 0;
        try {
            pid_num = std::stoi(query);
            if (pid_num > 1) {
                int sig = (extra == "9") ? SIGKILL : SIGTERM;
                ok = (kill(pid_num, sig) == 0);
            }
        } catch (...) {}
        std::cout << json({{"mode", "kill_proc"}, {"success", ok}, {"pid", pid_num}}).dump() << std::endl;
    }

    return 0;
}
