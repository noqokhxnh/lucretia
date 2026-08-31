#include "weather_engine.hpp"
#include <QUrl>
#include <QUrlQuery>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QDateTime>
#include <cmath>

WeatherEngine::WeatherEngine(QNetworkAccessManager* netMgr, QObject* parent)
    : QObject(parent), m_netMgr(netMgr), m_refreshTimer(new QTimer(this))
{
    loadCachedData();

    connect(m_refreshTimer, &QTimer::timeout, this, &WeatherEngine::onAutoRefreshTimeout);
    m_refreshTimer->setInterval(m_intervalMinutes * 60 * 1000);
    m_refreshTimer->start();

    // Initial fetch after 1 second
    QTimer::singleShot(1000, this, [this]() {
        refresh();
    });
}

void WeatherEngine::setLocation(double lat, double lon, const QString& cityName) {
    if (std::abs(m_latitude - lat) > 0.0001 || std::abs(m_longitude - lon) > 0.0001 || m_cityName != cityName) {
        m_latitude = lat;
        m_longitude = lon;
        if (!cityName.isEmpty()) m_cityName = cityName;
        refresh(true);
    }
}

void WeatherEngine::setUnit(const QString& unit) {
    QString u = (unit.toLower() == "imperial" || unit.toLower() == "f") ? "imperial" : "metric";
    if (m_unit != u) {
        m_unit = u;
        refresh(true);
    }
}

void WeatherEngine::setRefreshInterval(int minutes) {
    if (minutes < 1) minutes = 1;
    m_intervalMinutes = minutes;
    m_refreshTimer->setInterval(m_intervalMinutes * 60 * 1000);
}

QJsonObject WeatherEngine::getWeatherData() const {
    return m_currentData;
}

void WeatherEngine::refresh(bool force) {
    if (m_isFetching && !force) return;
    if (!m_netMgr) return;

    m_isFetching = true;

    QUrl url("https://api.open-meteo.com/v1/forecast");
    QUrlQuery query;
    query.addQueryItem("latitude", QString::number(m_latitude, 'f', 4));
    query.addQueryItem("longitude", QString::number(m_longitude, 'f', 4));
    query.addQueryItem("current", "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m");
    query.addQueryItem("hourly", "temperature_2m,weather_code");
    query.addQueryItem("daily", "weather_code,temperature_2m_max,temperature_2m_min");
    query.addQueryItem("timezone", "auto");

    if (m_unit == "imperial") {
        query.addQueryItem("temperature_unit", "fahrenheit");
        query.addQueryItem("wind_speed_unit", "mph");
        query.addQueryItem("precipitation_unit", "inch");
    }

    url.setQuery(query);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "Quickshell-Lucretia/2.0");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply* reply = m_netMgr->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onNetworkReply(reply);
    });
}

void WeatherEngine::onAutoRefreshTimeout() {
    refresh(false);
}

void WeatherEngine::onNetworkReply(QNetworkReply* reply) {
    reply->deleteLater();
    m_isFetching = false;

    if (reply->error() != QNetworkReply::NoError) {
        // Transient failures at boot (network not ready, DNS hiccup) would
        // otherwise silence broadcasts until the next 15-min timer tick.
        if (m_fetchFailures < 3) {
            m_fetchFailures++;
            int delayMs = m_fetchFailures * 5000;
            QTimer::singleShot(delayMs, this, [this]() { refresh(false); });
        }
        return;
    }
    m_fetchFailures = 0;

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    parseOpenMeteoJson(doc.object());
}

QString WeatherEngine::getWeatherIcon(int code, bool isDay) const {
    switch (code) {
        case 0: return isDay ? "󰖙" : "󰖔"; // Clear
        case 1: return isDay ? "󰖕" : "󰼱"; // Mainly clear
        case 2: return isDay ? "󰖐" : "󰖐"; // Partly cloudy
        case 3: return "󰖐"; // Overcast
        case 45: case 48: return "󰖑"; // Fog
        case 51: case 53: case 55: return "󰖗"; // Drizzle
        case 61: case 63: case 65: return "󰖖"; // Rain
        case 71: case 73: case 75: return "󰖘"; // Snow
        case 80: case 81: case 82: return "󰖖"; // Rain showers
        case 85: case 86: return "󰖘"; // Snow showers
        case 95: case 96: case 99: return "󰙾"; // Thunderstorm
        default: return "󰖐";
    }
}

QString WeatherEngine::getWeatherDescription(int code) const {
    switch (code) {
        case 0: return "Clear sky";
        case 1: return "Mainly clear";
        case 2: return "Partly cloudy";
        case 3: return "Overcast";
        case 45: return "Fog";
        case 48: return "Depositing rime fog";
        case 51: return "Light drizzle";
        case 53: return "Moderate drizzle";
        case 55: return "Dense drizzle";
        case 61: return "Slight rain";
        case 63: return "Moderate rain";
        case 65: return "Heavy rain";
        case 71: return "Slight snow";
        case 73: return "Moderate snow";
        case 75: return "Heavy snow";
        case 80: return "Slight showers";
        case 81: return "Moderate showers";
        case 82: return "Violent showers";
        case 95: return "Thunderstorm";
        case 96: case 99: return "Thunderstorm with hail";
        default: return "Unknown";
    }
}

