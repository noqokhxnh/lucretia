#include "ipc_server.hpp"
#include <QCoreApplication>
#include <QProcess>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QImage>
#include <QTextStream>
#include <iostream>
#include <thread>
#include <climits>
#include <zbar.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

static std::map<std::string, std::string> LANG_MAP = {
    {"vi", "vi"}, {"viet", "vi"}, {"vietnamese", "vi"}, {"tieng viet", "vi"},
    {"en", "en"}, {"english", "en"}, {"anh", "en"},
    {"es", "es"}, {"sp", "es"}, {"spanish", "es"},
    {"fr", "fr"}, {"french", "fr"},
    {"de", "de"}, {"german", "de"},
    {"ja", "ja"}, {"jp", "ja"}, {"japanese", "ja"},
    {"ko", "ko"}, {"kr", "ko"}, {"korean", "ko"},
    {"zh", "zh"}, {"cn", "zh"}, {"chinese", "zh"},
    {"it", "it"}, {"pt", "pt"}, {"ru", "ru"}, {"ar", "ar"}, {"th", "th"}
};

DaemonServer::DaemonServer(QObject* parent) : QObject(parent) {
    sysDataSvc = new SysDataService(this);
    musicSvc = new MusicService(this);
    focusSvc = new FocusService(this);
    appIndexer = new AppIndexer(this);
    serviceManager = new ServiceManager(this);
    mediaProcessor = new MediaProcessor(this);
    clipboardManager = new ClipboardManager(this);
    netManager = new QNetworkAccessManager(this);

    server = new QLocalServer(this);
    QString sockPath = "/tmp/quickshell_qs_daemon.sock";
    QLocalServer::removeServer(sockPath);
    if (!server->listen(sockPath)) {
        std::cerr << "Failed to start Local UNIX Socket server!" << std::endl;
        QCoreApplication::exit(1);
    }

    connect(server, &QLocalServer::newConnection, this, &DaemonServer::onNewConnection);

    QTimer* sysTimer = new QTimer(this);
    connect(sysTimer, &QTimer::timeout, this, &DaemonServer::broadcastSysData);
    sysTimer->start(10000);

    QTimer* musicTimer = new QTimer(this);
    connect(musicTimer, &QTimer::timeout, this, &DaemonServer::broadcastMusicData);
    musicTimer->start(2000);
}

void DaemonServer::onNewConnection() {
    QLocalSocket* client = server->nextPendingConnection();
    connect(client, &QLocalSocket::readyRead, this, [this, client]() {
        this->onClientReadyRead(client);
    });
    connect(client, &QLocalSocket::disconnected, this, [this, client]() {
        this->onClientDisconnected(client);
    });
    clients.append(client);
}

void DaemonServer::onClientDisconnected(QLocalSocket* client) {
    clients.removeAll(client);
    sysSubscribers.removeAll(client);
    musicSubscribers.removeAll(client);
    client->deleteLater();
}

void DaemonServer::onClientReadyRead(QLocalSocket* client) {
    while (client->canReadLine()) {
        QByteArray line = client->readLine().trimmed();
        if (line.isEmpty()) continue;
        processRequest(client, line);
    }
}

void DaemonServer::broadcastSysData() {
    if (sysSubscribers.isEmpty()) return;
    QJsonObject metrics = sysDataSvc->getMetrics();
    QJsonObject event;
    event["event"] = "sysdata";
    event["data"] = metrics;
    QByteArray data = QJsonDocument(event).toJson(QJsonDocument::Compact) + "\n";
    for (auto* c : sysSubscribers) c->write(data);
}

void DaemonServer::broadcastMusicData() {
    if (musicSubscribers.isEmpty()) return;
    QJsonObject state = musicSvc->fetchState();
    QJsonObject event;
    event["event"] = "music";
    event["data"] = state;
    QByteArray data = QJsonDocument(event).toJson(QJsonDocument::Compact) + "\n";
    for (auto* c : musicSubscribers) c->write(data);
}

void DaemonServer::sendResponse(QLocalSocket* client, const QString& reqId, const QJsonObject& result, const QString& status) {
    QJsonObject resp;
    resp["id"] = reqId;
    resp["status"] = status;
    resp["result"] = result;
    client->write(QJsonDocument(resp).toJson(QJsonDocument::Compact) + "\n");
    client->flush();
}

