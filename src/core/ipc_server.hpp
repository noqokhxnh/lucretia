#pragma once

#include <QObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QTimer>
#include <QList>

#include "system/system_monitor.hpp"
#include "music/music_manager.hpp"
#include "focus/focus_tracker.hpp"
#include "apps/app_indexer.hpp"
#include "services/service_manager.hpp"
#include "media/media_processor.hpp"
#include "clipboard/clipboard_manager.hpp"

class DaemonServer : public QObject {
    Q_OBJECT
public:
    explicit DaemonServer(QObject* parent = nullptr);

private slots:
    void onNewConnection();
    void onClientDisconnected(QLocalSocket* client);
    void onClientReadyRead(QLocalSocket* client);
    void broadcastSysData();
    void broadcastMusicData();

private:
    QLocalServer* server;
    QList<QLocalSocket*> clients;
    QList<QLocalSocket*> sysSubscribers;
    QList<QLocalSocket*> musicSubscribers;

    SysDataService* sysDataSvc;
    MusicService* musicSvc;
    FocusService* focusSvc;
    AppIndexer* appIndexer;
    ServiceManager* serviceManager;
    MediaProcessor* mediaProcessor;
    ClipboardManager* clipboardManager;
    QNetworkAccessManager* netManager;

    void processRequest(QLocalSocket* client, const QByteArray& rawJson);
    void handleToolsRequest(QLocalSocket* client, const QString& reqId, const QString& mode, const QString& query, const QString& extra);
    QString handlePhotoboothBurst(const QStringList& inputs, const QString& output, bool mirror);
    QString getPhotoboothSessionPath();
    void registerPhotoboothSession(const QString &filePath);
    QJsonArray getPhotoboothSession();
    QString handleScreenshotBeautify(const QString& inputPath, const QString& outputPath);
    QString handleScreenshotScanQr(const QString& inputPath);
    void handleWallpaperExtractColors(const QString& thumbsDir, const QString& markerDir);

    void sendResponse(QLocalSocket* client, const QString& reqId, const QJsonObject& result, const QString& status = "success");
    void sendResponse(QLocalSocket* client, const QString& reqId, const QJsonArray& result, const QString& status = "success");
    void sendResponse(QLocalSocket* client, const QString& reqId, const QString& textResult, const QString& status = "success");
};
