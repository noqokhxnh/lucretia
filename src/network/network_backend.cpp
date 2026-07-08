#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QVariantMap>
#include <iostream>
#include <QStringList>
#include <QFile>
#include <QDir>
#include <QProcess>

class NetworkBackend {
public:
    NetworkBackend() {}

    // --- ETHERNET LOGIC ---
    QJsonObject getEthStatus() {
        QJsonObject root;
        root["present"] = false;
        root["power"] = "off";
        root["device"] = "";
        root["connected"] = QJsonValue::Null;

        QDBusInterface nm("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", QDBusConnection::systemBus());
        QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");

        if (!devices.isValid()) return root;

        for (const auto &path : devices.value()) {
            QDBusInterface device("org.freedesktop.NetworkManager", path.path(), "org.freedesktop.NetworkManager.Device", QDBusConnection::systemBus());
            uint type = device.property("DeviceType").toUInt();
            if (type == 1) { // NM_DEVICE_TYPE_ETHERNET
                root["present"] = true;
                QString interface = device.property("Interface").toString();
                root["device"] = interface;
                uint state = device.property("State").toUInt();

                if (state == 100) { // NM_DEVICE_STATE_ACTIVATED
                    root["power"] = "on";
                    QJsonObject conn;
                    conn["id"] = interface;
                    conn["icon"] = "󰈀";

                    // Get Profile Name
                    QDBusObjectPath activeConnPath = device.property("ActiveConnection").value<QDBusObjectPath>();
                    if (!activeConnPath.path().isEmpty()) {
                        QDBusInterface activeConn("org.freedesktop.NetworkManager", activeConnPath.path(), "org.freedesktop.NetworkManager.Connection.Active", QDBusConnection::systemBus());
                        conn["name"] = activeConn.property("Id").toString();
                    } else {
                        conn["name"] = "Wired Connection";
                    }

                    // IP Address
                    QDBusObjectPath ip4Path = device.property("Ip4Config").value<QDBusObjectPath>();
                    if (!ip4Path.path().isEmpty()) {
                        QDBusInterface ip4("org.freedesktop.NetworkManager", ip4Path.path(), "org.freedesktop.NetworkManager.IP4Config", QDBusConnection::systemBus());
                        QVariant v = ip4.property("AddressData");
                        if (v.canConvert<QVariantList>()) {
                            QVariantList list = v.toList();
                            if (!list.isEmpty()) {
                                conn["ip"] = list.first().toMap()["address"].toString();
                            }
                        }
                    }
                    if (!conn.contains("ip")) conn["ip"] = "No IP";

                    // Speed
                    uint speed = device.property("Speed").toUInt();
                    conn["speed"] = QString::number(speed) + " Mbps";

                    // MAC
                    conn["mac"] = device.property("Autoconnect").toBool() ? device.property("HwAddress").toString() : "Unknown";
                    if (conn["mac"] == "") conn["mac"] = device.property("HwAddress").toString();

                    root["connected"] = conn;
                }
                break; // Only handle first ethernet for now
            }
        }
        return root;
    }

