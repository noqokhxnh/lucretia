#pragma once

#include <QObject>
#include <QJsonArray>
#include <QProcess>
#include <thread>
#include <atomic>
#include <vector>

class AudioSpectrumService : public QObject {
    Q_OBJECT
public:
    explicit AudioSpectrumService(QObject* parent = nullptr);
    ~AudioSpectrumService();

    void setBarCount(int bars);
    void addSubscriber();
    void removeSubscriber();
    bool isRunning() const { return m_subscribersCount > 0; }

signals:
    void spectrumUpdated(const QJsonArray& levels);

private slots:
    void onProcessReadyRead();

private:
    int m_bars = 32;
    std::atomic<int> m_subscribersCount{0};
    QProcess* m_process{nullptr};

    void startProcess();
    void stopProcess();
};
