#include "file_watcher.hpp"
#include <QProcessEnvironment>
#include <QDebug>

FileWatcherService::FileWatcherService(QObject* parent) : QObject(parent) {
    watcher = new QFileSystemWatcher(this);

    connect(watcher, &QFileSystemWatcher::fileChanged, this, &FileWatcherService::onFileChanged);
    connect(watcher, &QFileSystemWatcher::directoryChanged, this, &FileWatcherService::onDirectoryChanged);

    initDefaultWatches();
}

void FileWatcherService::addWatchPath(const QString& path) {
    if (path.isEmpty()) return;
    QFileInfo info(path);
    if (info.exists()) {
        watcher->addPath(path);
    } else if (info.dir().exists()) {
        watcher->addPath(info.dir().absolutePath());
    }
}

void FileWatcherService::initDefaultWatches() {
    QString home = QProcessEnvironment::systemEnvironment().value("HOME");
    QString runtimeDir = QProcessEnvironment::systemEnvironment().value("XDG_RUNTIME_DIR");
    if (runtimeDir.isEmpty()) runtimeDir = "/tmp";

    QStringList pathsToWatch = {
        home + "/.config/niri/settings.json",
        home + "/.config/niri/bin/quickshell/qs_colors.json",
        home + "/.cache/quickshell/dnd/state",
        home + "/.cache/quickshell/updater/update_pending",
        home + "/.cache/quickshell/recording",
        runtimeDir + "/quickshell/current_widget",
        runtimeDir + "/quickshell/keycast/enabled"
    };

    for (const QString& path : pathsToWatch) {
        addWatchPath(path);
    }
}

void FileWatcherService::onFileChanged(const QString& path) {
    // Re-add file to watcher if it was recreated atomically (tmp+mv)
    if (QFile::exists(path)) {
        watcher->addPath(path);
    }
    emit fileChanged("file_modified", path);
}

void FileWatcherService::onDirectoryChanged(const QString& path) {
    emit fileChanged("dir_modified", path);
}
