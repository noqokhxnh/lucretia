#include "audio_spectrum.hpp"
#include <QTemporaryFile>
#include <QTextStream>
#include <QStandardPaths>
#include <QFile>
#include <QDir>
#include <cmath>

AudioSpectrumService::AudioSpectrumService(QObject* parent) : QObject(parent) {
}

AudioSpectrumService::~AudioSpectrumService() {
    stopProcess();
}

void AudioSpectrumService::setBarCount(int bars) {
    if (bars > 0 && bars != m_bars) {
        m_bars = bars;
        if (m_subscribersCount > 0) {
            stopProcess();
            startProcess();
        }
    }
}

void AudioSpectrumService::addSubscriber() {
    if (++m_subscribersCount == 1) {
        startProcess();
    }
}

void AudioSpectrumService::removeSubscriber() {
    if (--m_subscribersCount <= 0) {
        m_subscribersCount = 0;
        stopProcess();
    }
}

void AudioSpectrumService::startProcess() {
    if (m_process) return;

    m_process = new QProcess(this);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &AudioSpectrumService::onProcessReadyRead);

    QString config = QString("[general]\n"
                             "bars = %1\n"
                             "framerate = 60\n"
                             "sensitivity = 150\n"
                             "[output]\n"
                             "method = raw\n"
                             "raw_target = /dev/stdout\n"
                             "data_format = ascii\n"
                             "ascii_max_range = 1000\n"
                             "bar_delimiter = 59\n").arg(m_bars);

    QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtimeDir.isEmpty()) runtimeDir = "/tmp";
    QString configDir = runtimeDir + "/lucretia";
    QDir().mkpath(configDir);
    m_configPath = configDir + "/cava_spectrum.conf";
    QFile f(m_configPath);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        f.write(config.toUtf8());
        f.close();
    }

    m_process->start("cava", QStringList() << "-p" << m_configPath);
}

void AudioSpectrumService::stopProcess() {
    if (m_process) {
        m_process->terminate();
        if (!m_process->waitForFinished(300)) {
            m_process->kill();
            m_process->waitForFinished(200);
        }
        m_process->deleteLater();
        m_process = nullptr;
    }
    if (!m_configPath.isEmpty()) {
        QFile::remove(m_configPath);
        m_configPath.clear();
    }
}

void AudioSpectrumService::onProcessReadyRead() {
    if (!m_process) return;

    while (m_process->canReadLine()) {
        QByteArray line = m_process->readLine().trimmed();
        if (line.isEmpty()) continue;

        QList<QByteArray> parts = line.split(';');
        QJsonArray levels;
        int count = std::min(static_cast<int>(parts.size()), m_bars);
        for (int i = 0; i < m_bars; ++i) {
            if (i < count && !parts[i].isEmpty()) {
                int val = parts[i].toInt();
                double norm = std::max(0.0, std::min(1.0, val / 1000.0));
                levels.append(norm);
            } else {
                levels.append(0.0);
            }
        }

        emit spectrumUpdated(levels);
    }
}
