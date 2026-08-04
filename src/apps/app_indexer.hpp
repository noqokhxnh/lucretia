#pragma once

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <vector>
#include <string>

struct DesktopApp {
    std::string name;
    std::string exec;
    std::string icon;
};

class AppIndexer : public QObject {
    Q_OBJECT
public:
    explicit AppIndexer(QObject* parent = nullptr);

    void scanDesktopApps();
    QJsonArray searchApps(const QString& query);

private:
    std::vector<DesktopApp> desktopApps;

    int computeFuzzyScore(const std::string& pattern, const std::string& str);
    std::string getIconPath(const std::string& iconName);
};