void DaemonServer::sendResponse(QLocalSocket* client, const QString& reqId, const QJsonArray& result, const QString& status) {
    QJsonObject resp;
    resp["id"] = reqId;
    resp["status"] = status;
    resp["result"] = result;
    client->write(QJsonDocument(resp).toJson(QJsonDocument::Compact) + "\n");
    client->flush();
}

void DaemonServer::sendResponse(QLocalSocket* client, const QString& reqId, const QString& textResult, const QString& status) {
    QJsonObject resp;
    resp["id"] = reqId;
    resp["status"] = status;
    resp["result"] = textResult;
    client->write(QJsonDocument(resp).toJson(QJsonDocument::Compact) + "\n");
    client->flush();
}

void DaemonServer::handleToolsRequest(QLocalSocket* client, const QString& reqId, const QString& mode, const QString& query, const QString& extra) {
    QString url;
    if (mode == "tran") {
        QString target = "vi";
        QString l = extra.toLower();
        if (LANG_MAP.count(l.toStdString())) target = QString::fromStdString(LANG_MAP[l.toStdString()]);
        else if (!l.isEmpty()) target = l;
        
        url = "https://api.mymemory.translated.net/get?q=" + QUrl::toPercentEncoding(query) + "&langpair=autodetect|" + target;
    } else {
        url = "https://api.dictionaryapi.dev/api/v2/entries/en/" + QUrl::toPercentEncoding(query);
    }

    QNetworkReply* reply = netManager->get(QNetworkRequest(QUrl(url)));
    connect(reply, &QNetworkReply::finished, this, [this, client, reqId, mode, query, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            QJsonObject errorRes;
            errorRes["result"] = "Error connecting to service.";
            errorRes["mode"] = mode;
            sendResponse(client, reqId, errorRes, "error");
            return;
        }

        QByteArray rawData = reply->readAll();
        try {
            auto data = json::parse(rawData.toStdString());
            QJsonObject resObj;

            if (mode == "tran") {
                std::string translated = data["responseData"]["translatedText"];
                if (translated.find("MYMEMORY WARNING") != std::string::npos || translated.find("PLEASE SELECT") != std::string::npos) {
                    translated = "API quota exceeded, try again later.";
                }
                resObj["result"] = QString::fromStdString(translated);
                resObj["mode"] = "tran";
            } else {
                if (data.is_array() && !data.empty()) {
                    auto entry = data[0];
                    std::string phonetic = entry.value("phonetic", "");
                    std::vector<std::string> results;
                    int m_count = 0;
                    for (auto& meaning : entry["meanings"]) {
                        if (m_count >= 2) break;
                        std::string part = meaning.value("partOfSpeech", "");
                        if (meaning.contains("definitions") && !meaning["definitions"].empty()) {
                            std::string defn = meaning["definitions"][0].value("definition", "");
                            if (!defn.empty()) {
                                results.push_back("(" + part + ") " + defn);
                                m_count++;
                            }
                        }
                    }
                    
                    std::string final_res = (phonetic.empty() ? query.toStdString() : phonetic) + "\n";
                    for (size_t i = 0; i < results.size(); ++i) {
                        final_res += results[i] + (i == results.size() - 1 ? "" : "\n");
                    }
                    resObj["result"] = QString::fromStdString(final_res);
                    resObj["mode"] = "df";
                } else {
                    resObj["result"] = "No definition found.";
                    resObj["mode"] = "df";
                }
            }
            sendResponse(client, reqId, resObj);
        } catch (...) {
            QJsonObject errorRes;
            errorRes["result"] = "Failed to parse API response.";
            errorRes["mode"] = mode;
            sendResponse(client, reqId, errorRes, "error");
        }
    });
}

QString DaemonServer::getPhotoboothSessionPath() {
    QString home = qgetenv("HOME");
    QString cacheDir = home + "/.cache/quickshell/photobooth";
    QDir().mkpath(cacheDir);
    return cacheDir + "/session.json";
}

void DaemonServer::registerPhotoboothSession(const QString &filePath) {
    QString path = getPhotoboothSessionPath();
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
    session.prepend(entry);
    
    QFile writeFile(path);
    if (writeFile.open(QIODevice::WriteOnly)) {
        writeFile.write(QJsonDocument(session).toJson(QJsonDocument::Compact));
    }
}

QJsonArray DaemonServer::getPhotoboothSession() {
    QFile file(getPhotoboothSessionPath());
    if (file.open(QIODevice::ReadOnly)) {
        return QJsonDocument::fromJson(file.readAll()).array();
    }
    return QJsonArray();
}