    // --- WIFI LOGIC ---
    QJsonObject getWifiStatus() {
        QJsonObject root;
        root["present"] = false;
        root["power"] = "off";
        root["connected"] = QJsonValue::Null;
        root["networks"] = QJsonArray();

        QDBusInterface nm("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", QDBusConnection::systemBus());
        bool wifiEnabled = nm.property("WirelessEnabled").toBool();
        root["power"] = wifiEnabled ? "on" : "off";

        QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");
        if (!devices.isValid()) return root;

        for (const auto &path : devices.value()) {
            QDBusInterface device("org.freedesktop.NetworkManager", path.path(), "org.freedesktop.NetworkManager.Device", QDBusConnection::systemBus());
            uint type = device.property("DeviceType").toUInt();
            if (type == 2) { // NM_DEVICE_TYPE_WIFI
                root["present"] = true;
                if (!wifiEnabled) return root;

                QDBusInterface wifi("org.freedesktop.NetworkManager", path.path(), "org.freedesktop.NetworkManager.Device.Wireless", QDBusConnection::systemBus());
                
                // Connected AP
                QDBusObjectPath activeApPath = wifi.property("ActiveAccessPoint").value<QDBusObjectPath>();
                QString activeSsid;
                if (!activeApPath.path().isEmpty() && activeApPath.path() != "/") {
                    QDBusInterface ap("org.freedesktop.NetworkManager", activeApPath.path(), "org.freedesktop.NetworkManager.AccessPoint", QDBusConnection::systemBus());
                    activeSsid = QString::fromUtf8(ap.property("Ssid").toByteArray());
                    uint strength = ap.property("Strength").toUInt();
                    
                    QJsonObject conn;
                    conn["id"] = activeSsid;
                    conn["ssid"] = activeSsid;
                    conn["signal"] = QString::number(strength);
                    conn["icon"] = getWifiIcon(strength);
                    conn["security"] = getWifiSecurity(ap.property("WpaFlags").toUInt(), ap.property("RsnFlags").toUInt());
                    
                    // IP and Freq
                    QDBusObjectPath ip4Path = device.property("Ip4Config").value<QDBusObjectPath>();
                    if (!ip4Path.path().isEmpty()) {
                        QDBusInterface ip4("org.freedesktop.NetworkManager", ip4Path.path(), "org.freedesktop.NetworkManager.IP4Config", QDBusConnection::systemBus());
                        QVariant v = ip4.property("AddressData");
                        if (v.canConvert<QVariantList>()) {
                            QVariantList list = v.toList();
                            if (!list.isEmpty()) conn["ip"] = list.first().toMap()["address"].toString();
                        }
                    }
                    if (!conn.contains("ip")) conn["ip"] = "No IP";
                    
                    uint freq = ap.property("Frequency").toUInt();
                    conn["freq"] = QString::number(freq) + " MHz";
                    
                    root["connected"] = conn;
                }

                // All APs
                QDBusReply<QList<QDBusObjectPath>> aps = wifi.call("GetAllAccessPoints");
                if (aps.isValid()) {
                    QJsonArray networks;
                    QSet<QString> seenSsids;
                    if (!activeSsid.isEmpty()) seenSsids.insert(activeSsid);

                    for (const auto &apPath : aps.value()) {
                        QDBusInterface ap("org.freedesktop.NetworkManager", apPath.path(), "org.freedesktop.NetworkManager.AccessPoint", QDBusConnection::systemBus());
                        QString ssid = QString::fromUtf8(ap.property("Ssid").toByteArray());
                        if (ssid.isEmpty() || seenSsids.contains(ssid)) continue;
                        seenSsids.insert(ssid);

                        uint strength = ap.property("Strength").toUInt();
                        QJsonObject net;
                        net["id"] = ssid;
                        net["ssid"] = ssid;
                        net["signal"] = QString::number(strength);
                        net["icon"] = getWifiIcon(strength);
                        net["security"] = getWifiSecurity(ap.property("WpaFlags").toUInt(), ap.property("RsnFlags").toUInt());
                        networks.append(net);
                        if (networks.size() >= 24) break;
                    }
                    root["networks"] = networks;
                }
                break;
            }
        }
        return root;
    }

