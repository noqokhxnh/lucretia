#pragma once

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <set>
#include <string>
#include <vector>
#include <filesystem>

class ClipboardManager : public QObject {
    Q_OBJECT
public:
    explicit ClipboardManager(QObject* parent = nullptr);

    QJsonArray fetchClipboard(int offset, int limit, const QString& cacheDir);
    void togglePin(const QString& id, const QString& cacheDir);
    void deleteItem(const QString& id);
    QString decodeItem(const QString& id);

private:
    std::set<std::string> loadPinned(const QString& cacheDir);
};
