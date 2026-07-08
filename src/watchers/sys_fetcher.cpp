#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <sstream>
#include <unistd.h>
#include <dirent.h>
#include <algorithm>
#include <iomanip>

struct CpuStats {
    long long user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice;
};

CpuStats get_cpu_stats() {
    std::ifstream file("/proc/stat");
    std::string line;
    CpuStats stats = {0};
    if (std::getline(file, line)) {
        std::stringstream ss(line);
        std::string cpu;
        ss >> cpu >> stats.user >> stats.nice >> stats.system >> stats.idle >> stats.iowait >> stats.irq >> stats.softirq >> stats.steal >> stats.guest >> stats.guest_nice;
    }
    return stats;
}

struct NetStats {
    long long rx, tx;
};

NetStats get_net_stats() {
    std::ifstream file("/proc/net/dev");
    std::string line;
    long long total_rx = 0, total_tx = 0;
    while (std::getline(file, line)) {
        size_t colon = line.find(':');
        if (colon == std::string::npos) continue;
        
        std::string interface = line.substr(0, colon);
        interface.erase(0, interface.find_first_not_of(" \t"));
        
        if (interface.empty()) continue;
        char first = std::tolower(interface[0]);
        if (first == 'e' || first == 'w') {
            std::stringstream ss(line.substr(colon + 1));
            long long rx, tx, dummy;
            if (ss >> rx) {
                for (int i = 0; i < 7; ++i) ss >> dummy;
                if (ss >> tx) {
                    total_rx += rx;
                    total_tx += tx;
                }
            }
        }
    }
    return {total_rx, total_tx};
}

void get_mem_stats(int &percent, double &used_gb) {
    std::ifstream file("/proc/meminfo");
    std::string line;
    long long total = 0, avail = 0;
    while (std::getline(file, line)) {
        if (line.compare(0, 8, "MemTotal") == 0) {
            std::stringstream ss(line.substr(9));
            ss >> total;
        } else if (line.compare(0, 12, "MemAvailable") == 0) {
            std::stringstream ss(line.substr(13));
            ss >> avail;
        }
    }
    if (total > 0) {
        long long used = total - avail;
        percent = (int)(100 * used / total);
        used_gb = (double)used / (1024 * 1024);
    }
}

int get_temp() {
    // Attempt 1: hwmon
    const char* hwmon_base = "/sys/class/hwmon/";
    DIR* dir = opendir(hwmon_base);
    if (dir) {
        struct dirent* ent;
        while ((ent = readdir(dir)) != nullptr) {
            if (ent->d_name[0] == '.') continue;
            std::string path = std::string(hwmon_base) + ent->d_name + "/";
            std::ifstream name_file(path + "name");
            std::string name;
            std::getline(name_file, name);
            if (name == "coretemp" || name == "k10temp" || name == "zenpower" || name == "cpu_thermal" || name == "bcm2835_thermal") {
                std::ifstream temp_file(path + "temp1_input");
                int temp;
                if (temp_file >> temp) {
                    closedir(dir);
                    return (temp > 1000) ? temp / 1000 : temp;
                }
            }
        }
        closedir(dir);
    }

    // Attempt 2: thermal_zone
    const char* thermal_base = "/sys/class/thermal/";
    dir = opendir(thermal_base);
    if (dir) {
        struct dirent* ent;
        while ((ent = readdir(dir)) != nullptr) {
            if (std::string(ent->d_name).find("thermal_zone") == 0) {
                std::string path = std::string(thermal_base) + ent->d_name + "/";
                std::ifstream type_file(path + "type");
                std::string type;
                std::getline(type_file, type);
                if (type == "x86_pkg_temp" || type == "cpu_thermal" || type == "cpu-thermal") {
                    std::ifstream temp_file(path + "temp");
                    int temp;
                    if (temp_file >> temp) {
                        closedir(dir);
                        return (temp > 1000) ? temp / 1000 : temp;
                    }
                }
            }
        }
        closedir(dir);
    }
    
    // Attempt 3: Ultimate fallback
    std::ifstream fb1("/sys/class/hwmon/hwmon0/temp1_input");
    int t;
    if (fb1 >> t) return (t > 1000) ? t / 1000 : t;
    std::ifstream fb2("/sys/class/thermal/thermal_zone0/temp");
    if (fb2 >> t) return (t > 1000) ? t / 1000 : t;

    return 0;
}

int main() {
    CpuStats c1 = get_cpu_stats();
    NetStats n1 = get_net_stats();

    usleep(500000); // 0.5s

    CpuStats c2 = get_cpu_stats();
    NetStats n2 = get_net_stats();

    // CPU Calculation
    long long idle1 = c1.idle;
    long long total1 = c1.user + c1.nice + c1.system + c1.idle + c1.iowait + c1.irq + c1.softirq + c1.steal;
    long long idle2 = c2.idle;
    long long total2 = c2.user + c2.nice + c2.system + c2.idle + c2.iowait + c2.irq + c2.softirq + c2.steal;
    
    long long diff_idle = idle2 - idle1;
    long long diff_total = total2 - total1;
    int cpu_usage = 0;
    if (diff_total > 0) {
        cpu_usage = (int)(100 * (diff_total - diff_idle) / diff_total);
    }

    // Network Calculation
    long long rx_rate = (n2.rx - n1.rx) * 2;
    long long tx_rate = (n2.tx - n1.tx) * 2;

    // RAM Calculation
    int ram_pct = 0;
    double ram_gb = 0.0;
    get_mem_stats(ram_pct, ram_gb);

    // Temp Calculation
    int temp = get_temp();

    // Output: CPU|RAM_PCT|RAM_GB|TEMP|RX_RATE|TX_RATE
    std::cout << cpu_usage << "|" << ram_pct << "|" << std::fixed << std::setprecision(1) << ram_gb << "|" << temp << "|" << rx_rate << "|" << tx_rate << std::endl;

    return 0;
}
