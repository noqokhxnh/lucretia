#include <QImage>
#include <QPainter>
#include <QStringList>
#include <QFile>
#include <QDir>
#include <QColor>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <iostream>

QString getSessionPath() {
    QString home = qgetenv("HOME");
    QString cacheDir = home + "/.cache/quickshell/photobooth";
    QDir().mkpath(cacheDir);
    return cacheDir + "/session.json";
}

void addToSession(const QString &filePath) {
    QString path = getSessionPath();
    QJsonArray session;
    
    QFile readFile(path);
    if (readFile.open(QIODevice::ReadOnly)) {
        session = QJsonDocument::fromJson(readFile.readAll()).array();
        readFile.close();
    }
    
    QFileInfo info(filePath);
    QJsonObject entry;
    entry["name"] = info.fileName();
    entry["path"] = "file://" + info.absoluteFilePath();
    
    // Prepend so latest is first (leftmost in UI)
    session.prepend(entry);
    
    QFile writeFile(path);
    if (writeFile.open(QIODevice::WriteOnly)) {
        writeFile.write(QJsonDocument(session).toJson(QJsonDocument::Compact));
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: photobooth_backend [setup | burst | start_session | add_to_session | get_session]" << std::endl;
        return 1;
    }

    QString cmd = argv[1];

    if (cmd == "burst") {
        if (argc < 7) return 1;
        QStringList inputs;
        for (int i = 2; i < 6; ++i) inputs << argv[i];
        QString output = argv[6];

        QList<QImage> images;
        int maxW = 0, maxH = 0;
        for (const QString &path : inputs) {
            QImage img(path);
            if (img.isNull()) continue;
            images << img;
            maxW = qMax(maxW, img.width());
            maxH = qMax(maxH, img.height());
        }

        if (images.size() < 4) return 1;

        int spacing = 8;
        int totalW = maxW * 2 + spacing * 3;
        int totalH = maxH * 2 + spacing * 3;

        QImage result(totalW, totalH, QImage::Format_RGB32);
        result.fill(QColor("#11111b"));

        QPainter painter(&result);
        painter.setRenderHint(QPainter::SmoothPixmapTransform);
        painter.drawImage(spacing, spacing, images[0].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.drawImage(maxW + spacing * 2, spacing, images[1].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.drawImage(spacing, maxH + spacing * 2, images[2].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.drawImage(maxW + spacing * 2, maxH + spacing * 2, images[3].scaled(maxW, maxH, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
        painter.end();

        if (result.save(output, "JPG", 92)) {
            for (const QString &path : inputs) QFile::remove(path);
            addToSession(output);
            std::cout << output.toStdString() << std::endl;
        }
        
    } else if (cmd == "setup") {
        QString home = qgetenv("HOME");
        QDir().mkpath(home + "/Pictures/PhotoBooth");
        
    } else if (cmd == "start_session") {
        QFile::remove(getSessionPath());
        std::cout << "[]" << std::endl;
        
    } else if (cmd == "add_to_session") {
        if (argc < 3) return 1;
        addToSession(argv[2]);
        std::cout << "registered" << std::endl;
        
    } else if (cmd == "get_session") {
        QFile file(getSessionPath());
        if (file.open(QIODevice::ReadOnly)) {
            std::cout << file.readAll().toStdString() << std::endl;
        } else {
            std::cout << "[]" << std::endl;
        }
    }

    return 0;
}
