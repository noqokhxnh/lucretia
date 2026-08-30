#include "theme_manager.hpp"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QFontDatabase>
#include <QStandardPaths>
#include <QProcess>
#include <algorithm>

ThemeManager::ThemeManager(QObject* parent) : QObject(parent) {
    QDir().mkpath(getUserThemesDir());
}

QString ThemeManager::getSystemThemesDir() const {
    return QDir::homePath() + "/.config/niri/bin/quickshell/assets/themes";
}

QString ThemeManager::getUserThemesDir() const {
    return QDir::homePath() + "/.local/state/quickshell/themes";
}

QJsonArray ThemeManager::listThemes() const {
    QJsonArray result;

    auto scanDir = [&](const QString& dirPath, bool isCustom) {
        QDir dir(dirPath);
        if (!dir.exists()) return;

        QFileInfoList list = dir.entryInfoList(QStringList() << "*.json", QDir::Files, QDir::Name);
        for (const QFileInfo& fi : list) {
            QFile file(fi.absoluteFilePath());
            if (file.open(QIODevice::ReadOnly)) {
                QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
                if (doc.isObject()) {
                    QJsonObject obj = doc.object();
                    QJsonObject themeSummary;
                    QString themeName = fi.baseName();
                    themeSummary["name"] = themeName;
                    themeSummary["file"] = fi.fileName();
                    themeSummary["path"] = fi.absoluteFilePath();
                    themeSummary["isCustom"] = isCustom;
                    themeSummary["isMatugen"] = (themeName.compare("Matugen", Qt::CaseInsensitive) == 0);
                    if (obj.contains("colors") && obj["colors"].isObject()) {
                        themeSummary["colors"] = obj["colors"].toObject();
                    } else {
                        themeSummary["colors"] = obj;
                    }
                    result.append(themeSummary);
                }
            }
        }
    };

    scanDir(getSystemThemesDir(), false);
    scanDir(getUserThemesDir(), true);

    return result;
}

QJsonObject ThemeManager::getTheme(const QString& name) const {
    QString userPath = getUserThemesDir() + "/" + name + ".json";
    if (QFile::exists(userPath)) {
        QFile file(userPath);
        if (file.open(QIODevice::ReadOnly)) {
            return QJsonDocument::fromJson(file.readAll()).object();
        }
    }

    QString sysPath = getSystemThemesDir() + "/" + name + ".json";
    if (QFile::exists(sysPath)) {
        QFile file(sysPath);
        if (file.open(QIODevice::ReadOnly)) {
            return QJsonDocument::fromJson(file.readAll()).object();
        }
    }

    return QJsonObject();
}

bool ThemeManager::saveCustomTheme(const QString& name, const QJsonObject& colors) {
    if (name.isEmpty() || colors.isEmpty()) return false;
    QString targetPath = getUserThemesDir() + "/" + name + ".json";
    QFile file(targetPath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(colors).toJson(QJsonDocument::Indented));
        return true;
    }
    return false;
}

bool ThemeManager::applyTheme(const QString& name) {
    QJsonObject colors = getTheme(name);
    if (colors.isEmpty()) return false;

    QString qsColorsPath = QDir::homePath() + "/.config/niri/bin/quickshell/qs_colors.json";
    QFile file(qsColorsPath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(colors).toJson(QJsonDocument::Indented));
        return true;
    }
    return false;
}

QStringList ThemeManager::listFonts() const {
    QStringList fonts = QFontDatabase::families();
    fonts.removeDuplicates();
    fonts.sort(Qt::CaseInsensitive);
    return fonts;
}
