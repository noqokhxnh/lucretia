#include "media_processor.hpp"

class QrTask : public QRunnable {
public:
    QrTask(const QString& path, std::function<void(const QString&)> cb)
        : imagePath(path), callback(cb) {}

    void run() override {
        QImage img(imagePath);
        if (img.isNull()) {
            callback("");
            return;
        }

        QImage gray = img.convertToFormat(QImage::Format_Grayscale8);
        zbar::ImageScanner scanner;
        scanner.set_config(zbar::ZBAR_NONE, zbar::ZBAR_CFG_ENABLE, 1);

        zbar::Image zbarImg(gray.width(), gray.height(), "Y800", gray.bits(), gray.sizeInBytes());
        int n = scanner.scan(zbarImg);
        if (n > 0) {
            for (auto symbol = zbarImg.symbol_begin(); symbol != zbarImg.symbol_end(); ++symbol) {
                QString result = QString::fromStdString(symbol->get_data());
                callback(result);
                return;
            }
        }
        callback("");
    }

private:
    QString imagePath;
    std::function<void(const QString&)> callback;
};

MediaProcessor::MediaProcessor(QObject* parent) : QObject(parent) {
    pool.setMaxThreadCount(4);
}

void MediaProcessor::scanQrCodeAsync(const QString& imagePath, std::function<void(const QString& text)> callback) {
    QrTask* task = new QrTask(imagePath, callback);
    pool.start(task);
}
