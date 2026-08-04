#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QProcess>
#include <QImage>
#include <QColor>
#include <QDir>
#include <QFile>
#include <QCryptographicHash>
#include <QMap>

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
    explicit MusicService(QObject* parent = nullptr);

    QJsonObject fetchState();
    void handleControl(const QString& action, const QString& arg1 = "", const QString& arg2 = "");
    QJsonObject getEqState();
    void setEqBand(const QString& idx, const QString& val);
    void applyPreset(const QString& name);
    void applyEq();

private:
    QNetworkAccessManager* manager;

    QString getRunDir();
    QVariant getProperty(QDBusInterface &iface, const QString &prop);
    void processImage(const QString &input, const QString &outputBlur, const QString &outputGrad, const QString &outputText, MusicState *data);
    void fetchDeviceInfo(MusicState *data);
    MusicState fetchDataInternal();
};
