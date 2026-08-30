#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QString>

class WeatherEngine : public QObject {
    Q_OBJECT
public:
    explicit WeatherEngine(QNetworkAccessManager* netMgr, QObject* parent = nullptr);

    void setLocation(double lat, double lon, const QString& cityName = "");
    void setUnit(const QString& unit); // "metric" or "imperial"
    void setRefreshInterval(int minutes);

    QJsonObject getWeatherData() const;
    void refresh(bool force = false);

signals:
    void weatherUpdated(const QJsonObject& data);

private slots:
    void onNetworkReply(QNetworkReply* reply);
    void onAutoRefreshTimeout();

private:
    QNetworkAccessManager* m_netMgr;
    QTimer* m_refreshTimer;

    double m_latitude = 21.0285;  // Default Hanoi / fallback
    double m_longitude = 105.8542;
    QString m_cityName = "Hanoi";
    QString m_unit = "metric";
    int m_intervalMinutes = 15;

    bool m_isFetching = false;
    QJsonObject m_currentData;

    QString getWeatherIcon(int code, bool isDay) const;
    QString getWeatherDescription(int code) const;
    QString getWeatherColor(int code) const;

    void parseOpenMeteoJson(const QJsonObject& root);
    void loadCachedData();
    void saveCachedData();
};
