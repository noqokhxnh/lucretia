#ifndef FILE_WATCHER_HPP
#define FILE_WATCHER_HPP

#include <QObject>
#include <QFileSystemWatcher>
#include <QStringList>
#include <QJsonObject>
#include <QDir>
#include <QFileInfo>

class FileWatcherService : public QObject {
    Q_OBJECT

public:
    explicit FileWatcherService(QObject* parent = nullptr);
    void addWatchPath(const QString& path);

signals:
    void fileChanged(const QString& eventType, const QString& path);

private slots:
    void onFileChanged(const QString& path);
    void onDirectoryChanged(const QString& path);

private:
    QFileSystemWatcher* watcher;
    void initDefaultWatches();
};

#endif // FILE_WATCHER_HPP
