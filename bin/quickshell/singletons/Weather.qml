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
    property string description: (data && data.description) ? data.description : ""

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
