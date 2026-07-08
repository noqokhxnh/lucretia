#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDBusConnectionInterface>
#include <QImage>
#include <QColor>
#include <QPainter>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QFile>
#include <QDir>
#include <QProcess>
#include <QCryptographicHash>
#include <iostream>
#include <cmath>

struct MusicData {
    QString title = "Not Playing";
    QString artist = "";
    QString status = "Stopped";
    long length = 1;
    long position = 0;
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

class MusicBackend {
public:
    MusicBackend() {
        manager = new QNetworkAccessManager();
    }

    ~MusicBackend() {
        delete manager;
    }

    void processImage(const QString &input, const QString &outputBlur, const QString &outputGrad, const QString &outputText, MusicData *data) {
        QImage img;
        if (!img.load(input)) return;

        // 1. Create Blur (scale trick)
        int blurScale = 16;
        QImage blurred = img.scaled(img.width() / blurScale, img.height() / blurScale, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        
        // Adjust Brightness/Contrast (-30, -10 approx)
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

        // 2. Extract Colors for Gradient
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

        // 3. Text Color (Inverse of C1 or high contrast)
        QColor col1(c1);
        double luminance = (0.299 * col1.red() + 0.587 * col1.green() + 0.114 * col1.blue()) / 255.0;
        data->textColor = luminance > 0.5 ? "#11111b" : "#cdd6f4";
        QFile fText(outputText);
        if (fText.open(QIODevice::WriteOnly)) fText.write(data->textColor.toUtf8());
    }

    void fetchDeviceInfo(MusicData *data) {
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

    MusicData fetchData() {
        MusicData data;
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
                
                data.length = len_micro / 1000000;
                data.position = getProperty(player, "Position").toLongLong() / 1000000;
                
                data.playerName = playerService.mid(23); 
                data.source = data.playerName;
                if (!data.source.isEmpty()) data.source[0] = data.source[0].toUpper();

                if (data.length > 0) {
                    data.lengthStr = QString("%1:%2").arg(data.length / 60, 2, 10, QChar('0')).arg(data.length % 60, 2, 10, QChar('0'));
                } else {
                    data.lengthStr = "00:00";
                }
                
                data.positionStr = QString("%1:%2").arg(data.position / 60, 2, 10, QChar('0')).arg(data.position % 60, 2, 10, QChar('0'));
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

    void printEqJson() {
        QFile file(getRunDir() + "/eq_state.json");
        if (file.open(QIODevice::ReadOnly)) {
            std::cout << file.readAll().toStdString() << std::endl;
        } else {
            std::cout << "{\"b1\": 0, \"b2\": 0, \"b3\": 0, \"b4\": 0, \"b5\": 0, \"b6\": 0, \"b7\": 0, \"b8\": 0, \"b9\": 0, \"b10\": 0, \"preset\": \"Flat\", \"pending\": false}" << std::endl;
        }
    }

    void setBand(const QString &idx, const QString &val) {
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

    void applyPreset(const QString &name) {
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

    void control(const QString &action, const QString &arg1 = "", const QString &arg2 = "") {
        QDBusConnection bus = QDBusConnection::sessionBus();
        QStringList services = bus.interface()->registeredServiceNames();
        QString playerService = "";
        
        for (const QString &service : services) {
            if (service.startsWith("org.mpris.MediaPlayer2.")) {
                QDBusInterface player(service, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus);
                QVariant status = player.call("Get", "org.mpris.MediaPlayer2.Player", "PlaybackStatus").arguments().at(0);
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
            // arg1: percent, arg2: length
            double perc = arg1.toDouble();
            double len = arg2.toDouble();
            double target = (len * perc) / 100.0;
            QProcess::startDetached("playerctl", {"-p", playerService.mid(23), "position", QString::number(target, 'f', 2)});
        }
    }

    void printJson(const MusicData &data) {
        QJsonObject obj;
        obj["title"] = data.title;
        obj["artist"] = data.artist;
        obj["status"] = data.status;
        obj["length"] = (double)data.length;
        obj["position"] = (double)data.position;
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
        std::cout << QJsonDocument(obj).toJson(QJsonDocument::Compact).toStdString() << std::endl;
    }

private:
    QNetworkAccessManager *manager;
};

int main(int argc, char *argv[]) {
    QCoreApplication a(argc, argv);
    MusicBackend backend;
    
    if (argc > 1) {
        QString cmd = argv[1];
        if (cmd == "get_eq") {
            backend.printEqJson();
        } else if (cmd == "set_band") {
            if (argc > 3) backend.setBand(argv[2], argv[3]);
        } else if (cmd == "preset") {
            if (argc > 2) backend.applyPreset(argv[2]);
        } else if (cmd == "apply") {
            backend.applyEq();
        } else if (cmd == "next" || cmd == "prev" || cmd == "play-pause") {
            backend.control(cmd);
        } else if (cmd == "seek") {
            if (argc > 3) backend.control("seek", argv[2], argv[3]);
        } else {
            auto data = backend.fetchData();
            backend.printJson(data);
        }
    } else {
        auto data = backend.fetchData();
        backend.printJson(data);
    }
    return 0;
}


