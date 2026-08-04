#include "system_monitor.hpp"

SysDataService::SysDataService(QObject* parent) : QObject(parent) {
    lastCpu = get_cpu_stats();
    lastNet = get_net_stats();
}

QJsonObject SysDataService::getMetrics() {
    CpuStats currentCpu = get_cpu_stats();
    NetStats currentNet = get_net_stats();

    // CPU
    long long idle1 = lastCpu.idle;
    long long total1 = lastCpu.user + lastCpu.nice + lastCpu.system + lastCpu.idle + lastCpu.iowait + lastCpu.irq + lastCpu.softirq + lastCpu.steal;
    long long idle2 = currentCpu.idle;
    long long total2 = currentCpu.user + currentCpu.nice + currentCpu.system + currentCpu.idle + currentCpu.iowait + currentCpu.irq + currentCpu.softirq + currentCpu.steal;

    long long diff_idle = idle2 - idle1;
    long long diff_total = total2 - total1;
    int cpu_usage = 0;
    if (diff_total > 0) {
        cpu_usage = static_cast<int>(100 * (diff_total - diff_idle) / diff_total);
    }

    // Network
    double rx_rate = (currentNet.rx - lastNet.rx);
    double tx_rate = (currentNet.tx - lastNet.tx);
    rx_rate = std::max(0.0, rx_rate / 2.0);
    tx_rate = std::max(0.0, tx_rate / 2.0);

    // RAM
    int ram_pct = 0;
    double ram_gb = 0.0;
    get_mem_stats(ram_pct, ram_gb);

    // Temp
    int temp = get_temp();

    lastCpu = currentCpu;
    lastNet = currentNet;

    QJsonObject obj;
    obj["cpu"] = cpu_usage;
    obj["ramPercent"] = ram_pct;
    obj["ramGb"] = ram_gb;
    obj["temp"] = temp;
    obj["netRx"] = rx_rate;
    obj["netTx"] = tx_rate;
    return obj;
}

CpuStats SysDataService::get_cpu_stats() {
    std::ifstream file("/proc/stat");
    std::string line;
    CpuStats stats;
    if (std::getline(file, line)) {
        std::stringstream ss(line);
        std::string cpu;
        ss >> cpu >> stats.user >> stats.nice >> stats.system >> stats.idle >> stats.iowait >> stats.irq >> stats.softirq >> stats.steal >> stats.guest >> stats.guest_nice;
    }
    return stats;
}

NetStats SysDataService::get_net_stats() {
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

void SysDataService::get_mem_stats(int &percent, double &used_gb) {
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
        percent = static_cast<int>(100 * used / total);
        used_gb = static_cast<double>(used) / (1024 * 1024);
    }
}

int SysDataService::get_temp() {
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
    return 0;
}
