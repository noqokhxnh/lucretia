#pragma once

#include <QObject>
#include <QJsonObject>
#include <fstream>
#include <sstream>
#include <string>
#include <algorithm>
#include <dirent.h>

struct CpuStats {
    long long user{0}, nice{0}, system{0}, idle{0}, iowait{0}, irq{0}, softirq{0}, steal{0}, guest{0}, guest_nice{0};
};

struct NetStats {
    long long rx{0}, tx{0};
};

class SysDataService : public QObject {
    Q_OBJECT
public:
    explicit SysDataService(QObject* parent = nullptr);

    QJsonObject getMetrics();

private:
    CpuStats lastCpu;
    NetStats lastNet;

    CpuStats get_cpu_stats();
    NetStats get_net_stats();
    void get_mem_stats(int &percent, double &used_gb);
    int get_temp();
};