QString WeatherEngine::getWeatherColor(int code) const {
    switch (code) {
        case 0: case 1: return "#f9e2af"; // Sunny / Yellow
        case 2: case 3: return "#89b4fa"; // Blue
        case 45: case 48: return "#9399b2"; // Gray
        case 51: case 53: case 55: case 61: case 63: case 65: case 80: case 81: case 82: return "#74c7ec"; // Cyan/Rain
        case 71: case 73: case 75: case 85: case 86: return "#bac2de"; // Snow
        case 95: case 96: case 99: return "#cba6f7"; // Thunder / Purple
        default: return "#89b4fa";
    }
}

void WeatherEngine::parseOpenMeteoJson(const QJsonObject& root) {
    if (!root.contains("current")) return;

    QJsonObject cur = root["current"].toObject();
    double temp = cur["temperature_2m"].toDouble();
    int code = cur["weather_code"].toInt();
    bool isDay = cur["is_day"].toInt() == 1;
    double humidity = cur["relative_humidity_2m"].toDouble();
    double windSpeed = cur["wind_speed_10m"].toDouble();
    double apparentTemp = cur["apparent_temperature"].toDouble();

    QString sym = (m_unit == "imperial") ? "°F" : "°C";
    QString icon = getWeatherIcon(code, isDay);
    QString desc = getWeatherDescription(code);
    QString hex = getWeatherColor(code);

    QJsonObject weatherObj;
    weatherObj["temp"] = std::round(temp);
    weatherObj["temp_formatted"] = QString::number(static_cast<int>(std::round(temp))) + sym;
    weatherObj["feels_like"] = std::round(apparentTemp);
    weatherObj["feels_like_formatted"] = QString::number(static_cast<int>(std::round(apparentTemp))) + sym;
    weatherObj["humidity"] = static_cast<int>(std::round(humidity));
    weatherObj["wind"] = windSpeed;
    weatherObj["wind_formatted"] = QString::number(windSpeed, 'f', 1) + (m_unit == "imperial" ? " mph" : " km/h");
    weatherObj["icon"] = icon;
    weatherObj["description"] = desc;
    weatherObj["hex"] = hex;
    weatherObj["unit_sym"] = sym;
    weatherObj["city"] = m_cityName;
    weatherObj["is_day"] = isDay;
    weatherObj["code"] = code;
    weatherObj["last_updated"] = QDateTime::currentDateTime().toString("hh:mm");

    // Daily Forecast
    QJsonArray forecastArr;
    if (root.contains("daily")) {
        QJsonObject daily = root["daily"].toObject();
        QJsonArray times = daily["time"].toArray();
        QJsonArray maxTemps = daily["temperature_2m_max"].toArray();
        QJsonArray minTemps = daily["temperature_2m_min"].toArray();
        QJsonArray codes = daily["weather_code"].toArray();

        for (int i = 0; i < times.size() && i < 7; ++i) {
            QJsonObject dayObj;
            QString dateStr = times[i].toString();
            QDate d = QDate::fromString(dateStr, Qt::ISODate);
            dayObj["day"] = d.toString("ddd");
            dayObj["date"] = dateStr;
            dayObj["temp_max"] = static_cast<int>(std::round(maxTemps[i].toDouble()));
            dayObj["temp_min"] = static_cast<int>(std::round(minTemps[i].toDouble()));
            int dCode = codes[i].toInt();
            dayObj["code"] = dCode;
            dayObj["icon"] = getWeatherIcon(dCode, true);
            dayObj["hex"] = getWeatherColor(dCode);
            dayObj["description"] = getWeatherDescription(dCode);
            forecastArr.append(dayObj);
        }
    }
    weatherObj["forecast"] = forecastArr;

    // Hourly Forecast (next 24 hours)
    QJsonArray hourlyArr;
    if (root.contains("hourly")) {
        QJsonObject hourly = root["hourly"].toObject();
        QJsonArray hTimes = hourly["time"].toArray();
        QJsonArray hTemps = hourly["temperature_2m"].toArray();
        QJsonArray hCodes = hourly["weather_code"].toArray();

        QDateTime now = QDateTime::currentDateTime();
        int count = 0;
        for (int i = 0; i < hTimes.size() && count < 24; ++i) {
            QDateTime dt = QDateTime::fromString(hTimes[i].toString(), "yyyy-MM-ddTHH:mm");
            if (dt >= now.addSecs(-3600)) {
                QJsonObject hourObj;
                hourObj["time"] = dt.toString("hh:mm");
                hourObj["temp"] = static_cast<int>(std::round(hTemps[i].toDouble()));
                int hCode = hCodes[i].toInt();
                hourObj["code"] = hCode;
                hourObj["icon"] = getWeatherIcon(hCode, dt.time().hour() >= 6 && dt.time().hour() < 18);
                hourObj["hex"] = getWeatherColor(hCode);
                hourlyArr.append(hourObj);
                count++;
            }
        }
    }
    weatherObj["hourly"] = hourlyArr;

    m_currentData = weatherObj;
    saveCachedData();
    emit weatherUpdated(m_currentData);
}

void WeatherEngine::loadCachedData() {
    QString cacheDir = QDir::homePath() + "/.cache/quickshell/weather";
    QFile file(cacheDir + "/weather.json");
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            m_currentData = doc.object();
        }
    }
}

void WeatherEngine::saveCachedData() {
    QString cacheDir = QDir::homePath() + "/.cache/quickshell/weather";
    QDir().mkpath(cacheDir);
    QFile file(cacheDir + "/weather.json");
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(m_currentData).toJson(QJsonDocument::Compact));
    }
}
