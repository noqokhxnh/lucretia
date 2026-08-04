#pragma once

#include <QObject>
#include <QThreadPool>
#include <QRunnable>
#include <QString>
#include <QImage>
#include <zbar.h>

class MediaProcessor : public QObject {
    Q_OBJECT
public:
    explicit MediaProcessor(QObject* parent = nullptr);

    void scanQrCodeAsync(const QString& imagePath, std::function<void(const QString& text)> callback);

private:
    QThreadPool pool;
};
