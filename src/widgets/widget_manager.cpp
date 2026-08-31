#include "widget_manager.hpp"
#include <QDir>
#include <QFile>
#include <QJsonDocument>

WidgetManager::WidgetManager(QObject* parent) : QObject(parent) {
}

QString WidgetManager::getLayoutFilePath(const QString& monitorName) const {
    QString safeName = monitorName.isEmpty() ? "default" : monitorName;
    safeName.replace(QRegularExpression("[^a-zA-Z0-9_-]"), "_");
    QString dirPath = QDir::homePath() + "/.local/state/quickshell/widgets/" + safeName;
    QDir().mkpath(dirPath);
    return dirPath + "/layout.json";
}

QJsonArray WidgetManager::loadLayout(const QString& monitorName) const {
    QString path = getLayoutFilePath(monitorName);
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isArray()) {
            return doc.array();
        }
    }
    return QJsonArray();
}

bool WidgetManager::saveLayout(const QString& monitorName, const QJsonArray& layout) {
    QString path = getLayoutFilePath(monitorName);
    QFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(layout).toJson(QJsonDocument::Indented));
        return true;
    }
    return false;
}
