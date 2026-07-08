#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <algorithm>
#include <cstdio>
#include <memory>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

// Function to execute a shell command and return its output as a vector of strings
std::vector<std::string> exec_command(const std::string& cmd) {
    std::vector<std::string> lines;
    // Redirect stderr to stdout to capture potential errors
    std::string full_cmd = cmd + " 2>/dev/null";
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(full_cmd.c_str(), "r"), pclose);
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

struct Service {
    std::string unit;
    std::string name;
    std::string load;
    std::string active;
    std::string sub;
    std::string desc;
    bool is_user;
};

// Helper function to trim strings
std::string trim(const std::string& s) {
    auto start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    auto end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

std::vector<Service> get_services(bool is_user) {
    std::string cmd = "systemctl list-units --type=service --all --no-pager --no-legend";
    if (is_user) cmd += " --user";

    std::vector<std::string> lines = exec_command(cmd);
    std::vector<Service> services;

    for (const auto& line : lines) {
        if (line.empty()) continue;

        // systemctl output format: UNIT LOAD ACTIVE SUB DESCRIPTION
        // We use stringstream to extract the first 4 columns
        std::stringstream ss(line);
        std::string unit, load, active, sub;
        
        if (!(ss >> unit >> load >> active >> sub)) continue;

        // The rest of the line is the description
        std::string desc;
        std::getline(ss, desc);
        desc = trim(desc);

        // Filter out not-found or inactive templates (matching Python logic)
        if (load == "not-found") continue;
        if (unit.find('@') != std::string::npos && active == "inactive") continue;

        std::string name = unit;
        size_t dot = name.find_last_of('.');
        if (dot != std::string::npos) name = name.substr(0, dot);

        services.push_back({unit, name, load, active, sub, desc.empty() ? name : desc, is_user});
    }
    return services;
}

int main(int argc, char* argv[]) {
    std::string action = (argc > 1) ? argv[1] : "list";

    if (action == "list") {
        std::vector<Service> user_svcs = get_services(true);
        std::vector<Service> sys_svcs = get_services(false);

        std::vector<Service> all_svcs = user_svcs;
        all_svcs.insert(all_svcs.end(), sys_svcs.begin(), sys_svcs.end());

        // Sort: active services first, then by name
        std::sort(all_svcs.begin(), all_svcs.end(), [](const Service& a, const Service& b) {
            if ((a.active == "active") != (b.active == "active")) {
                return a.active == "active";
            }
            return a.name < b.name;
        });

        json j_array = json::array();
        for (const auto& s : all_svcs) {
            j_array.push_back({
                {"unit", s.unit},
                {"name", s.name},
                {"load", s.load},
                {"active", s.active},
                {"sub", s.sub},
                {"desc", s.desc},
                {"is_user", s.is_user}
            });
        }
        std::cout << j_array.dump() << std::endl;
    } 
    else if (action == "start" || action == "stop" || action == "restart") {
        if (argc < 3) {
            std::cout << "{\"status\":\"error\",\"message\":\"Missing unit name\"}" << std::endl;
            return 1;
        }

        std::string unit = argv[2];
        bool is_user = (argc > 3 && std::string(argv[3]) == "true");

        std::string cmd = "systemctl";
        if (is_user) cmd += " --user";
        cmd += " " + action + " " + unit + " 2>&1";

        std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
        if (!pipe) {
            std::cout << "{\"status\":\"error\",\"message\":\"Failed to run systemctl\"}" << std::endl;
            return 1;
        }

        char buffer[1024];
        std::string result_msg;
        while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
            result_msg += buffer;
        }

        int status = pclose(pipe.release());
        if (status == 0) {
            std::cout << json({{"status", "success"}, {"unit", unit}, {"action", action}}).dump() << std::endl;
        } else {
            std::cout << json({{"status", "error"}, {"message", trim(result_msg)}}).dump() << std::endl;
        }
    }
    else {
        std::cout << "{\"status\":\"error\",\"message\":\"Unknown action\"}" << std::endl;
        return 1;
    }

    return 0;
}
