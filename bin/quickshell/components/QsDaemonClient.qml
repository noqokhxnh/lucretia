pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string _runtimeDir: {
        var xdg = Quickshell.env("XDG_RUNTIME_DIR");
        return (xdg !== "" ? xdg : "/tmp") + "/quickshell";
    }

    // --- Singleton Properties (Reactive States) ---
    property var sysData: ({
        cpu: 0,
        ramPercent: 0,
        ramGb: 0.0,
        temp: 0,
        netRx: 0,
        netTx: 0
    })

    property var musicState: ({
        title: "Not Playing",
        artist: "",
        status: "Stopped",
        length: 1,
        position: 0,
        lengthStr: "00:00",
        positionStr: "00:00",
        timeStr: "00:00 / 00:00",
        percent: 0,
        source: "Offline",
        playerName: "",
        blur: "",
        grad: "linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)",
        textColor: "#cdd6f4",
        deviceIcon: "󰓃",
        deviceName: "Speaker",
        artUrl: ""
    })

    property var weatherData: ({
        temp: 0,
        temp_formatted: "--°",
        feels_like: 0,
        feels_like_formatted: "--°",
        humidity: 0,
        wind: 0,
        wind_formatted: "0 km/h",
        icon: "󰖐",
        description: "Loading...",
        hex: "#89b4fa",
        unit_sym: "°C",
        city: "",
        forecast: [],
        hourly: []
    })

    property var spectrumLevels: []

    property bool isConnected: daemonSocket.connected

    // --- Real-time Event Signals ---
    signal sysDataReceived(var data)
    signal musicStateReceived(var data)
    signal weatherReceived(var data)
    signal spectrumReceived(var levels)
    signal eqStateReceived(var data)
    signal focusStatsReceived(var data)
    signal clipboardReceived(var data)
    signal servicesReceived(var data)
    signal appLauncherReceived(var data)
    signal toolsReceived(var data)
    signal photoboothReceived(var data)
    signal screenshotReceived(var data)

    // --- Request/Response Callback Management ---
    property int nextRequestId: 1
    property var pendingCallbacks: ({})

    // JSON cache to skip redundant property updates that trigger QML binding cascades
    property string _lastMusicJson: ""
    property string _lastSysdataJson: ""

    // --- UNIX Local Socket Connection ---
    Socket {
        id: daemonSocket
        path: root._runtimeDir + "/qs_daemon.sock"
        connected: false

        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let msg = data ? data.trim() : "";
                if (!msg) return;

                try {
                    let parsed = JSON.parse(msg);
                    
                    // Case 1: Subscription Broadcast / Event Push
                    if (parsed.event !== undefined) {
                        let eventType = parsed.event;
                        let payload = parsed.data;

                        if (eventType === "sysdata" || eventType === "sys_data") {
                            // Skip if unchanged to prevent QML binding cascades
                            let sysJson = JSON.stringify(payload);
                            if (sysJson !== root._lastSysdataJson) {
                                root._lastSysdataJson = sysJson;
                                root.sysData = payload;
                                root.sysDataReceived(payload);
                            }
                        } else if (eventType === "music" || eventType === "music_state") {
                            // Skip if unchanged (daemon sends every 1s even when idle)
                            let mJson = JSON.stringify(payload);
                            if (mJson !== root._lastMusicJson) {
                                root._lastMusicJson = mJson;
                                root.musicState = payload;
                                root.musicStateReceived(payload);
                            }
                        } else if (eventType === "eq_state") {
                            root.eqStateReceived(payload);
                        } else if (eventType === "focus_stats") {
                            root.focusStatsReceived(payload);
                        } else if (eventType === "clipboard") {
                            root.clipboardReceived(payload);
                        } else if (eventType === "services") {
                            root.servicesReceived(payload);
                        } else if (eventType === "app_launcher") {
                            root.appLauncherReceived(payload);
                        } else if (eventType === "tools") {
                            root.toolsReceived(payload);
                        } else if (eventType === "photobooth") {
                            root.photoboothReceived(payload);
                        } else if (eventType === "weather") {
                            root.weatherData = payload;
                            root.weatherReceived(payload);
                        } else if (eventType === "spectrum") {
                            root.spectrumLevels = payload;
                            root.spectrumReceived(payload);
                        } else if (eventType === "screenshot") {
                            root.screenshotReceived(payload);
                        }
                    } 
                    // Case 2: Request Response
                    else if (parsed.id !== undefined) {
                        let reqId = parsed.id.toString();
                        let cb = root.pendingCallbacks[reqId];
                        if (cb) {
                            cb(parsed.result !== undefined ? parsed.result : (parsed.textResult !== undefined ? parsed.textResult : parsed));
                            let newCallbacks = Object.assign({}, root.pendingCallbacks);
                            delete newCallbacks[reqId];
                            root.pendingCallbacks = newCallbacks;
                        }
                    }
                } catch (e) {
                    console.warn("[QsDaemonClient] Error parsing JSON:", e, "Raw data:", msg);
                }
            }
        }

        onError: (err) => {
            console.warn("[QsDaemonClient] Socket error:", err);
            connected = false;
        }

        onConnectedChanged: {
            if (connected) {
                console.log("[QsDaemonClient] Connected to C++ qs_daemon!");
                // Send initial handshake / subscriptions
                sendRequest("sysdata", "subscribe", {}, null);
                sendRequest("music", "subscribe", {}, null);
            } else {
                console.log("[QsDaemonClient] Disconnected from qs_daemon. Retrying...");
            }
        }
    }

    Component.onCompleted: {
        initialConnectTimer.start();
    }

    Timer {
        id: initialConnectTimer
        interval: 1000
        repeat: false
        onTriggered: {
            console.log("[QsDaemonClient] Initial connection attempt...");
            daemonSocket.connected = true;
        }
    }

    Timer {
        id: reconnectTimer
        interval: 1500
        repeat: true
        running: !daemonSocket.connected && !initialConnectTimer.running
        onTriggered: {
            console.log("[QsDaemonClient] Reconnecting to socket...");
            daemonSocket.connected = false;
            Qt.callLater(() => {
                daemonSocket.connected = true;
            });
        }
    }

    // --- Core API: Send Asynchronous Request to Daemon ---
    function sendRequest(target, action, argsObj, callback) {
        let reqIdStr = (root.nextRequestId++).toString();
        if (callback) {
            let newCallbacks = Object.assign({}, root.pendingCallbacks);
            newCallbacks[reqIdStr] = callback;
            root.pendingCallbacks = newCallbacks;
        }

        let requestObj = Object.assign({
            id: reqIdStr,
            target: target,
            action: action
        }, argsObj || {});

        if (daemonSocket.connected) {
            daemonSocket.write(JSON.stringify(requestObj) + "\n");
            daemonSocket.flush();
        } else {
            console.warn("[QsDaemonClient] Cannot send request, socket disconnected:", JSON.stringify(requestObj));
            // Trigger callback with null if disconnected to prevent hangs
            if (callback) {
                Qt.callLater(callback, null);
            }
        }
        return reqIdStr;
    }

    function fetchWeather(callback) {
        return sendRequest("weather", "get", {}, callback);
    }

    function refreshWeather(callback) {
        return sendRequest("weather", "refresh", {}, callback);
    }

    function setWeatherLocation(lat, lon, city, callback) {
        return sendRequest("weather", "set_location", { lat: lat, lon: lon, city: city }, callback);
    }

    function setWeatherUnit(unit, callback) {
        return sendRequest("weather", "set_unit", { unit: unit }, callback);
    }

    function subscribeSpectrum(callback) {
        return sendRequest("spectrum", "subscribe", {}, callback);
    }

    function unsubscribeSpectrum(callback) {
        return sendRequest("spectrum", "unsubscribe", {}, callback);
    }

    function setSpectrumBars(bars, callback) {
        return sendRequest("spectrum", "set_bars", { bars: bars }, callback);
    }
}