QString DaemonServer::handlePhotoboothBurst(const QStringList& inputs, const QString& output, bool mirror) {
    QList<QImage> images;
    int maxW = 0, maxH = 0;
    for (const QString &path : inputs) {
        QImage img(path);
        if (img.isNull()) continue;
        if (mirror) img = img.flipped(Qt::Horizontal);
        images << img;
        maxW = qMax(maxW, img.width());
        maxH = qMax(maxH, img.height());
    }

    if (images.size() < 4) return "error: missing images";

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
        registerPhotoboothSession(output);
        return output;
    }
    return "error: save failed";
}

QString DaemonServer::handleScreenshotBeautify(const QString& inputPath, const QString& outputPath) {
    if (!QFile::exists(inputPath)) return "error: input image missing";
    QString bin = QCoreApplication::applicationDirPath() + "/screenshot/screenshot_backend";
    QProcess proc;
    proc.start(bin, {"beautify", inputPath, outputPath});
    if (!proc.waitForStarted(5000)) return "error: beautify backend not found";
    if (!proc.waitForFinished(30000)) {
        proc.kill();
        return "error: beautify timed out";
    }
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0)
        return "error: beautify failed";
    if (!QFile::exists(outputPath) || QFileInfo(outputPath).size() <= 0)
        return "error: output file missing";
    return "ok";
}

QString DaemonServer::handleScreenshotScanQr(const QString& inputPath) {
    QImage input;
    if (!input.load(inputPath)) return "";

    QImage gray = input.convertToFormat(QImage::Format_Grayscale8);
    const int width  = gray.width();
    const int height = gray.height();

    std::vector<uchar> buffer;
    bool contiguous = (gray.bytesPerLine() == width);
    const uchar* raw_ptr = nullptr;

    if (contiguous) {
        raw_ptr = gray.bits();
    } else {
        buffer.reserve((size_t)width * height);
        for (int y = 0; y < height; ++y) {
            const uchar* line = gray.scanLine(y);
            buffer.insert(buffer.end(), line, line + width);
        }
        raw_ptr = buffer.data();
    }

    zbar::ImageScanner scanner;
    scanner.set_config(zbar::ZBAR_NONE, zbar::ZBAR_CFG_ENABLE, 1);
    zbar::Image zImage(width, height, "Y800", raw_ptr, (size_t)width * height);
    scanner.scan(zImage);

    auto collect_symbols = [](zbar::Image& img, int div = 1) -> QString {
        QString outText;
        for (auto sym = img.symbol_begin(); sym != img.symbol_end(); ++sym) {
            int min_x = INT_MAX, min_y = INT_MAX, max_x = INT_MIN, max_y = INT_MIN;
            for (int i = 0, n = sym->get_location_size(); i < n; ++i) {
                int px = sym->get_location_x(i) / div;
                int py = sym->get_location_y(i) / div;
                if (px < min_x) min_x = px;
                if (px > max_x) max_x = px;
                if (py < min_y) min_y = py;
                if (py > max_y) max_y = py;
            }
            outText += QString("%1,%2,%3,%4|||%5\n")
                .arg(min_x).arg(min_y)
                .arg(max_x - min_x).arg(max_y - min_y)
                .arg(QString::fromStdString(sym->get_data()));
        }
        return outText;
    };

    QString res = collect_symbols(zImage);
    if (res.isEmpty()) {
        QImage scaled = input.scaled(input.width() * 2, input.height() * 2, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        QImage gray2 = scaled.convertToFormat(QImage::Format_Grayscale8);
        const int w2 = gray2.width(), h2 = gray2.height();

        std::vector<uchar> buf2;
        bool c2 = (gray2.bytesPerLine() == w2);
        const uchar* ptr2 = nullptr;
        if (c2) {
            ptr2 = gray2.bits();
        } else {
            buf2.reserve((size_t)w2 * h2);
            for (int y = 0; y < h2; ++y) {
                const uchar* l = gray2.scanLine(y);
                buf2.insert(buf2.end(), l, l + w2);
            }
            ptr2 = buf2.data();
        }

        zbar::Image zImg2(w2, h2, "Y800", ptr2, (size_t)w2 * h2);
        if (scanner.scan(zImg2) > 0) {
            res = collect_symbols(zImg2, 2);
        }
    }
    return res;
}

void DaemonServer::handleWallpaperExtractColors(const QString& thumbsDir, const QString& markerDir) {
    QDir dir(thumbsDir);
    if (!dir.exists()) return;

    QDir mDir(markerDir);
    mDir.mkpath(".");

    QString csvPath = dir.filePath("../colors.csv");
    if (QFile::exists(csvPath)) {
        QFile file(csvPath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&file);
            while (!in.atEnd()) {
                QString line = in.readLine().trimmed();
                if (line.isEmpty()) continue;
                QStringList parts = line.split(',');
                if (parts.size() >= 2) {
                    QString fname = parts[0].trimmed();
                    QString hexcode = parts[1].trimmed().replace("#", "");
                    if (hexcode.length() > 6) hexcode = hexcode.left(6);
                    if (!fname.isEmpty() && !hexcode.isEmpty()) {
                        QFile marker(markerDir + "/" + fname + "_HEX_" + hexcode);
                        if (marker.open(QIODevice::WriteOnly)) {
                            marker.close();
                        }
                    }
                }
            }
            file.close();
            QFile::rename(csvPath, csvPath + ".bak");
        }
    }

    QStringList filters;
    filters << "*";
    dir.setNameFilters(filters);
    dir.setFilter(QDir::Files | QDir::NoDotAndDotDot);

    QFileInfoList list = dir.entryInfoList();
    for (const QFileInfo& fileInfo : list) {
        QString filename = fileInfo.fileName();
        if (filename.startsWith(".") || filename == "colors_markers" || filename == "search_thumbs" || filename == "thumbs") continue;

        bool found = false;
        QDir mSearchDir(markerDir);
        QStringList mFilters;
        mFilters << filename + "_HEX_*";
        mSearchDir.setNameFilters(mFilters);
        if (mSearchDir.entryInfoList().size() > 0) {
            found = true;
        }

        if (!found) {
            QImage img;
            if (img.load(fileInfo.absoluteFilePath())) {
                QImage small = img.scaled(1, 1, Qt::IgnoreAspectRatio, Qt::FastTransformation);
                QColor col = small.pixelColor(0, 0);

                QString hex = QString("%1%2%3")
                                  .arg(col.red(), 2, 16, QChar('0'))
                                  .arg(col.green(), 2, 16, QChar('0'))
                                  .arg(col.blue(), 2, 16, QChar('0'))
                                  .toUpper();

                QFile marker(markerDir + "/" + filename + "_HEX_" + hex);
                if (marker.open(QIODevice::WriteOnly)) {
                    marker.close();
                }
            }
        }
    }
}

