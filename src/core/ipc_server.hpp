#pragma once

#include <QObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QTimer>
#include <QList>
#include <QThreadPool>
#include <QRunnable>
#include <memory>
#include <unordered_map>
#include <string>

#include "system/system_monitor.hpp"
#include "music/music_manager.hpp"
#include "focus/focus_tracker.hpp"
#include "apps/app_indexer.hpp"
#include "services/service_manager.hpp"
#include "media/media_processor.hpp"
#include "media/audio_spectrum.hpp"
#include "clipboard/clipboard_manager.hpp"

#include "system/file_watcher.hpp"
#include "system/dbus_watcher.hpp"
#include "system/weather_engine.hpp"
#include "system/theme_manager.hpp"
#include "widgets/widget_manager.hpp"

class DaemonServer;

class ICommandHandler {
public:
    virtual ~ICommandHandler() = default;
    virtual void handleRequest(DaemonServer* server, QLocalSocket* client, const QString& reqId, const QString& action, const QJsonObject& req) = 0;
};

class DaemonServer : public QObject {
    Q_OBJECT
public:
    explicit DaemonServer(QObject* parent = nullptr);

    void sendResponse(QLocalSocket* client, const QString& reqId, const QJsonObject& result, const QString& status = "success");
    void sendResponse(QLocalSocket* client, const QString& reqId, const QJsonArray& result, const QString& status = "success");
    void sendResponse(QLocalSocket* client, const QString& reqId, const QString& textResult, const QString& status = "success");

    SysDataService* getSysDataSvc() const { return sysDataSvc; }
    MusicService* getMusicSvc() const { return musicSvc; }
    FocusService* getFocusSvc() const { return focusSvc; }
    AppIndexer* getAppIndexer() const { return appIndexer; }
    ServiceManager* getServiceManager() const { return serviceManager; }
    MediaProcessor* getMediaProcessor() const { return mediaProcessor; }
    AudioSpectrumService* getAudioSpectrum() const { return audioSpectrum; }
    ClipboardManager* getClipboardManager() const { return clipboardManager; }
    WeatherEngine* getWeatherEngine() const { return weatherEngine; }
    ThemeManager* getThemeManager() const { return themeManager; }
    WidgetManager* getWidgetManager() const { return widgetManager; }
    QNetworkAccessManager* getNetManager() const { return netManager; }

    void addSysSubscriber(QLocalSocket* client) { if (!sysSubscribers.contains(client)) sysSubscribers.append(client); }
    void removeSysSubscriber(QLocalSocket* client) { sysSubscribers.removeAll(client); }
    void addMusicSubscriber(QLocalSocket* client) { if (!musicSubscribers.contains(client)) musicSubscribers.append(client); }
    void removeMusicSubscriber(QLocalSocket* client) { musicSubscribers.removeAll(client); }

    void handleToolsRequest(QLocalSocket* client, const QString& reqId, const QString& mode, const QString& query, const QString& extra);
    QString handlePhotoboothBurst(const QStringList& inputs, const QString& output, bool mirror);
    QString getPhotoboothSessionPath();
    void registerPhotoboothSession(const QString &filePath);
    QJsonArray getPhotoboothSession();
    QString handleScreenshotBeautify(const QString& inputPath, const QString& outputPath);
    QString handleScreenshotScanQr(const QString& inputPath);
    void handleWallpaperExtractColors(const QString& thumbsDir, const QString& markerDir);

public slots:
    void broadcastSysData();
    void broadcastMusicData();

private slots:
    void onNewConnection();
    void onClientDisconnected(QLocalSocket* client);
    void onClientReadyRead(QLocalSocket* client);

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
    AudioSpectrumService* audioSpectrum;
    ClipboardManager* clipboardManager;
    FileWatcherService* fileWatcher;
    DBusWatcherService* dbusWatcher;
    WeatherEngine* weatherEngine;
    ThemeManager* themeManager;
    WidgetManager* widgetManager;
    QNetworkAccessManager* netManager;

    std::unordered_map<std::string, std::shared_ptr<ICommandHandler>> handlers;

    void registerHandlers();
    void processRequest(QLocalSocket* client, const QByteArray& rawJson);
};
