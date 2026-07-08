#include <QCoreApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDBusConnectionInterface>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QImage>
#include <QColor>
#include <QPainter>
#include <QPainterPath>
#include <QLinearGradient>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QCryptographicHash>
#include <QTimer>
#include <QDateTime>
#include <QThread>
#include <QTextStream>

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <algorithm>
#include <filesystem>
#include <chrono>
#include <memory>
#include <mutex>
#include <thread>
#include <iomanip>
#include <cmath>
#include <regex>
#include <unistd.h>
#include <dirent.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <csignal>

#include <sqlite3.h>
#include <zbar.h>
#include <nlohmann/json.hpp>

// Focus Time helper
#include "focustime/focus_common.hpp"

using json = nlohmann::json;
namespace fs = std::filesystem;

// -----------------------------------------------------------------------------
// GLOBAL VARS & CONFIG
// -----------------------------------------------------------------------------
const std::pair<QColor, QColor> GRADIENTS[] = {
    {QColor("#cba6f7"), QColor("#89b4fa")}, // Catppuccin Pastel (Mauve to Blue)
    {QColor("#f38ba8"), QColor("#cba6f7")}, // Catppuccin Sunset (Red to Mauve)
    {QColor("#f72585"), QColor("#7209b7")}, // Cyber Neon (Pink to Purple)
    {QColor("#3a7bd5"), QColor("#3a6073")}, // Premium Slate Blue
    {QColor("#00c6ff"), QColor("#0072ff")}, // Vibrant Azure
    {QColor("#ff007f"), QColor("#7f00ff")}, // Electric Magenta to Violet
    {QColor("#a1c4fd"), QColor("#c2e9fb")}, // Elegant Ice Blue
    {QColor("#111726"), QColor("#2d3c59")}, // Luxury Stealth Navy
    {QColor("#fc6767"), QColor("#ec008c")}, // Warm Neon Sunset
    {QColor("#642B73"), QColor("#C6426E")}, // Plum Velvet
    {QColor("#243B55"), QColor("#141E30")}, // Matte Space Gray
    {QColor("#00F260"), QColor("#0575E6")}, // Mint Aurora to Deep Sea
    {QColor("#fa709a"), QColor("#fee140")}, // Soft Coral Pink to Lemon
    {QColor("#1e3c72"), QColor("#2a5298")}, // Deep Royal Navy
    {QColor("#ee0979"), QColor("#ff6a00")}, // High-voltage Citrus
    {QColor("#8A2387"), QColor("#E94057")}, // Cosmic Berry
    {QColor("#ff758c"), QColor("#ff7eb3")}, // Sweet Rose Water
    {QColor("#ff9900"), QColor("#ff5b00")}, // Golden Ember
    {QColor("#4facfe"), QColor("#00f2fe")}, // Cool Aqua
    {QColor("#b224ef"), QColor("#7579ff")}, // Psychedelic Violet
    {QColor("#0250c5"), QColor("#d43f8d")}, // Intense Purple-Pink
    {QColor("#85FFBD"), QColor("#FFFB7D")}, // Fresh Spring Mint
    {QColor("#130CB7"), QColor("#52E5E7")}, // Futuristic Deep Blue to Cyan
    {QColor("#F40076"), QColor("#DF580A")}  // Ignite Orange-Pink
};
constexpr int GRADIENT_COUNT = sizeof(GRADIENTS) / sizeof(GRADIENTS[0]);

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

// -----------------------------------------------------------------------------
// HELPER FUNCTIONS
// -----------------------------------------------------------------------------
std::string trim(const std::string& s) {
    auto start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    auto end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

std::string exec_cmd_sync(const std::string& cmd) {
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen((cmd + " 2>/dev/null").c_str(), "r"), pclose);
    if (!pipe) return "";
    char buffer[4096];
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        result += buffer;
    }
    return result;
}

std::vector<std::string> exec_cmd_sync_lines(const std::string& cmd) {
    std::vector<std::string> lines;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen((cmd + " 2>/dev/null").c_str(), "r"), pclose);
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

// -----------------------------------------------------------------------------
// CLASS: SYSTEM DATA SERVICE
// -----------------------------------------------------------------------------
struct CpuStats {
    long long user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice;
};

struct NetStats {
    long long rx, tx;
};

class SysDataService : public QObject {
    Q_OBJECT
public:
    SysDataService(QObject* parent = nullptr) : QObject(parent) {
        lastCpu = get_cpu_stats();
        lastNet = get_net_stats();
    }

    QJsonObject getMetrics() {
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
            cpu_usage = (int)(100 * (diff_total - diff_idle) / diff_total);
        }

        // Network
        double rx_rate = (currentNet.rx - lastNet.rx);
        double tx_rate = (currentNet.tx - lastNet.tx);
        // Rates are per the measurement interval (currently 2 seconds)
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

private:
    CpuStats lastCpu;
    NetStats lastNet;

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
};

// -----------------------------------------------------------------------------
// CLASS: MUSIC & EQ SERVICE
// -----------------------------------------------------------------------------
struct MusicState {
    QString title = "Not Playing";
    QString artist = "";
    QString status = "Stopped";
    double length = 1;
    double position = 0;
    QString lengthStr = "00:00";
    QString positionStr = "00:00";
    QString timeStr = "00:00 / 00:00";
    int percent = 0;
    QString source = "Offline";
    QString playerName = "";
    QString blur = "";
    QString grad = "linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)";
    QString textColor = "#cdd6f4";
    QString deviceIcon = "󰓃";
    QString deviceName = "Speaker";
    QString artUrl = "";
};

class MusicService : public QObject {
    Q_OBJECT
public:
    MusicService(QObject* parent = nullptr) : QObject(parent) {
        manager = new QNetworkAccessManager(this);
    }

    QJsonObject fetchState() {
        MusicState data = fetchDataInternal();
        QJsonObject obj;
        obj["title"] = data.title;
        obj["artist"] = data.artist;
        obj["status"] = data.status;
        obj["length"] = data.length;
        obj["position"] = data.position;
        obj["lengthStr"] = data.lengthStr;
        obj["positionStr"] = data.positionStr;
        obj["timeStr"] = data.timeStr;
        obj["percent"] = data.percent;
        obj["source"] = data.source;
        obj["playerName"] = data.playerName;
        obj["blur"] = data.blur;
        obj["grad"] = data.grad;
        obj["textColor"] = data.textColor;
        obj["deviceIcon"] = data.deviceIcon;
        obj["deviceName"] = data.deviceName;
        obj["artUrl"] = data.artUrl;
        return obj;
    }

    void handleControl(const QString& action, const QString& arg1 = "", const QString& arg2 = "") {
        QDBusConnection bus = QDBusConnection::sessionBus();
        QStringList services = bus.interface()->registeredServiceNames();
        QString playerService = "";
        
        for (const QString &service : services) {
            if (service.startsWith("org.mpris.MediaPlayer2.")) {
                QDBusInterface player(service, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus);
                QVariant status = getProperty(player, "PlaybackStatus");
                if (status.toString() == "Playing") {
                    playerService = service;
                    break;
                }
                if (playerService.isEmpty()) playerService = service;
            }
        }

        if (playerService.isEmpty()) return;

        QDBusInterface player(playerService, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", bus);
        if (action == "next") player.call("Next");
        else if (action == "prev") player.call("Previous");
        else if (action == "play-pause") player.call("PlayPause");
        else if (action == "seek") {
            double perc = arg1.toDouble();
            double len = arg2.toDouble();
            double target = (len * perc) / 100.0;
            QProcess::startDetached("playerctl", {"-p", playerService.mid(23), "position", QString::number(target, 'f', 2)});
        }
    }

    QJsonObject getEqState() {
        QFile file(getRunDir() + "/eq_state.json");
        QJsonObject obj;
        if (file.open(QIODevice::ReadOnly)) {
            obj = QJsonDocument::fromJson(file.readAll()).object();
        } else {
            for (int i = 1; i <= 10; ++i) obj["b" + QString::number(i)] = "0";
            obj["preset"] = "Flat";
            obj["pending"] = false;
        }
        return obj;
    }

    void setEqBand(const QString& idx, const QString& val) {
        QString path = getRunDir() + "/eq_state.json";
        QFile file(path);
        QJsonObject obj;
        if (file.open(QIODevice::ReadOnly)) {
            obj = QJsonDocument::fromJson(file.readAll()).object();
            file.close();
        }
        obj["b" + idx] = val;
        obj["preset"] = "Custom";
        obj["pending"] = true;
        if (file.open(QIODevice::WriteOnly)) {
            file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
        }
    }

    void applyPreset(const QString& name) {
        QJsonObject obj;
        auto set = [&](QList<int> vals) {
            for (int i = 0; i < 10; ++i) obj["b" + QString::number(i + 1)] = QString::number(vals[i]);
        };

        if (name == "Flat") set({0,0,0,0,0,0,0,0,0,0});
        else if (name == "Bass") set({5,7,5,2,1,0,0,0,1,2});
        else if (name == "Treble") set({-2,-1,0,1,2,3,4,5,6,6});
        else if (name == "Vocal") set({-2,-1,1,3,5,5,4,2,1,0});
        else if (name == "Pop") set({2,4,2,0,1,2,4,2,1,2});
        else if (name == "Rock") set({5,4,2,-1,-2,-1,2,4,5,6});
        else if (name == "Jazz") set({3,3,1,1,1,1,2,1,2,3});
        else if (name == "Classic") set({0,1,2,2,2,2,1,2,3,4});

        obj["preset"] = name;
        obj["pending"] = false;
        
        QFile file(getRunDir() + "/eq_state.json");
        if (file.open(QIODevice::WriteOnly)) {
            file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
            file.close();
            applyEq();
        }
    }

    void applyEq() {
        QString path = getRunDir() + "/eq_state.json";
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) return;
        QJsonObject data = QJsonDocument::fromJson(file.readAll()).object();
        file.close();

        // Mark as not pending
        data["pending"] = false;
        if (file.open(QIODevice::WriteOnly)) {
            file.write(QJsonDocument(data).toJson(QJsonDocument::Compact));
            file.close();
        }

        // Generate EasyEffects JSON
        QMap<int, int> sliderMap = {{0,0}, {1,3}, {2,6}, {3,9}, {4,12}, {5,15}, {6,18}, {7,21}, {8,24}, {9,27}};
        QList<int> freqs = {32, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000, 22000, 24000, 24000};
        
        QJsonObject bands;
        for (int i = 0; i < 32; ++i) {
            double gain = 0.0;
            for (auto it = sliderMap.begin(); it != sliderMap.end(); ++it) {
                if (i == it.value()) {
                    gain = data["b" + QString::number(it.key() + 1)].toString().toDouble();
                    break;
                }
            }
            QJsonObject band;
            band["frequency"] = (double)freqs[i];
            band["gain"] = gain;
            band["mode"] = "Bell";
            band["mute"] = false;
            band["q"] = 1.0;
            band["solo"] = false;
            band["width"] = 1.0;
            band["slope"] = "x1";
            bands["band" + QString::number(i)] = band;
        }

        QJsonObject equalizer;
        equalizer["bypass"] = false;
        equalizer["input-gain"] = 0.0;
        equalizer["output-gain"] = 0.0;
        equalizer["left"] = bands;
        equalizer["right"] = bands;
        equalizer["mode"] = "IIR";
        equalizer["num-bands"] = 32;
        equalizer["split-channels"] = false;

        QJsonObject output;
        output["blocklist"] = QJsonArray();
        output["plugins_order"] = QJsonArray({"equalizer"});
        output["equalizer"] = equalizer;

        QJsonObject root;
        root["output"] = output;

        QString home = qgetenv("HOME");
        QString presetFile = home + "/.local/share/easyeffects/output/live_eq.json";
        QDir().mkpath(home + "/.local/share/easyeffects/output");
        
        QFile pFile(presetFile);
        if (pFile.open(QIODevice::WriteOnly)) {
            pFile.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
            pFile.close();
            QProcess::startDetached("easyeffects", {"-l", "live_eq"});
        }
    }

private:
    QNetworkAccessManager* manager;