void DaemonServer::processRequest(QLocalSocket* client, const QByteArray& rawJson) {
    QJsonDocument doc = QJsonDocument::fromJson(rawJson);
    if (!doc.isObject()) return;
    QJsonObject req = doc.object();

    QString reqId = req["id"].toString();
    QString target = req["target"].toString();
    QString action = req["action"].toString();

    if (target == "sysdata") {
        if (action == "subscribe") {
            if (!sysSubscribers.contains(client)) sysSubscribers.append(client);
            sendResponse(client, reqId, "subscribed");
        } else if (action == "unsubscribe") {
            sysSubscribers.removeAll(client);
            sendResponse(client, reqId, "unsubscribed");
        }
    } 
    else if (target == "music") {
        if (action == "subscribe") {
            if (!musicSubscribers.contains(client)) musicSubscribers.append(client);
            sendResponse(client, reqId, "subscribed");
        } else if (action == "unsubscribe") {
            musicSubscribers.removeAll(client);
            sendResponse(client, reqId, "unsubscribed");
        } else if (action == "fetch") {
            sendResponse(client, reqId, musicSvc->fetchState());
        } else if (action == "control") {
            musicSvc->handleControl(req["command"].toString(), req["arg1"].toString(), req["arg2"].toString());
            sendResponse(client, reqId, "controlled");
            broadcastMusicData();
        } else if (action == "get_eq") {
            sendResponse(client, reqId, musicSvc->getEqState());
        } else if (action == "set_band") {
            musicSvc->setEqBand(req["band"].toString(), req["val"].toString());
            sendResponse(client, reqId, "ok");
        } else if (action == "preset") {
            musicSvc->applyPreset(req["name"].toString());
            sendResponse(client, reqId, "ok");
        } else if (action == "apply") {
            musicSvc->applyEq();
            sendResponse(client, reqId, "applied");
        }
    }
    else if (target == "clipboard") {
        if (action == "fetch") {
            int offset = req.contains("offset") ? req["offset"].toInt() : 0;
            int limit = req.contains("limit") ? req["limit"].toInt() : 24;
            QString cacheDir = req["cache_dir"].toString();
            sendResponse(client, reqId, clipboardManager->fetchClipboard(offset, limit, cacheDir));
        } else if (action == "toggle-pin") {
            clipboardManager->togglePin(req["item_id"].toString(), req["cache_dir"].toString());
            sendResponse(client, reqId, "ok");
        } else if (action == "delete") {
            clipboardManager->deleteItem(req["item_id"].toString());
            sendResponse(client, reqId, "ok");
        } else if (action == "decode") {
            sendResponse(client, reqId, clipboardManager->decodeItem(req["item_id"].toString()));
        }
    }
    else if (target == "apps" || target == "applauncher") {
        if (action == "search") {
            sendResponse(client, reqId, appIndexer->searchApps(req["query"].toString()));
        } else if (action == "tools") {
            QString mode = req["mode"].toString();
            QString query = req["query"].toString();
            QString extra = req["extra"].toString();
            handleToolsRequest(client, reqId, mode, query, extra);
        }
    }
    else if (target == "services") {
        if (action == "list") {
            sendResponse(client, reqId, serviceManager->listServices());
        } else if (action == "control") {
            serviceManager->controlService(req["unit"].toString(), req["command"].toString(), req["is_user"].toBool());
            sendResponse(client, reqId, "ok");
        }
    }
    else if (target == "focustime") {
        if (action == "get_stats" || action == "get") {
            sendResponse(client, reqId, focusSvc->handleStats(req));
        }
    }
    else if (target == "photobooth") {
        if (action == "burst") {
            QJsonArray inFiles = req["inputs"].toArray();
            QString outImg = req["output"].toString();
            bool mirror = req["mirror"].toBool(false);

            std::thread([this, client, reqId, inFiles, outImg, mirror]() {
                QStringList inputs;
                for (auto f : inFiles) inputs << f.toString();
                QString res = handlePhotoboothBurst(inputs, outImg, mirror);
                QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                    sendResponse(client, reqId, res);
                });
            }).detach();
        } else if (action == "setup") {
            QString home = qgetenv("HOME");
            QDir().mkpath(home + "/Pictures/PhotoBooth");
            sendResponse(client, reqId, "ok");
        } else if (action == "start_session") {
            QFile::remove(getPhotoboothSessionPath());
            sendResponse(client, reqId, QJsonArray());
        } else if (action == "add_to_session") {
            registerPhotoboothSession(req["path"].toString());
            sendResponse(client, reqId, "ok");
        } else if (action == "get_session") {
            sendResponse(client, reqId, getPhotoboothSession());
        } else if (action == "mirror") {
            QString path = req["path"].toString();
            if (!path.isEmpty()) {
                QImage img(path);
                if (!img.isNull()) {
                    img = img.flipped(Qt::Horizontal);
                    img.save(path, "JPG", 95);
                    sendResponse(client, reqId, "mirrored");
                } else {
                    sendResponse(client, reqId, "error: cannot open image");
                }
            } else {
                sendResponse(client, reqId, "error: no path");
            }
        }
    }
    else if (target == "media" || target == "screenshot") {
        if (action == "beautify") {
            QString input = req["input"].toString();
            QString output = req["output"].toString();
            std::thread([this, client, reqId, input, output]() {
                QString res = handleScreenshotBeautify(input, output);
                QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                    sendResponse(client, reqId, res);
                });
            }).detach();
        } else if (action == "qr_scan" || action == "scan_qr") {
            QString inputPath = req["path"].toString();
            if (inputPath.isEmpty()) inputPath = req["input"].toString();
            std::thread([this, client, reqId, inputPath]() {
                QString res = handleScreenshotScanQr(inputPath);
                QMetaObject::invokeMethod(this, [this, client, reqId, res]() {
                    sendResponse(client, reqId, res);
                });
            }).detach();
        }
    }
    else if (target == "wallpaper") {
        if (action == "extract_colors") {
            QString thumbsDir = req["thumbs_dir"].toString();
            QString markerDir = req["marker_dir"].toString();
            std::thread([this, client, reqId, thumbsDir, markerDir]() {
                handleWallpaperExtractColors(thumbsDir, markerDir);
                QMetaObject::invokeMethod(this, [this, client, reqId]() {
                    sendResponse(client, reqId, "ok");
                });
            }).detach();
        }
    }
}