    // --- BLUETOOTH LOGIC ---
    QJsonObject getBtStatus() {
        QJsonObject root;
        root["present"] = false;
        root["power"] = "off";
        root["connected"] = QJsonArray();
        root["devices"] = QJsonArray();

        QDBusInterface manager("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", QDBusConnection::systemBus());
        QDBusReply<QMap<QDBusObjectPath, QMap<QString, QVariantMap>>> reply = manager.call("GetManagedObjects");

        if (!reply.isValid()) return root;

        auto objects = reply.value();
        QJsonArray connected;
        QJsonArray discovered;

        for (auto it = objects.begin(); it != objects.end(); ++it) {
            auto interfaces = it.value();
            if (interfaces.contains("org.bluez.Adapter1")) {
                root["present"] = true;
                if (interfaces["org.bluez.Adapter1"]["Powered"].toBool()) root["power"] = "on";
            }
            
            if (interfaces.contains("org.bluez.Device1")) {
                auto props = interfaces["org.bluez.Device1"];
                QString mac = props["Address"].toString();
                QString name = props["Name"].toString();
                if (name.isEmpty()) name = props["Alias"].toString();
                if (name.isEmpty()) name = mac;

                QString iconType = props["Icon"].toString();
                QString icon = getBtIcon(iconType, name);

                if (props["Connected"].toBool()) {
                    QJsonObject dev;
                    dev["id"] = mac;
                    dev["name"] = name;
                    dev["mac"] = mac;
                    dev["icon"] = icon;
                    dev["battery"] = QString::number(props.contains("Battery") ? props["Battery"].toUInt() : 0);
                    
                    // Profile (Approximation based on UUIDs or Class)
                    dev["profile"] = "Connected";
                    QStringList uuids = props["UUIDs"].toStringList();
                    for (const auto &uuid : uuids) {
                        if (uuid.contains("0000110b") || uuid.contains("0000110d")) { dev["profile"] = "Hi-Fi (A2DP)"; break; }
                        if (uuid.contains("00001108") || uuid.contains("0000111e")) { dev["profile"] = "Headset (HFP)"; break; }
                    }
                    connected.append(dev);
                } else {
                    QJsonObject dev;
                    dev["id"] = mac;
                    dev["name"] = name;
                    dev["mac"] = mac;
                    dev["icon"] = icon;
                    dev["action"] = props["Paired"].toBool() ? "Connect" : "Pair";
                    
                    // Filter spam/unnamed if requested (matching shell logic)
                    if (name == mac || name == mac.replace(":", "-") || name.isEmpty()) continue;
                    
                    discovered.append(dev);
                }
            }
        }

        root["connected"] = connected;
        root["devices"] = discovered;
        return root;
    }

    void toggleWifi() {
        QDBusInterface nm("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", QDBusConnection::systemBus());
        bool wifiEnabled = nm.property("WirelessEnabled").toBool();
        nm.setProperty("WirelessEnabled", !wifiEnabled);
    }

    void toggleBt() {
        QDBusInterface manager("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", QDBusConnection::systemBus());
        QDBusReply<QMap<QDBusObjectPath, QMap<QString, QVariantMap>>> reply = manager.call("GetManagedObjects");
        if (reply.isValid()) {
            for (auto it = reply.value().begin(); it != reply.value().end(); ++it) {
                if (it.value().contains("org.bluez.Adapter1")) {
                    QDBusInterface adapter("org.bluez", it.key().path(), "org.bluez.Adapter1", QDBusConnection::systemBus());
                    bool powered = adapter.property("Powered").toBool();
                    adapter.setProperty("Powered", !powered);
                    break;
                }
            }
        }
    }

    void connectWifi(const QString &ssid, const QString &password = "") {
        // This is complex via D-Bus directly for new connections (requires SecretAgent).
        // For simplicity and matching existing behavior, we can use nmcli for the actual connection 
        // while using D-Bus for the fast status/list.
        QString cmd = "nmcli device wifi connect '" + ssid + "'";
        if (!password.isEmpty()) cmd += " password '" + password + "'";
        QProcess::startDetached("bash", {"-c", cmd});
    }

    void disconnectWifi() {
        // Disconnect the first wifi device found
        QDBusInterface nm("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", QDBusConnection::systemBus());
        QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");
        if (devices.isValid()) {
            for (const auto &path : devices.value()) {
                QDBusInterface device("org.freedesktop.NetworkManager", path.path(), "org.freedesktop.NetworkManager.Device", QDBusConnection::systemBus());
                if (device.property("DeviceType").toUInt() == 2) { // WIFI
                    device.call("Disconnect");
                    break;
                }
            }
        }
    }