    QString getRunDir() {
        QString runDir = qgetenv("QS_RUN_MUSIC");
        if (runDir.isEmpty()) {
            QString xdgRuntime = qgetenv("XDG_RUNTIME_DIR");
            if (xdgRuntime.isEmpty()) xdgRuntime = "/tmp";
            runDir = xdgRuntime + "/quickshell/music";
        }
        QDir().mkpath(runDir);
        return runDir;
    }

    QVariant getProperty(QDBusInterface &iface, const QString &prop) {
        QDBusReply<QVariant> reply = iface.call("Get", "org.mpris.MediaPlayer2.Player", prop);
        if (reply.isValid()) {
            QVariant v = reply.value();
            if (v.canConvert<QDBusVariant>()) return v.value<QDBusVariant>().variant();
            return v;
        }
        return QVariant();
    }

    void processImage(const QString &input, const QString &outputBlur, const QString &outputGrad, const QString &outputText, MusicState *data) {
        QImage img;
        if (!img.load(input)) return;

        // 1. Blur
        int blurScale = 16;
        QImage blurred = img.scaled(img.width() / blurScale, img.height() / blurScale, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        for (int y = 0; y < blurred.height(); ++y) {
            for (int x = 0; x < blurred.width(); ++x) {
                QColor c = blurred.pixelColor(x, y);
                int r = qBound(0, (int)((c.red() - 128) * 0.9 + 128 - 30), 255);
                int g = qBound(0, (int)((c.green() - 128) * 0.9 + 128 - 30), 255);
                int b = qBound(0, (int)((c.blue() - 128) * 0.9 + 128 - 30), 255);
                blurred.setPixelColor(x, y, QColor(r, g, b));
            }
        }
        blurred = blurred.scaled(500, 500, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        blurred.save(outputBlur, "PNG");
        data->blur = outputBlur;
        data->artUrl = input;

        // 2. Gradients
        QImage small = img.scaled(50, 50, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        QMap<QString, int> colorCounts;
        for (int y = 0; y < small.height(); ++y) {
            for (int x = 0; x < small.width(); ++x) {
                QString hex = small.pixelColor(x, y).name();
                colorCounts[hex]++;
            }
        }
        QList<QString> sortedColors = colorCounts.keys();
        std::sort(sortedColors.begin(), sortedColors.end(), [&](const QString &a, const QString &b){
            return colorCounts[a] > colorCounts[b];
        });

        QString c1 = sortedColors.size() > 0 ? sortedColors[0] : "#cba6f7";
        QString c2 = sortedColors.size() > 1 ? sortedColors[1] : c1;
        QString c3 = sortedColors.size() > 2 ? sortedColors[2] : c1;

        data->grad = QString("linear-gradient(45deg, %1, %2, %3, %1)").arg(c1, c2, c3);
        QFile fGrad(outputGrad);
        if (fGrad.open(QIODevice::WriteOnly)) fGrad.write(data->grad.toUtf8());

        // 3. Text Contrast
        QColor col1(c1);
        double luminance = (0.299 * col1.red() + 0.587 * col1.green() + 0.114 * col1.blue()) / 255.0;
        data->textColor = luminance > 0.5 ? "#11111b" : "#cdd6f4";
        QFile fText(outputText);
        if (fText.open(QIODevice::WriteOnly)) fText.write(data->textColor.toUtf8());
    }

    void fetchDeviceInfo(MusicState *data) {
        QProcess proc;
        proc.start("wpctl", QStringList() << "inspect" << "@DEFAULT_AUDIO_SINK@");
        if (proc.waitForFinished(500)) {
            QString out = proc.readAllStandardOutput();
            QString name, desc;
            for (const QString &line : out.split("\n")) {
                if (line.contains("node.name")) {
                    auto parts = line.split("\"");
                    if (parts.size() > 1) name = parts.at(1);
                }
                if (line.contains("node.description")) {
                    auto parts = line.split("\"");
                    if (parts.size() > 1) desc = parts.at(1);
                }
            }

            if (name.contains("bluez")) {
                data->deviceIcon = "󰂯";
                data->deviceName = desc.isEmpty() ? "Bluetooth" : desc;
            } else if (name.contains("usb")) {
                data->deviceIcon = "󰓃";
                data->deviceName = "USB Audio";
            } else if (name.contains("pci")) {
                data->deviceIcon = "󰓃";
                data->deviceName = "System";
            } else if (!desc.isEmpty()) {
                data->deviceName = desc;
            }
        }
    }

    MusicState fetchDataInternal() {
        MusicState data;
        QString runDir = getRunDir();
        QString coversDir = runDir + "/covers";
        QDir().mkpath(coversDir);
        QString placeholder = coversDir + "/placeholder_blank.png";
        
        if (!QFile::exists(placeholder)) {
            QImage img(500, 500, QImage::Format_RGB32);
            img.fill(QColor("#313244"));
            img.save(placeholder);
        }
        
        data.artUrl = placeholder;
        data.blur = placeholder;

        QDBusConnection bus = QDBusConnection::sessionBus();
        QStringList services = bus.interface()->registeredServiceNames();
        QString playerService = "";
        
        for (const QString &service : services) {
            if (service.startsWith("org.mpris.MediaPlayer2.")) {
                QDBusInterface player(service, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus);
                QVariant status = getProperty(player, "PlaybackStatus");
                if (status.toString() == "Playing") {
                    playerService = service;
                    break;
                }
                if (playerService.isEmpty()) playerService = service;
            }
        }

        if (!playerService.isEmpty()) {
            QDBusInterface player(playerService, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus);
            QString status = getProperty(player, "PlaybackStatus").toString();
            if (!status.isEmpty()) data.status = status;

            QVariant vMeta = getProperty(player, "Metadata");
            QVariantMap metadata;
            if (vMeta.canConvert<QVariantMap>()) {
                metadata = vMeta.toMap();
            } else {
                metadata = qdbus_cast<QVariantMap>(vMeta);
            }
            
            if (!metadata.isEmpty()) {
                QString title = metadata.value("xesam:title").toString();
                if (!title.isEmpty()) data.title = title;
                else data.title = "Unknown Track";

                QVariant artistVar = metadata.value("xesam:artist");
                QString artist;
                if (artistVar.canConvert<QStringList>()) {
                    artist = artistVar.toStringList().join(", ");
                } else {
                    artist = artistVar.toString();
                }
                if (!artist.isEmpty()) data.artist = artist;
                else data.artist = "Unknown Artist";
                
                long long len_micro = 0;
                if (metadata.contains("mpris:length")) {
                    len_micro = metadata.value("mpris:length").toLongLong();
                }
                
                data.length = len_micro / 1000000.0;
                data.position = getProperty(player, "Position").toLongLong() / 1000000.0;
                
                data.playerName = playerService.mid(23); 
                data.source = data.playerName;
                if (!data.source.isEmpty()) data.source[0] = data.source[0].toUpper();

                if (data.length > 0) {
                    data.lengthStr = QString("%1:%2").arg((int)data.length / 60, 2, 10, QChar('0')).arg((int)data.length % 60, 2, 10, QChar('0'));
                } else {
                    data.lengthStr = "00:00";
                }
                
                data.positionStr = QString("%1:%2").arg((int)data.position / 60, 2, 10, QChar('0')).arg((int)data.position % 60, 2, 10, QChar('0'));
                data.timeStr = data.positionStr + " / " + data.lengthStr;
                
                if (data.length > 1) {
                    data.percent = (int)((data.position * 100.0) / data.length);
                } else {
                    data.percent = 0;
                }
                
                if (data.percent > 100) data.percent = 100;
                if (data.percent < 0) data.percent = 0;

                QString rawArtUrl = metadata.value("mpris:artUrl").toString();
                if (!rawArtUrl.isEmpty()) {
                    QString hash = QCryptographicHash::hash(rawArtUrl.toUtf8(), QCryptographicHash::Md5).toHex();
                    QString cachedArt = coversDir + "/" + hash + "_art.jpg";
                    QString cachedBlur = coversDir + "/" + hash + "_blur.png";
                    QString cachedGrad = coversDir + "/" + hash + "_grad.txt";
                    QString cachedText = coversDir + "/" + hash + "_text.txt";

                    if (QFile::exists(cachedArt) && QFile::exists(cachedBlur)) {
                        data.artUrl = cachedArt;
                        data.blur = cachedBlur;
                        QFile fG(cachedGrad); if (fG.open(QIODevice::ReadOnly)) data.grad = fG.readAll();
                        QFile fT(cachedText); if (fT.open(QIODevice::ReadOnly)) data.textColor = fT.readAll();
                    } else {
                        bool downloaded = false;
                        if (rawArtUrl.startsWith("http")) {
                            QNetworkRequest req((QUrl(rawArtUrl)));
                            QNetworkReply *rep = manager->get(req);
                            QEventLoop loop;
                            QObject::connect(rep, &QNetworkReply::finished, &loop, &QEventLoop::quit);
                            loop.exec();
                            if (rep->error() == QNetworkReply::NoError) {
                                QFile f(cachedArt);
                                if (f.open(QIODevice::WriteOnly)) { f.write(rep->readAll()); downloaded = true; }
                            }
                            rep->deleteLater();
                        } else {
                            QString path = rawArtUrl;
                            if (path.startsWith("file://")) path = path.mid(7);
                            if (QFile::exists(path)) { if (QFile::copy(path, cachedArt)) downloaded = true; }
                        }
                        if (downloaded) processImage(cachedArt, cachedBlur, cachedGrad, cachedText, &data);
                    }
                }
            }
        }

        fetchDeviceInfo(&data);
        return data;
    }
};

// -----------------------------------------------------------------------------
// CLASS: FOCUS TIME STATS & DAEMON SERVICE
// -----------------------------------------------------------------------------
class FocusService : public QObject {
    Q_OBJECT
public:
    FocusService(QObject* parent = nullptr) : QObject(parent), db(nullptr) {
        // Startup Focus Tracker
        std::string db_dir = std::getenv("QS_STATE_FOCUSTIME") ? std::getenv("QS_STATE_FOCUSTIME") : 
                             std::string(std::getenv("HOME")) + "/.local/state/quickshell/focustime";
        fs::create_directories(db_dir);
        db_path = db_dir + "/focustime.db";
        db = focus_common::init_db(db_path);

        run_dir = std::getenv("QS_RUN_FOCUSTIME") ? std::getenv("QS_RUN_FOCUSTIME") : "/tmp/quickshell/focustime";
        fs::create_directories(run_dir);

        // Start Niri listener socket thread
        std::thread([this]() {
            this->runNiriListener();
        }).detach();

        // Start logging logic timer
        QTimer* timer = new QTimer(this);
        connect(timer, &QTimer::timeout, this, &FocusService::onTick);
        timer->start(1000);
    }

    ~FocusService() {
        if (db) sqlite3_close(db);
    }

    QJsonObject getStats(const QString& dateStr, const QString& appFilter = "") {
        QJsonObject root;
        if (!db) return root;

        std::string app_filter_std = appFilter.toStdString();
        std::string target_date_str = dateStr.toStdString();
        if (target_date_str.empty()) {
            auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
            std::tm tm = *std::localtime(&now);
            std::ostringstream oss;
            oss << std::put_time(&tm, "%Y-%m-%d");
            target_date_str = oss.str();
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
            if (app_filter_std.empty()) return base;
            std::string res = base;
            if (res.find("WHERE") != std::string::npos) res += " AND app_class = ?";
            else res += " WHERE app_class = ?";
            return res;
        };

        sqlite3_stmt* stmt;
        auto get_sum = [&](const std::string& sql, const std::vector<std::string>& params) -> int {
            std::string q = build_query(sql);
            if (sqlite3_prepare_v2(db, q.c_str(), -1, &stmt, nullptr) != SQLITE_OK) return 0;
            for (size_t i = 0; i < params.size(); ++i) sqlite3_bind_text(stmt, i + 1, params[i].c_str(), -1, SQLITE_STATIC);
            if (!app_filter_std.empty()) sqlite3_bind_text(stmt, params.size() + 1, app_filter_std.c_str(), -1, SQLITE_STATIC);
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
            if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 3, app_filter_std.c_str(), -1, SQLITE_STATIC);
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                days_count = sqlite3_column_int(stmt, 0);
                total_week = sqlite3_column_int(stmt, 1);
            }
        }
        sqlite3_finalize(stmt);
        int average_seconds = (days_count > 0) ? (total_week / days_count) : 0;

        // Apps list
        QJsonArray appsArray;
        std::string q_apps = build_query("SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date = ?");
        q_apps += " GROUP BY app_class ORDER BY secs DESC";
        if (sqlite3_prepare_v2(db, q_apps.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, target_date_str.c_str(), -1, SQLITE_STATIC);
            if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 2, app_filter_std.c_str(), -1, SQLITE_STATIC);
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                std::string cls = (const char*)sqlite3_column_text(stmt, 0);
                std::string name = (const char*)sqlite3_column_text(stmt, 1);
                int secs = sqlite3_column_int(stmt, 2);
                QJsonObject appObj;
                appObj["class"] = QString::fromStdString(cls);
                appObj["name"] = QString::fromStdString(name);
                appObj["icon"] = QString::fromStdString(focus_common::get_app_icon(cls));
                appObj["seconds"] = secs;
                appObj["percent"] = total_seconds > 0 ? std::round((secs * 1000.0) / total_seconds) / 10.0 : 0.0;
                appsArray.append(appObj);
            }
        }
        sqlite3_finalize(stmt);

