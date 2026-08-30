#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringList>

class ThemeManager : public QObject {
    Q_OBJECT
public:
    explicit ThemeManager(QObject* parent = nullptr);

    QJsonArray listThemes() const;
    QJsonObject getTheme(const QString& name) const;
    bool saveCustomTheme(const QString& name, const QJsonObject& colors);
    bool applyTheme(const QString& name);

    QStringList listFonts() const;

private:
    QString getSystemThemesDir() const;
    QString getUserThemesDir() const;
};