    void disconnectEth(const QString &interface) {
        QDBusInterface nm("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", QDBusConnection::systemBus());
        QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");
        if (devices.isValid()) {
            for (const auto &path : devices.value()) {
                QDBusInterface device("org.freedesktop.NetworkManager", path.path(), "org.freedesktop.NetworkManager.Device", QDBusConnection::systemBus());
                if (device.property("Interface").toString() == interface) {
                    device.call("Disconnect");
                    break;
                }
            }
        }
    }

    void connectBt(const QString &mac) {
        QDBusInterface device("org.bluez", "/org/bluez/hci0/dev_" + QString(mac).replace(":", "_"), "org.bluez.Device1", QDBusConnection::systemBus());
        device.call("Connect");
    }

    void disconnectBt(const QString &mac) {
        QDBusInterface device("org.bluez", "/org/bluez/hci0/dev_" + QString(mac).replace(":", "_"), "org.bluez.Device1", QDBusConnection::systemBus());
        device.call("Disconnect");
    }

private:
    QString getWifiIcon(uint strength) {
        if (strength >= 80) return "󰤨";
        if (strength >= 60) return "󰤥";
        if (strength >= 40) return "󰤢";
        if (strength >= 20) return "󰤟";
        return "󰤯";
    }

    QString getWifiSecurity(uint wpa, uint rsn) {
        if (rsn > 0) return "WPA2/WPA3";
        if (wpa > 0) return "WPA";
        return "Open";
    }

    QString getBtIcon(const QString &type, const QString &name) {
        QString t = type.toLower();
        QString n = name.toLower();
        if (t.contains("headset") || t.contains("headphone") || n.contains("headphone") || n.contains("buds") || n.contains("pods")) return "🎧";
        if (t.contains("audio") || t.contains("speaker") || n.contains("speaker")) return "蓼";
        if (t.contains("phone") || n.contains("phone") || n.contains("iphone") || n.contains("android")) return "";
        if (t.contains("mouse") || n.contains("mouse")) return "";
        if (t.contains("keyboard") || n.contains("keyboard")) return "";
        if (t.contains("controller") || n.contains("controller")) return "";
        return "";
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication a(argc, argv);
    NetworkBackend backend;

    if (argc > 1) {
        QString cmd = argv[1];
        if (cmd == "--wifi-status") {
            std::cout << QJsonDocument(backend.getWifiStatus()).toJson(QJsonDocument::Compact).toStdString() << std::endl;
        } else if (cmd == "--bt-status") {
            std::cout << QJsonDocument(backend.getBtStatus()).toJson(QJsonDocument::Compact).toStdString() << std::endl;
        } else if (cmd == "--eth-status") {
            std::cout << QJsonDocument(backend.getEthStatus()).toJson(QJsonDocument::Compact).toStdString() << std::endl;
        } else if (cmd == "--wifi-toggle") {
            backend.toggleWifi();
        } else if (cmd == "--bt-toggle") {
            backend.toggleBt();
        } else if (cmd == "--wifi-connect") {
            if (argc > 3) backend.connectWifi(argv[2], argv[3]);
            else if (argc > 2) backend.connectWifi(argv[2]);
        } else if (cmd == "--bt-connect") {
            if (argc > 2) backend.connectBt(argv[2]);
        } else if (cmd == "--bt-disconnect") {
            if (argc > 2) backend.disconnectBt(argv[2]);
        } else if (cmd == "--wifi-disconnect") {
            backend.disconnectWifi();
        } else if (cmd == "--eth-disconnect") {
            if (argc > 2) backend.disconnectEth(argv[2]);
        }
    } else {
        // Default to all combined if needed, but the QML expects separate calls currently
        QJsonObject all;
        all["wifi"] = backend.getWifiStatus();
        all["bt"] = backend.getBtStatus();
        all["eth"] = backend.getEthStatus();
        std::cout << QJsonDocument(all).toJson(QJsonDocument::Compact).toStdString() << std::endl;
    }

    return 0;
}