        // Week data
        QJsonArray weekArray;
        std::map<std::string, int> week_map;
        std::string q_week = build_query("SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ?");
        q_week += " GROUP BY log_date";
        if (sqlite3_prepare_v2(db, q_week.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
            sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
            if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 3, app_filter_std.c_str(), -1, SQLITE_STATIC);
            while (sqlite3_step(stmt) == SQLITE_ROW) week_map[(const char*)sqlite3_column_text(stmt, 0)] = sqlite3_column_int(stmt, 1);
        }
        sqlite3_finalize(stmt);
        std::vector<std::string> days_abbr = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
        for (int i = 0; i < 7; ++i) {
            std::string d_str = get_iso_date(monday_time + i * 24 * 3600);
            QJsonObject dayObj;
            dayObj["date"] = QString::fromStdString(d_str);
            dayObj["day"] = QString::fromStdString(days_abbr[i]);
            dayObj["total"] = week_map[d_str];
            dayObj["is_target"] = (d_str == target_date_str);
            weekArray.append(dayObj);
        }

        // Hourly
        QJsonArray hourlyArray;
        std::vector<int> hourly_data(48, 0);
        std::string q_hour = build_query("SELECT hour, SUM(seconds) FROM focus_hourly WHERE log_date = ?");
        if (sqlite3_prepare_v2(db, (q_hour + " GROUP BY hour").c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, target_date_str.c_str(), -1, SQLITE_STATIC);
            if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 2, app_filter_std.c_str(), -1, SQLITE_STATIC);
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                int hr = sqlite3_column_int(stmt, 0);
                if (hr >= 0 && hr < 24) hourly_data[hr * 2] += sqlite3_column_int(stmt, 1);
            }
        }
        sqlite3_finalize(stmt);
        for(int h : hourly_data) hourlyArray.append(h);

        // Week Heatmap (7 days, 24 hours per day)
        std::vector<std::vector<int>> heatmap_matrix(7, std::vector<int>(24, 0));
        std::string q_heatmap = build_query("SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date >= ? AND log_date <= ?");
        q_heatmap += " GROUP BY log_date, hour";
        if (sqlite3_prepare_v2(db, q_heatmap.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, monday_str.c_str(), -1, SQLITE_STATIC);
            sqlite3_bind_text(stmt, 2, sunday_str.c_str(), -1, SQLITE_STATIC);
            if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 3, app_filter_std.c_str(), -1, SQLITE_STATIC);
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

        QJsonArray weekHeatmapArray;
        for (int d = 0; d < 7; ++d) {
            QJsonArray dayArray;
            for (int h = 0; h < 24; ++h) {
                dayArray.append(heatmap_matrix[d][h]);
            }
            weekHeatmapArray.append(dayArray);
        }

        // Month Data
        QJsonArray monthArray;
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
            QJsonObject padObj;
            padObj["date"] = "";
            padObj["total"] = -1;
            padObj["is_target"] = false;
            monthArray.append(padObj);
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

        if (sqlite3_prepare_v2(db, q_month.c_str(), -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, like_pattern, -1, SQLITE_TRANSIENT);
            if (!app_filter_std.empty()) sqlite3_bind_text(stmt, 2, app_filter_std.c_str(), -1, SQLITE_STATIC);
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
            
            QJsonObject dayObj;
            dayObj["date"] = QString::fromStdString(date_str);
            dayObj["total"] = total;
            dayObj["is_target"] = is_tgt;
            monthArray.append(dayObj);
        }

        int total_items = start_pad + num_days;
        int end_pad = (7 - (total_items % 7)) % 7;
        for (int i = 0; i < end_pad; ++i) {
            QJsonObject padObj;
            padObj["date"] = "";
            padObj["total"] = -1;
            padObj["is_target"] = false;
            monthArray.append(padObj);
        }

        root["selected_date"] = QString::fromStdString(target_date_str);
        root["total"] = total_seconds;
        root["average"] = average_seconds;
        root["week_range"] = QString::fromStdString(week_range_str);
        root["yesterday"] = yesterday_seconds;
        root["current"] = appFilter.isEmpty() ? "History" : appFilter;
        root["apps"] = appsArray;
        root["week"] = weekArray;
        root["hourly"] = hourlyArray;
        root["week_heatmap"] = weekHeatmapArray;
        root["peak_usage_str"] = "N/A";
        root["month"] = monthArray;

        return root;
    }

