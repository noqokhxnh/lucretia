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
    std::string keywords;
    std::string comment;
    std::string categories;
    bool terminal = false;
    std::string desktopFile;
};

struct RunningWindowInfo {
    int id;
    std::string appId;
    std::string title;
    int workspaceId;
};

class AppIndexer : public QObject {
    Q_OBJECT
public:
    explicit AppIndexer(QObject* parent = nullptr);

    void scanDesktopApps();
    QJsonArray searchApps(const QString& query);

private:
    std::vector<DesktopApp> desktopApps;

    int computeFuzzyScore(const DesktopApp& app, const std::string& query);
    std::vector<RunningWindowInfo> fetchNiriWindows();
};

