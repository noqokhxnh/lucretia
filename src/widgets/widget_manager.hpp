#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QString>

class WidgetManager : public QObject {
    Q_OBJECT
public:
    explicit WidgetManager(QObject* parent = nullptr);

    QJsonArray loadLayout(const QString& monitorName) const;
    bool saveLayout(const QString& monitorName, const QJsonArray& layout);

private:
    QString getLayoutFilePath(const QString& monitorName) const;
};