private:
    sqlite3* db;
    std::string db_path;
    std::string run_dir;

    std::string current_class = "Desktop";
    std::string current_title = "Desktop";
    std::mutex state_mutex;

    struct LogEntry {
        std::string date;
        std::string cls;
        std::string title;
        int hour;
        int minute;
    };
    std::vector<LogEntry> buffer;
    int tick_counter = 0;

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

    std::string get_active_window_info() {
        return exec_cmd_sync("niri msg --json windows");
    }

    void update_active_window() {
        if (is_locked()) {
            std::lock_guard<std::mutex> lock(state_mutex);
            current_class = "Locked";
            current_title = "Locked";
            return;
        }
        std::string info_json = get_active_window_info();
        if (info_json.empty() || info_json == "[]" || info_json == "null") {
            std::lock_guard<std::mutex> lock(state_mutex);
            current_class = "Desktop";
            current_title = "Desktop";
            return;
        }
        try {
            auto data = json::parse(info_json);
            if (data.is_array()) {
                bool found = false;
                for (auto& item : data) {
                    if (item.value("is_focused", false)) {
                        std::string cls = item.value("app_id", "Unknown");
                        std::string title = item.value("title", "Unknown");
                        
                        if (cls.find("quickshell") != std::string::npos) {
                            cls = "Quickshell";
                            title = "Quickshell";
                        }
                        std::string clean_title = focus_common::resolve_app_name(cls, title);
                        
                        std::lock_guard<std::mutex> lock(state_mutex);
                        current_class = cls;
                        current_title = clean_title;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    std::lock_guard<std::mutex> lock(state_mutex);
                    current_class = "Desktop";
                    current_title = "Desktop";
                }
            } else {
                std::lock_guard<std::mutex> lock(state_mutex);
                current_class = "Desktop";
                current_title = "Desktop";
            }
        } catch (...) {
            std::lock_guard<std::mutex> lock(state_mutex);
            current_class = "Unknown";
            current_title = "Unknown";
        }
    }

    bool is_locked() {
        return system("pgrep -f Lock.qml > /dev/null") == 0;
    }

    void runNiriListener() {
        const char* niri_socket = std::getenv("NIRI_SOCKET");
        if (!niri_socket) return;

        std::string sock_path = niri_socket;

        while (true) {
            int sock = socket(AF_UNIX, SOCK_STREAM, 0);
            if (sock < 0) { std::this_thread::sleep_for(std::chrono::seconds(2)); continue; }

            struct sockaddr_un addr;
            memset(&addr, 0, sizeof(addr));
            addr.sun_family = AF_UNIX;
            strncpy(addr.sun_path, sock_path.c_str(), sizeof(addr.sun_path) - 1);

            if (::connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
                close(sock);
                std::this_thread::sleep_for(std::chrono::seconds(2));
                continue;
            }

            // Start the event stream
            std::string req = "\"EventStream\"\n";
            if (send(sock, req.c_str(), req.length(), 0) < 0) {
                close(sock);
                std::this_thread::sleep_for(std::chrono::seconds(2));
                continue;
            }

            char buffer[4096];
            std::string stream_data = "";
            while (true) {
                ssize_t n = recv(sock, buffer, sizeof(buffer) - 1, 0);
                if (n <= 0) break;
                buffer[n] = '\0';
                stream_data += buffer;

                size_t pos;
                while ((pos = stream_data.find('\n')) != std::string::npos) {
                    std::string line = stream_data.substr(0, pos);
                    stream_data.erase(0, pos + 1);
                    if (!line.empty()) {
                        // Check if the event signifies a focus change or window change
                        if (line.find("WindowFocusChanged") != std::string::npos ||
                            line.find("WindowOpenedOrChanged") != std::string::npos ||
                            line.find("WorkspaceActivated") != std::string::npos) {
                            update_active_window();
                        }
                    }
                }
            }
            close(sock);
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }

    void onTick() {
        tick_counter++;
        auto now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        std::tm* now_tm = std::localtime(&now);
        char date_buf[16];
        std::strftime(date_buf, sizeof(date_buf), "%Y-%m-%d", now_tm);
        
        LogEntry entry;
        {
            std::lock_guard<std::mutex> lock(state_mutex);
            entry = {date_buf, current_class, current_title, now_tm->tm_hour, now_tm->tm_min};
        }
        
        if (!entry.cls.empty()) buffer.push_back(entry);



        // SQLite write logic
        if (buffer.size() >= 15) {
            std::map<std::pair<std::string, std::string>, int> daily;
            std::map<std::tuple<std::string, int, std::string>, int> hourly;
            for (const auto& e : buffer) {
                daily[{e.date, e.cls}]++;
                hourly[{e.date, e.hour, e.cls}]++;
            }

            sqlite3_exec(db, "BEGIN TRANSACTION;", nullptr, nullptr, nullptr);
            for (auto const& [key, secs] : daily) {
                sqlite3_stmt* stmt;
                sqlite3_prepare_v2(db, "INSERT INTO focus_log (log_date, app_class, seconds, app_title) VALUES (?, ?, ?, ?) ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?", -1, &stmt, nullptr);
                sqlite3_bind_text(stmt, 1, key.first.c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_text(stmt, 2, key.second.c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_int(stmt, 3, secs);
                sqlite3_bind_text(stmt, 4, key.second.c_str(), -1, SQLITE_STATIC); 
                sqlite3_bind_int(stmt, 5, secs);
                sqlite3_step(stmt);
                sqlite3_finalize(stmt);
            }
            for (auto const& [key, secs] : hourly) {
                sqlite3_stmt* stmt;
                sqlite3_prepare_v2(db, "INSERT INTO focus_hourly (log_date, hour, app_class, seconds) VALUES (?, ?, ?, ?) ON CONFLICT(log_date, hour, app_class) DO UPDATE SET seconds = seconds + ?", -1, &stmt, nullptr);
                sqlite3_bind_text(stmt, 1, std::get<0>(key).c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_int(stmt, 2, std::get<1>(key));
                sqlite3_bind_text(stmt, 3, std::get<2>(key).c_str(), -1, SQLITE_STATIC);
                sqlite3_bind_int(stmt, 4, secs);
                sqlite3_bind_int(stmt, 5, secs);
                sqlite3_step(stmt);
                sqlite3_finalize(stmt);
            }
            sqlite3_exec(db, "COMMIT;", nullptr, nullptr, nullptr);
            buffer.clear();
        }
    }
};

// -----------------------------------------------------------------------------
// CORE SERVICE ROUTER & SERVER
// -----------------------------------------------------------------------------
class DaemonServer : public QObject {
    Q_OBJECT
public:
    DaemonServer(QObject* parent = nullptr) : QObject(parent) {
        sysDataSvc = new SysDataService(this);
        musicSvc = new MusicService(this);
        focusSvc = new FocusService(this);
        netManager = new QNetworkAccessManager(this);

        // Preload desktop apps
        scanDesktopApps();

        // Socket server initialization
        server = new QLocalServer(this);
        QString sockPath = "/tmp/quickshell_qs_daemon.sock";
        QLocalServer::removeServer(sockPath);
        if (!server->listen(sockPath)) {
            std::cerr << "Failed to start Local UNIX Socket server!" << std::endl;
            QCoreApplication::exit(1);
        }

        connect(server, &QLocalServer::newConnection, this, &DaemonServer::onNewConnection);

        // Periodically broadcast resource utilization to subscribed clients
        QTimer* sysTimer = new QTimer(this);
        connect(sysTimer, &QTimer::timeout, this, &DaemonServer::broadcastSysData);
        sysTimer->start(2000);

        // Periodically broadcast music position/track state to subscribed clients
        QTimer* musicTimer = new QTimer(this);
        connect(musicTimer, &QTimer::timeout, this, &DaemonServer::broadcastMusicData);
        musicTimer->start(1000);
    }

private slots:
    void onNewConnection() {
        QLocalSocket* client = server->nextPendingConnection();
        connect(client, &QLocalSocket::readyRead, this, [this, client]() {
            this->onClientReadyRead(client);
        });
        connect(client, &QLocalSocket::disconnected, this, [this, client]() {
            this->onClientDisconnected(client);
        });
        clients.append(client);
    }

    void onClientDisconnected(QLocalSocket* client) {
        clients.removeAll(client);
        sysSubscribers.removeAll(client);
        musicSubscribers.removeAll(client);
        client->deleteLater();
    }

    void onClientReadyRead(QLocalSocket* client) {
        while (client->canReadLine()) {
            QByteArray line = client->readLine().trimmed();
            if (line.isEmpty()) continue;
            processRequest(client, line);
        }
    }

    void broadcastSysData() {
        if (sysSubscribers.isEmpty()) return;
        QJsonObject metrics = sysDataSvc->getMetrics();
        QJsonObject event;
        event["event"] = "sysdata";
        event["data"] = metrics;
        QByteArray data = QJsonDocument(event).toJson(QJsonDocument::Compact) + "\n";
        for (auto* c : sysSubscribers) c->write(data);
    }

    void broadcastMusicData() {
        if (musicSubscribers.isEmpty()) return;
        QJsonObject state = musicSvc->fetchState();
        QJsonObject event;
        event["event"] = "music";
        event["data"] = state;
        QByteArray data = QJsonDocument(event).toJson(QJsonDocument::Compact) + "\n";
        for (auto* c : musicSubscribers) c->write(data);
    }

private:
    QLocalServer* server;
    QList<QLocalSocket*> clients;
    QList<QLocalSocket*> sysSubscribers;
    QList<QLocalSocket*> musicSubscribers;

    SysDataService* sysDataSvc;
    MusicService* musicSvc;
    FocusService* focusSvc;
    QNetworkAccessManager* netManager;

    // Desktop apps cache
    struct DesktopApp {
        std::string name;
        std::string exec;
        std::string icon;
    };
    std::vector<DesktopApp> desktopApps;

    void sendResponse(QLocalSocket* client, const QString& reqId, const QJsonObject& result, const QString& status = "success") {
        QJsonObject resp;
        resp["id"] = reqId;
        resp["status"] = status;
        resp["result"] = result;
        client->write(QJsonDocument(resp).toJson(QJsonDocument::Compact) + "\n");
        client->flush();
    }

    void sendResponse(QLocalSocket* client, const QString& reqId, const QJsonArray& result, const QString& status = "success") {
        QJsonObject resp;
        resp["id"] = reqId;
        resp["status"] = status;
        resp["result"] = result;
        client->write(QJsonDocument(resp).toJson(QJsonDocument::Compact) + "\n");
        client->flush();
    }

    void sendResponse(QLocalSocket* client, const QString& reqId, const QString& textResult, const QString& status = "success") {
        QJsonObject resp;
        resp["id"] = reqId;
        resp["status"] = status;
        resp["result"] = textResult;
        client->write(QJsonDocument(resp).toJson(QJsonDocument::Compact) + "\n");
        client->flush();
    }

    void processRequest(QLocalSocket* client, const QByteArray& rawJson) {
        QJsonDocument doc = QJsonDocument::fromJson(rawJson);
        if (!doc.isObject()) return;
        QJsonObject req = doc.object();

        QString reqId = req["id"].toString();
        QString target = req["target"].toString();
        QString action = req["action"].toString();

        // ---------------------------------------------------------------------
        // SUBSCRIPTION ROUTING
        // ---------------------------------------------------------------------
        if (target == "sysdata") {
            if (action == "subscribe") {
                if (!sysSubscribers.contains(client)) sysSubscribers.append(client);
                sendResponse(client, reqId, "subscribed");
            } else if (action == "unsubscribe") {
                sysSubscribers.removeAll(client);
                sendResponse(client, reqId, "unsubscribed");
            }
        } 
        else if (target == "music") {
            if (action == "subscribe") {
                if (!musicSubscribers.contains(client)) musicSubscribers.append(client);
                sendResponse(client, reqId, "subscribed");
            } else if (action == "unsubscribe") {
                musicSubscribers.removeAll(client);
                sendResponse(client, reqId, "unsubscribed");
            } else if (action == "fetch") {
                sendResponse(client, reqId, musicSvc->fetchState());
            } else if (action == "control") {
                musicSvc->handleControl(req["command"].toString(), req["arg1"].toString(), req["arg2"].toString());
                sendResponse(client, reqId, "controlled");
            } else if (action == "get_eq") {
                sendResponse(client, reqId, musicSvc->getEqState());
            } else if (action == "set_band") {
                musicSvc->setEqBand(req["band"].toString(), req["val"].toString());
                sendResponse(client, reqId, "ok");
            } else if (action == "preset") {
                musicSvc->applyPreset(req["name"].toString());
                sendResponse(client, reqId, "ok");
            } else if (action == "apply") {
                musicSvc->applyEq();
                sendResponse(client, reqId, "applied");
            }
        }
        // ---------------------------------------------------------------------
        // CLIPBOARD ROUTING
        // ---------------------------------------------------------------------
        else if (target == "clipboard") {
            if (action == "fetch") {
                int offset = req.contains("offset") ? req["offset"].toInt() : 0;
                int limit = req.contains("limit") ? req["limit"].toInt() : 24;
                QString cacheDir = req["cache_dir"].toString();

                std::thread([this, client, reqId, offset, limit, cacheDir]() {
                    QJsonArray res = handleClipboardFetch(offset, limit, cacheDir);
                    // Use invokeMethod to emit response from local socket thread safely
                    QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                        sendResponse(client, reqId, res);
                    });
                }).detach();
            } 
            else if (action == "toggle-pin") {
                QString id = req["item_id"].toString();
                QString cacheDir = req["cache_dir"].toString();
                handleClipboardPin(id, cacheDir);
                sendResponse(client, reqId, "ok");
            } 
            else if (action == "delete") {
                QString id = req["item_id"].toString();
                handleClipboardDelete(id);
                sendResponse(client, reqId, "ok");
            }
            else if (action == "decode") {
                QString id = req["item_id"].toString();
                std::thread([this, client, reqId, id]() {
                    std::string res = exec_cmd_sync("cliphist decode " + id.toStdString());
                    QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                        sendResponse(client, reqId, QString::fromStdString(res));
                    });
                }).detach();
            }
        }
        // ---------------------------------------------------------------------
        // SERVICES ROUTING
        // ---------------------------------------------------------------------
        else if (target == "services") {
            if (action == "list") {
                std::thread([this, client, reqId]() {
                    QJsonArray res = handleServicesList();
                    QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                        sendResponse(client, reqId, res);
                    });
                }).detach();
            } 
            else if (action == "control") {
                QString svcAction = req["command"].toString(); // start, stop, restart
                QString unit = req["unit"].toString();
                bool isUser = req["is_user"].toBool();
                
                std::thread([this, client, reqId, svcAction, unit, isUser]() {
                    QString cmd = "systemctl";
                    if (isUser) cmd += " --user";
                    cmd += " " + svcAction + " " + unit;
                    std::string result = exec_cmd_sync(cmd.toStdString());
                    QMetaObject::invokeMethod(this, [this, client, reqId]() {
                        sendResponse(client, reqId, "ok");
                    });
                }).detach();
            }
        }
        // ---------------------------------------------------------------------
        // APP LAUNCHER & TOOLS ROUTING
        // ---------------------------------------------------------------------
        else if (target == "applauncher") {
            if (action == "search") {
                QString query = req["query"].toString();
                QJsonArray results = handleAppSearch(query);
                sendResponse(client, reqId, results);
            } 
            else if (action == "tools") {
                QString mode = req["mode"].toString(); // tran, df
                QString query = req["query"].toString();
                QString extra = req["extra"].toString();

                handleToolsRequest(client, reqId, mode, query, extra);
            }
        }
        // ---------------------------------------------------------------------
        // PHOTOBOOTH ROUTING
        // ---------------------------------------------------------------------
        else if (target == "photobooth") {
            if (action == "burst") {
                QJsonArray inFiles = req["inputs"].toArray();
                QString outImg = req["output"].toString();

                std::thread([this, client, reqId, inFiles, outImg]() {
                    QStringList inputs;
                    for (auto f : inFiles) inputs << f.toString();
                    QString res = handlePhotoboothBurst(inputs, outImg);
                    QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                        sendResponse(client, reqId, res);
                    });
                }).detach();
            } 
            else if (action == "setup") {
                QString home = qgetenv("HOME");
                QDir().mkpath(home + "/Pictures/PhotoBooth");
                sendResponse(client, reqId, "ok");
            } 
            else if (action == "start_session") {
                QFile::remove(getPhotoboothSessionPath());
                sendResponse(client, reqId, QJsonArray());
            } 
            else if (action == "add_to_session") {
                registerPhotoboothSession(req["path"].toString());
                sendResponse(client, reqId, "ok");
            } 
            else if (action == "get_session") {
                sendResponse(client, reqId, getPhotoboothSession());
            }
        }
        // ---------------------------------------------------------------------
        // FOCUSTIME ROUTING
        // ---------------------------------------------------------------------
        else if (target == "focustime") {
            if (action == "get_stats") {
                QString targetDate = req["date"].toString();
                QString appFilter = req["app"].toString();
                sendResponse(client, reqId, focusSvc->getStats(targetDate, appFilter));
            }
        }
        // ---------------------------------------------------------------------
        // SCREENSHOT & QR ROUTING
        // ---------------------------------------------------------------------
        else if (target == "screenshot") {
            if (action == "beautify") {
                QString input = req["input"].toString();
                QString output = req["output"].toString();

                std::thread([this, client, reqId, input, output]() {
                    handleScreenshotBeautify(input, output);
                    QMetaObject::invokeMethod(this, [this, client, reqId]() {
                        sendResponse(client, reqId, "ok");
                    });
                }).detach();
            } 
            else if (action == "scan_qr") {
                QString input = req["input"].toString();
                std::thread([this, client, reqId, input]() {
                    QString res = handleScreenshotScanQr(input);
                    QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                        sendResponse(client, reqId, res);
                    });
                }).detach();
            }
        }
        // ---------------------------------------------------------------------
        // WALLPAPER ROUTING
        // ---------------------------------------------------------------------
        else if (target == "wallpaper") {
            if (action == "extract_colors") {
                QString thumbsDir = req["thumbs_dir"].toString();
                QString markerDir = req["marker_dir"].toString();

                std::thread([this, client, reqId, thumbsDir, markerDir]() {
                    handleWallpaperExtractColors(thumbsDir, markerDir);
                    QMetaObject::invokeMethod(this, [this, client, reqId]() {
                        sendResponse(client, reqId, "ok");
                    });
                }).detach();
            }
        }
    }

    // -------------------------------------------------------------------------
    // SERVICE IMPLEMENTATIONS
    // -------------------------------------------------------------------------

    // 1. CLIPBOARD
    QJsonArray handleClipboardFetch(int offset, int limit, const QString& cacheDir) {
        QJsonArray arr;
        std::vector<std::string> all_lines = exec_cmd_sync_lines("cliphist list");
        if (all_lines.empty()) return arr;

        std::set<std::string> pinned_ids = loadPinned(cacheDir);
        std::vector<std::string> sorted_lines;
        std::vector<std::string> unpinned_lines;
        
        for (const auto& line : all_lines) {
            size_t tab_pos = line.find('\t');
            if (tab_pos == std::string::npos) continue;
            std::string id = line.substr(0, tab_pos);
            if (pinned_ids.count(id)) {
                sorted_lines.push_back(line);
            } else {
                unpinned_lines.push_back(line);
            }
        }
        sorted_lines.insert(sorted_lines.end(), unpinned_lines.begin(), unpinned_lines.end());

        int end = std::min((int)sorted_lines.size(), offset + limit);
        for (int i = offset; i < end; ++i) {
            const std::string& line = sorted_lines[i];
            size_t tab_pos = line.find('\t');
            if (tab_pos == std::string::npos) continue;

            std::string iid = line.substr(0, tab_pos);
            std::string content = line.substr(tab_pos + 1);
            std::string item_type = "text";
            std::string display_content = content;

            if (content.find("[[ binary data") != std::string::npos) {
                item_type = "image";
                std::string img_path = (fs::path(cacheDir.toStdString()) / (iid + ".png")).string();
                if (!fs::exists(img_path)) {
                    std::string decode_cmd = "cliphist decode " + iid + " > \"" + img_path + "\"";
                    std::system(decode_cmd.c_str());
                }
                display_content = img_path;
            }

            QJsonObject item;
            item["id"] = QString::fromStdString(iid);
            item["content"] = QString::fromStdString(display_content);
            item["type"] = QString::fromStdString(item_type);
            item["pinned"] = pinned_ids.count(iid) > 0;
            arr.append(item);
        }
        return arr;
    }

    std::set<std::string> loadPinned(const QString& cacheDir) {
        std::set<std::string> pinned;
        std::string pinned_path = (fs::path(cacheDir.toStdString()) / "pinned.json").string();
        if (fs::exists(pinned_path)) {
            try {
                std::ifstream f(pinned_path);
                json j;
                f >> j;
                if (j.is_array()) {
                    for (const auto& id : j) {
                        if (id.is_string()) pinned.insert(id.get<std::string>());
                    }
                }
            } catch (...) {}
        }
        return pinned;
    }

    void handleClipboardPin(const QString& id, const QString& cacheDir) {
        std::set<std::string> pinned = loadPinned(cacheDir);
        std::string stdId = id.toStdString();
        if (pinned.count(stdId)) {
            pinned.erase(stdId);
        } else {
            pinned.insert(stdId);
        }
        
        std::string pinned_path = (fs::path(cacheDir.toStdString()) / "pinned.json").string();
        try {
            json j = json::array();
            for (const auto& pid : pinned) j.push_back(pid);
            std::ofstream f(pinned_path);
            f << j.dump();
        } catch (...) {}
    }

    void handleClipboardDelete(const QString& id) {
        std::vector<std::string> all_lines = exec_cmd_sync_lines("cliphist list");
        std::string line_to_delete;
        std::string stdId = id.toStdString();
        for (const auto& line : all_lines) {
            size_t tab_pos = line.find('\t');
            if (tab_pos != std::string::npos && line.substr(0, tab_pos) == stdId) {
                line_to_delete = line;
                break;
            }
        }
        
        if (!line_to_delete.empty()) {
            QProcess proc;
            proc.start("cliphist", {"delete"});
            proc.write((line_to_delete + "\n").c_str());
            proc.closeWriteChannel();
            proc.waitForFinished();
        }
    }

    // 2. SYSTEMD SERVICES
    struct ServiceEntry {
        std::string unit;
        std::string name;
        std::string load;
        std::string active;
        std::string sub;
        std::string desc;
        bool is_user;
    };

    QJsonArray handleServicesList() {
        std::vector<ServiceEntry> services;
        auto fetch = [&](bool is_user) {
            std::string cmd = "systemctl list-units --type=service --all --no-pager --no-legend";
            if (is_user) cmd += " --user";
            std::vector<std::string> lines = exec_cmd_sync_lines(cmd);
            for (const auto& line : lines) {
                if (line.empty()) continue;
                std::stringstream ss(line);
                std::string unit, load, active, sub;
                if (!(ss >> unit >> load >> active >> sub)) continue;
                std::string desc;
                std::getline(ss, desc);
                desc = trim(desc);

                if (load == "not-found") continue;
                if (unit.find('@') != std::string::npos && active == "inactive") continue;

                std::string name = unit;
                size_t dot = name.find_last_of('.');
                if (dot != std::string::npos) name = name.substr(0, dot);
                services.push_back({unit, name, load, active, sub, desc.empty() ? name : desc, is_user});
            }
        };

        fetch(true);
        fetch(false);

        // Sort: active first, then by name
        std::sort(services.begin(), services.end(), [](const ServiceEntry& a, const ServiceEntry& b) {
            if ((a.active == "active") != (b.active == "active")) {
                return a.active == "active";
            }
            return a.name < b.name;
        });

        QJsonArray arr;
        for (const auto& s : services) {
            QJsonObject sObj;
            sObj["unit"] = QString::fromStdString(s.unit);
            sObj["name"] = QString::fromStdString(s.name);
            sObj["load"] = QString::fromStdString(s.load);
            sObj["active"] = QString::fromStdString(s.active);
            sObj["sub"] = QString::fromStdString(s.sub);
            sObj["desc"] = QString::fromStdString(s.desc);
            sObj["is_user"] = s.is_user;
            arr.append(sObj);
        }
        return arr;
    }

    // 3. APP LAUNCHER DESKTOP PARSING
    void scanDesktopApps() {
        std::vector<std::string> dirs = {
            "~/.local/share/applications",
            "~/.local/share/flatpak/exports/share/applications",
            "~/.nix-profile/share/applications",
            "/usr/local/share/applications",
            "/usr/share/applications",
            "/var/lib/flatpak/exports/share/applications",
            "/run/current-system/sw/share/applications"
        };
        
        std::map<std::string, DesktopApp> appsMap;
        for (auto& d : dirs) {
            fs::path p = expandHome(d);
            if (!fs::exists(p)) continue;
            try {
                for (const auto& entry : fs::recursive_directory_iterator(p)) {
                    if (entry.path().extension() == ".desktop") {
                        parseDesktopFile(entry.path(), appsMap);
                    }
                }
            } catch (...) {}
        }

        desktopApps.clear();
        for (auto const& [name, app] : appsMap) {
            desktopApps.push_back(app);
        }
    }

    fs::path expandHome(std::string path) {
        if (!path.empty() && path[0] == '~') {
            const char* home = std::getenv("HOME");
            if (home) return fs::path(home) / path.substr(2);
        }
        return fs::path(path);
    }

    std::string stripIconExt(std::string icon) {
        icon = trim(icon);
        if (icon.empty()) return icon;
        if (icon[0] == '/' || icon.find('/') != std::string::npos) return icon;
        std::vector<std::string> exts = {".png", ".svg", ".xpm", ".ico"};
        for (const auto& ext : exts) {
            if (icon.size() > ext.size() && 
                std::equal(ext.rbegin(), ext.rend(), icon.rbegin(), [](char a, char b) {
                    return std::tolower(a) == std::tolower(b);
                })) {
                return icon.substr(0, icon.size() - ext.size());
            }
        }
        return icon;
    }

    void parseDesktopFile(const fs::path& path, std::map<std::string, DesktopApp>& appsMap) {
        std::ifstream file(path);
        if (!file.is_open()) return;

        DesktopApp app;
        bool is_desktop = false;
        bool no_display = false;
        std::string line;

        while (std::getline(file, line)) {
            line = trim(line);
            if (line.empty() || line[0] == '#') continue;
            
            if (line[0] == '[') {
                is_desktop = (line == "[Desktop Entry]");
                continue;
            }

            if (is_desktop) {
                size_t sep = line.find('=');
                if (sep == std::string::npos) continue;
                
                std::string key = line.substr(0, sep);
                std::string value = line.substr(sep + 1);

                if (key == "Name" && app.name.empty()) {
                    app.name = trim(value);
                } else if (key == "Exec" && app.exec.empty()) {
                    // Strip %u, %F placeholders
                    std::string exec = trim(value);
                    size_t pos = exec.find(" %");
                    if (pos != std::string::npos) exec = exec.substr(0, pos);
                    pos = exec.find(" @@");
                    if (pos != std::string::npos) exec = exec.substr(0, pos);
                    app.exec = trim(exec);
                } else if (key == "Icon" && app.icon.empty()) {
                    std::string raw_icon = trim(value);
                    if (!raw_icon.empty() && raw_icon[0] == '~') {
                        app.icon = expandHome(raw_icon).string();
                    } else {
                        app.icon = stripIconExt(raw_icon);
                    }
                } else if (key == "NoDisplay") {
                    if (value == "true" || value == "1") no_display = true;
                }
            }
        }

        if (!app.name.empty() && !app.exec.empty() && !no_display) {
            if (appsMap.find(app.name) == appsMap.end()) {
                appsMap[app.name] = app;
            }
        }
    }

    std::string toLower(std::string s) {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
        return s;
    }

    int fuzzyScore(const std::string& name, const std::string& query) {
        if (query.empty()) return 0;
        std::string n = toLower(name);
        std::string q = toLower(query);
        
        int score = 0;
        if (n == q) score += 2000;
        else if (n.find(q) == 0) score += 1500 + (q.length() * 10);
        else if (n.find(" " + q) != std::string::npos) score += 1200 + (q.length() * 5);
        else if (n.find(q) != std::string::npos) score += 1000 + q.length();
        
        // Fuzzy character match
        int fuzzy = 0;
        int lastIdx = -1;
        bool match = true;
        for (size_t i = 0; i < q.length(); i++) {
            size_t idx = n.find(q[i], lastIdx + 1);
            if (idx == std::string::npos) { match = false; break; }
            if (lastIdx != -1) {
                int dist = idx - lastIdx;
                if (dist == 1) fuzzy += 50; 
                else fuzzy += std::max(0, 30 - dist);
            } else {
                if (idx == 0) fuzzy += 100;
            }
            lastIdx = idx;
        }
        if (!match) return score > 0 ? score : 0;
        return score + fuzzy;
    }

    QJsonArray handleAppSearch(const QString& query) {
        if (desktopApps.empty()) {
            scanDesktopApps();
        }
        QJsonArray arr;
        if (query == "--list") {
            for (const auto& app : desktopApps) {
                QJsonObject o;
                o["name"] = QString::fromStdString(app.name);
                o["exec"] = QString::fromStdString(app.exec);
                o["icon"] = QString::fromStdString(app.icon);
                arr.append(o);
            }
            return arr;
        }

        struct ScoreApp {
            DesktopApp app;
            int score;
        };
        std::vector<ScoreApp> results;
        std::string stdQuery = query.toStdString();
        for (const auto& app : desktopApps) {
            int score = fuzzyScore(app.name, stdQuery);
            if (score > 0) {
                results.push_back({app, score});
            }
        }
        
        std::sort(results.begin(), results.end(), [](const ScoreApp& a, const ScoreApp& b) {
            return a.score > b.score;
        });

        for (const auto& r : results) {
            QJsonObject o;
            o["name"] = QString::fromStdString(r.app.name);
            o["exec"] = QString::fromStdString(r.app.exec);
            o["icon"] = QString::fromStdString(r.app.icon);
            o["score"] = r.score;
            arr.append(o);
        }
        return arr;
    }

    // 4. TRANSLATION & DICTIONARY WEB SERVICE
    void handleToolsRequest(QLocalSocket* client, const QString& reqId, const QString& mode, const QString& query, const QString& extra) {
        QString url;
        if (mode == "tran") {
            QString target = "vi";
            QString l = extra.toLower();
            if (LANG_MAP.count(l.toStdString())) target = QString::fromStdString(LANG_MAP[l.toStdString()]);
            else if (!l.isEmpty()) target = l;
            
            url = "https://api.mymemory.translated.net/get?q=" + QUrl::toPercentEncoding(query) + "&langpair=autodetect|" + target;
        } else {
            url = "https://api.dictionaryapi.dev/api/v2/entries/en/" + QUrl::toPercentEncoding(query);
        }

        QNetworkReply* reply = netManager->get(QNetworkRequest(QUrl(url)));
        connect(reply, &QNetworkReply::finished, this, [this, client, reqId, mode, query, reply]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                QJsonObject errorRes;
                errorRes["result"] = "Error connecting to service.";
                errorRes["mode"] = mode;
                sendResponse(client, reqId, errorRes, "error");
                return;
            }

            QByteArray rawData = reply->readAll();
            try {
                auto data = json::parse(rawData.toStdString());
                QJsonObject resObj;

                if (mode == "tran") {
                    std::string translated = data["responseData"]["translatedText"];
                    if (translated.find("MYMEMORY WARNING") != std::string::npos || translated.find("PLEASE SELECT") != std::string::npos) {
                        translated = "API quota exceeded, try again later.";
                    }
                    resObj["result"] = QString::fromStdString(translated);
                    resObj["mode"] = "tran";
                } else {
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
                        
                        std::string final_res = (phonetic.empty() ? query.toStdString() : phonetic) + "\n";
                        for (size_t i = 0; i < results.size(); ++i) {
                            final_res += results[i] + (i == results.size() - 1 ? "" : "\n");
                        }
                        resObj["result"] = QString::fromStdString(final_res);
                        resObj["mode"] = "df";
                    } else {
                        resObj["result"] = "No definition found.";
                        resObj["mode"] = "df";
                    }
                }
                sendResponse(client, reqId, resObj);
            } catch (...) {
                QJsonObject errorRes;
                errorRes["result"] = "Failed to parse API response.";
                errorRes["mode"] = mode;
                sendResponse(client, reqId, errorRes, "error");
            }
        });
    }

    // 5. PHOTOBOOTH
    QString getPhotoboothSessionPath() {
        QString home = qgetenv("HOME");
        QString cacheDir = home + "/.cache/quickshell/photobooth";
        QDir().mkpath(cacheDir);
        return cacheDir + "/session.json";
    }

    void registerPhotoboothSession(const QString &filePath) {
        QString path = getPhotoboothSessionPath();
        QJsonArray session;
        
        QFile readFile(path);
        if (readFile.open(QIODevice::ReadOnly)) {
            session = QJsonDocument::fromJson(readFile.readAll()).array();
            readFile.close();
        }
        
        QFileInfo info(filePath);
        QJsonObject entry;
        entry["name"] = info.fileName();
        entry["path"] = "file://" + info.absoluteFilePath();
        session.prepend(entry);
        
        QFile writeFile(path);
        if (writeFile.open(QIODevice::WriteOnly)) {
            writeFile.write(QJsonDocument(session).toJson(QJsonDocument::Compact));
        }
    }

    QJsonArray getPhotoboothSession() {
        QFile file(getPhotoboothSessionPath());
        if (file.open(QIODevice::ReadOnly)) {
            return QJsonDocument::fromJson(file.readAll()).array();
        }
        return QJsonArray();
    }

    QString handlePhotoboothBurst(const QStringList& inputs, const QString& output) {
        QList<QImage> images;
        int maxW = 0, maxH = 0;
        for (const QString &path : inputs) {
            QImage img(path);
            if (img.isNull()) continue;
            images << img;
            maxW = qMax(maxW, img.width());
            maxH = qMax(maxH, img.height());
        }

        if (images.size() < 4) return "error: missing images";

        int spacing = 8;
        int totalW = maxW * 2 + spacing * 3;
        int totalH = maxH * 2 + spacing * 3;

        QImage result(totalW, totalH, QImage::Format_RGB32);
        result.fill(QColor("#11111b"));

        QPainter painter(&result);
        painter.setRenderHint(QPainter::SmoothPixmapTransform);
        painter.drawImage(spacing, spacing, images[0].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.drawImage(maxW + spacing * 2, spacing, images[1].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.drawImage(spacing, maxH + spacing * 2, images[2].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.drawImage(maxW + spacing * 2, maxH + spacing * 2, images[3].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.end();

        if (result.save(output, "JPG", 92)) {
            for (const QString &path : inputs) QFile::remove(path);
            registerPhotoboothSession(output);
            return output;
        }
        return "error: save failed";
    }

    // 6. SCREENSHOTS & QR SCAN
    void handleScreenshotBeautify(const QString& inputPath, const QString& outputPath) {
        QImage input;
        if (!input.load(inputPath)) return;

        int iw = input.width();
        double scale = (iw > 1600) ? 1.0 : (iw > 1000) ? 1.5 : 2.0;

        QImage screenshot;
        if (scale == 1.0) {
            screenshot = std::move(input);
        } else {
            screenshot = input.scaled(
                (int)(iw * scale), (int)(input.height() * scale),
                Qt::IgnoreAspectRatio, Qt::FastTransformation
            );
            input = QImage();
        }

        const int sw = screenshot.width();
        const int sh = screenshot.height();
        const int bar_h  = (int)(32 * scale);
        const int padding = (int)(60 * scale);
        const int radius  = (int)(14 * scale);
        const int b_rad   = (int)(7  * scale);
        const int combined_h = sh + bar_h;

        // Round window image
        QImage combined(sw, combined_h, QImage::Format_ARGB32_Premultiplied);
        combined.fill(Qt::transparent);

        {
            QPainter p(&combined);
            p.setRenderHint(QPainter::Antialiasing);

            QPainterPath path;
            path.addRoundedRect(0, 0, sw, combined_h, radius, radius);
            p.setClipPath(path);

            p.fillRect(0, 0, sw, bar_h, QColor("#1e1e1e"));

            // macOS Traffic lights
            p.setPen(Qt::NoPen);
            const int btn_y  = (int)(16 * scale);
            const int btn_d  = b_rad * 2;
            p.setBrush(QColor("#FF5F56"));
            p.drawEllipse((int)(24 * scale) - b_rad, btn_y - b_rad, btn_d, btn_d);
            p.setBrush(QColor("#FFBD2E"));
            p.drawEllipse((int)(46 * scale) - b_rad, btn_y - b_rad, btn_d, btn_d);
            p.setBrush(QColor("#27C93F"));
            p.drawEllipse((int)(68 * scale) - b_rad, btn_y - b_rad, btn_d, btn_d);

            p.drawImage(0, bar_h, screenshot);
        }
        screenshot = QImage();

        // Final composite
        const int final_w = sw + padding * 2;
        const int final_h = combined_h + padding * 2;

        QImage finalImg(final_w, final_h, QImage::Format_RGB32);

        {
            QPainter p_f(&finalImg);

            // Select Gradient
            std::srand((unsigned)std::time(nullptr));
            const auto& gp = GRADIENTS[std::rand() % GRADIENT_COUNT];

            QLinearGradient grad(0, 0, final_w, final_h);
            grad.setColorAt(0, gp.first);
            grad.setColorAt(1, gp.second);
            p_f.fillRect(finalImg.rect(), grad);

            // Smooth blurred shadow (8x downscale box blur approach)
            constexpr int BLK = 8;
            const int ssw = (final_w + BLK - 1) / BLK;
            const int ssh = (final_h + BLK - 1) / BLK;

            QImage shadowBuf(ssw, ssh, QImage::Format_ARGB32_Premultiplied);
            shadowBuf.fill(Qt::transparent);
            {
                QPainter ps(&shadowBuf);
                ps.setRenderHint(QPainter::Antialiasing);
                ps.setBrush(QColor(0, 0, 0, 100));
                ps.setPen(Qt::NoPen);
                ps.drawRoundedRect(
                    QRectF((double)padding / BLK,
                           (double)(padding + 10 * scale) / BLK,
                           (double)sw / BLK,
                           (double)combined_h / BLK),
                    (double)radius / BLK, (double)radius / BLK
                );
            }
            p_f.drawImage(QRect(0, 0, final_w, final_h),
                          shadowBuf.scaled(final_w, final_h,
                                           Qt::IgnoreAspectRatio,
                                           Qt::SmoothTransformation));

            p_f.drawImage(padding, padding, combined);
        }

        finalImg.save(outputPath, "PNG", 50);
    }

    QString handleScreenshotScanQr(const QString& inputPath) {
        QImage input;
        if (!input.load(inputPath)) return "";

        QImage gray = input.convertToFormat(QImage::Format_Grayscale8);
        const int width  = gray.width();
        const int height = gray.height();

        std::vector<uchar> buffer;
        bool contiguous = (gray.bytesPerLine() == width);
        const uchar* raw_ptr = nullptr;

        if (contiguous) {
            raw_ptr = gray.bits();
        } else {
            buffer.reserve((size_t)width * height);
            for (int y = 0; y < height; ++y) {
                const uchar* line = gray.scanLine(y);
                buffer.insert(buffer.end(), line, line + width);
            }
            raw_ptr = buffer.data();
        }

        zbar::ImageScanner scanner;
        scanner.set_config(zbar::ZBAR_NONE, zbar::ZBAR_CFG_ENABLE, 1);
        zbar::Image zImage(width, height, "Y800", raw_ptr, (size_t)width * height);
        scanner.scan(zImage);

        auto collect_symbols = [](zbar::Image& img, int div = 1) -> QString {
            QString outText;
            for (auto sym = img.symbol_begin(); sym != img.symbol_end(); ++sym) {
                int min_x = INT_MAX, min_y = INT_MAX, max_x = INT_MIN, max_y = INT_MIN;
                for (int i = 0, n = sym->get_location_size(); i < n; ++i) {
                    int px = sym->get_location_x(i) / div;
                    int py = sym->get_location_y(i) / div;
                    if (px < min_x) min_x = px;
                    if (px > max_x) max_x = px;
                    if (py < min_y) min_y = py;
                    if (py > max_y) max_y = py;
                }
                outText += QString("%1,%2,%3,%4|||%5\n")
                    .arg(min_x).arg(min_y)
                    .arg(max_x - min_x).arg(max_y - min_y)
                    .arg(QString::fromStdString(sym->get_data()));
            }
            return outText;
        };

        QString res = collect_symbols(zImage);
        if (res.isEmpty()) {
            QImage scaled = input.scaled(
                input.width() * 2, input.height() * 2,
                Qt::IgnoreAspectRatio, Qt::SmoothTransformation
            );
            QImage gray2 = scaled.convertToFormat(QImage::Format_Grayscale8);
            const int w2 = gray2.width(), h2 = gray2.height();

            std::vector<uchar> buf2;
            bool c2 = (gray2.bytesPerLine() == w2);
            const uchar* ptr2 = nullptr;
            if (c2) {
                ptr2 = gray2.bits();
            } else {
                buf2.reserve((size_t)w2 * h2);
                for (int y = 0; y < h2; ++y) {
                    const uchar* l = gray2.scanLine(y);
                    buf2.insert(buf2.end(), l, l + w2);
                }
                ptr2 = buf2.data();
            }

            zbar::Image zImg2(w2, h2, "Y800", ptr2, (size_t)w2 * h2);
            if (scanner.scan(zImg2) > 0) {
                res = collect_symbols(zImg2, 2);
            }
        }
        return res;
    }

    void handleWallpaperExtractColors(const QString& thumbsDir, const QString& markerDir) {
        QDir dir(thumbsDir);
        if (!dir.exists()) return;

        QDir mDir(markerDir);
        mDir.mkpath(".");

        // 1. Process colors.csv if it exists
        QString csvPath = dir.filePath("../colors.csv");
        if (QFile::exists(csvPath)) {
            QFile file(csvPath);
            if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream in(&file);
                while (!in.atEnd()) {
                    QString line = in.readLine().trimmed();
                    if (line.isEmpty()) continue;
                    QStringList parts = line.split(',');
                    if (parts.size() >= 2) {
                        QString fname = parts[0].trimmed();
                        QString hexcode = parts[1].trimmed().replace("#", "");
                        if (hexcode.length() > 6) hexcode = hexcode.left(6);
                        if (!fname.isEmpty() && !hexcode.isEmpty()) {
                            QFile marker(markerDir + "/" + fname + "_HEX_" + hexcode);
                            if (marker.open(QIODevice::WriteOnly)) {
                                marker.close();
                            }
                        }
                    }
                }
                file.close();
                QFile::rename(csvPath, csvPath + ".bak");
            }
        }

        // 2. Loop through all thumbnails
        QStringList filters;
        filters << "*";
        dir.setNameFilters(filters);
        dir.setFilter(QDir::Files | QDir::NoDotAndDotDot);

        QFileInfoList list = dir.entryInfoList();
        for (const QFileInfo& fileInfo : list) {
            QString filename = fileInfo.fileName();
            if (filename.startsWith(".") || filename == "colors_markers" || filename == "search_thumbs" || filename == "thumbs") continue;

            // Check if marker already exists
            bool found = false;
            QDir mSearchDir(markerDir);
            QStringList mFilters;
            mFilters << filename + "_HEX_*";
            mSearchDir.setNameFilters(mFilters);
            if (mSearchDir.entryInfoList().size() > 0) {
                found = true;
            }

            if (!found) {
                // Load QImage and get dominant color
                QImage img;
                if (img.load(fileInfo.absoluteFilePath())) {
                    // Resize to 1x1 to get average/dominant color using Fast/Smooth transformation
                    QImage small = img.scaled(1, 1, Qt::IgnoreAspectRatio, Qt::FastTransformation);
                    QColor col = small.pixelColor(0, 0);

                    // Format color as hex (without #)
                    QString hex = QString("%1%2%3")
                                      .arg(col.red(), 2, 16, QChar('0'))
                                      .arg(col.green(), 2, 16, QChar('0'))
                                      .arg(col.blue(), 2, 16, QChar('0'))
                                      .toUpper();

                    QFile marker(markerDir + "/" + filename + "_HEX_" + hex);
                    if (marker.open(QIODevice::WriteOnly)) {
                        marker.close();
                    }
                }
            }
        }
    }
};

// -----------------------------------------------------------------------------
// SYSTEM ENTRYPOINT
// -----------------------------------------------------------------------------
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>

int main(int argc, char* argv[]) {
    // Ensure only one instance of qs_daemon runs by terminating duplicates
    pid_t my_pid = getpid();
    FILE* pipe = popen("pgrep -x qs_daemon", "r");
    if (pipe) {
        char buffer[128];
        while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
            try {
                pid_t pid = std::stoi(buffer);
                if (pid != my_pid) {
                    kill(pid, SIGTERM);
                    usleep(50000); // 50ms grace period
                    kill(pid, SIGKILL);
                }
            } catch (...) {}
        }
        pclose(pipe);
    }

    QCoreApplication a(argc, argv);
    DaemonServer server;
    return a.exec();
}

#include "qs_daemon.moc"
