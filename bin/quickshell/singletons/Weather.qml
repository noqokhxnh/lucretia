pragma Singleton
import QtQuick
import Quickshell
import "../components"

Item {
    id: root

    property var data: QsDaemonClient.weatherData
    property var forecast: (data && data.forecast) ? data.forecast : []
    property var hourly: (data && data.hourly) ? data.hourly : []
    property string currentIcon: (data && data.icon) ? data.icon : "󰖐"
    property string currentTemp: (data && data.temp !== undefined) ? data.temp.toString() : ""
    property string currentTempFormatted: (data && data.temp_formatted) ? data.temp_formatted : "--°"
    property string currentHex: (data && data.hex) ? data.hex : "#89b4fa"
    property string unitSym: (data && data.unit_sym) ? data.unit_sym : "°C"
    property string city: (data && data.city) ? data.city : ""
    property string description: {
        let _lang = (typeof I18n !== "undefined") ? I18n.currentLang : "en";
        return (data && (data.code !== undefined || data.description)) ? getLocalizedDesc(data.code, data.description) : "";
    }

    function getLocalizedDesc(code, fallbackDesc) {
        let _lang = (typeof I18n !== "undefined") ? I18n.currentLang : "en";
        if (typeof I18n === "undefined" || !I18n.isReady) {
            return fallbackDesc || "";
        }
        let c = parseInt(code);
        if (!isNaN(c) && c >= 0) {
            let codeKey = "weather.codes." + c;
            let trans = I18n.t(codeKey);
            if (trans !== codeKey) {
                return trans;
            }
        }
        if (fallbackDesc) {
            let lower = String(fallbackDesc).toLowerCase().trim();
            if (lower.indexOf("clear") !== -1) return I18n.t("weather.desc.clear");
            if (lower.indexOf("sun") !== -1) return I18n.t("weather.desc.sunny");
            if (lower.indexOf("partly") !== -1) return I18n.t("weather.desc.partly_cloudy");
            if (lower.indexOf("overcast") !== -1) return I18n.t("weather.desc.overcast");
            if (lower.indexOf("cloud") !== -1) return I18n.t("weather.desc.cloudy");
            if (lower.indexOf("drizzle") !== -1) return I18n.t("weather.desc.drizzle");
            if (lower.indexOf("rain") !== -1 || lower.indexOf("shower") !== -1) return I18n.t("weather.desc.rainy");
            if (lower.indexOf("snow") !== -1) return I18n.t("weather.desc.snow");
            if (lower.indexOf("fog") !== -1 || lower.indexOf("mist") !== -1) return I18n.t("weather.desc.fog");
            if (lower.indexOf("storm") !== -1 || lower.indexOf("thunder") !== -1) return I18n.t("weather.desc.storm");
            return fallbackDesc;
        }
        return I18n.t("weather.desc.unknown");
    }

    property bool isLoading: false
    property bool isReady: data && data.temp !== undefined

    signal weatherUpdated()

    Connections {
        target: QsDaemonClient
        function onWeatherReceived(weatherPayload) {
            root.data = weatherPayload;
            root.weatherUpdated();
        }
    }

    Connections {
        target: typeof I18n !== "undefined" ? I18n : null
        function onLanguageChanged() {
            root.weatherUpdated();
        }
    }

    function refresh(force) {
        root.isLoading = true;
        QsDaemonClient.refreshWeather(function(res) {
            root.isLoading = false;
        });
    }

    function setLocation(lat, lon, cityName) {
        QsDaemonClient.setWeatherLocation(lat, lon, cityName, function(res) {
            refresh(true);
        });
    }

    function setUnit(unit) {
        QsDaemonClient.setWeatherUnit(unit, function(res) {
            refresh(true);
        });
    }

    Component.onCompleted: {
        QsDaemonClient.fetchWeather(function(res) {
            if (res && typeof res === "object") {
                root.data = res;
            } else {
                // Socket may not be connected yet; retry a few times.
                retryFetch.start();
            }
        });
    }

    Timer {
        id: retryFetch
        interval: 3000
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (attempts > 5) {
                retryFetch.stop();
                return;
            }
            QsDaemonClient.fetchWeather(function(res) {
                if (res && typeof res === "object") {
                    root.data = res;
                    retryFetch.stop();
                }
            });
        }
    }
}
