#pragma once

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <vector>
#include <string>

struct ServiceEntry {
    std::string unit;
    std::string name;
    std::string load;
    std::string active;
    std::string sub;
    std::string desc;
    bool is_user;
};

class ServiceManager : public QObject {
    Q_OBJECT
public:
    explicit ServiceManager(QObject* parent = nullptr);

    QJsonArray listServices();
    void controlService(const QString& unit, const QString& action, bool isUser);
};
