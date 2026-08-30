pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"

Singleton {
    id: root

    readonly property MprisPlayer activePlayer: {
        let players = Mpris.players.values;
        let playing = players.find(p => p.isPlaying);
        if (playing) return playing;
        let controllable = players.find(p => p.canControl);
        if (controllable) return controllable;
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool hasActivePlayer: activePlayer !== null
    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string currentArtUrl: {
        if (!activePlayer) return "";
        if (activePlayer.trackArtUrl && activePlayer.trackArtUrl !== "") return activePlayer.trackArtUrl;
        if (activePlayer.metadata) {
            let m = activePlayer.metadata;
            if (m["mpris:artUrl"]) return m["mpris:artUrl"];
            if (m["artUrl"]) return m["artUrl"];
            if (m["xesam:url"] && typeof m["xesam:url"] === "string" && (m["xesam:url"].startsWith("http") || m["xesam:url"].startsWith("file://"))) {
                if (m["xesam:url"].match(/\.(jpg|jpeg|png|webp)$/i)) return m["xesam:url"];
            }
        }
        return "";
    }
    property real livePosition: activePlayer ? activePlayer.position : 0

    property string artUrl: ""
    property string blur: ""
    property string grad: ""
    property string textColor: "#cdd6f4"
    property string deviceIcon: "󰓃"
    property string deviceName: "Speaker"
    property int artRetryCount: 0
    property string lastFetchedUrl: ""

    property string currentTrackHash: ""
    property string lastSuccessfulHash: ""
    property bool artFetchStalled: false
    property bool fetchPending: false

    onActivePlayerChanged: {
        if (root.activePlayer) {
            root.livePosition = root.activePlayer.position;
            root.artRetryCount = 0;
            root.lastFetchedUrl = "";
            root.currentTrackHash = "";
            root.artFetchStalled = false;
            fallbackArtTimer.restart();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasActivePlayer && root.isPlaying
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged();
                root.livePosition = root.activePlayer.position;
            }
        }
    }

    Timer {
        id: fallbackArtTimer
        interval: 150
        repeat: false
        onTriggered: {
            root.artRetryCount = 0;
            root.artFetchStalled = false;
            root.fetchArt();
        }
    }

    Connections {
        target: root.activePlayer
        function onPositionChanged() { root.livePosition = root.activePlayer.position; }
        function onPostTrackChanged() {
            root.livePosition = root.activePlayer.position;
            root.artRetryCount = 0;
            root.lastFetchedUrl = "";
            root.currentTrackHash = "";
            root.artFetchStalled = false;
            fallbackArtTimer.restart();
        }
        function onTrackArtUrlChanged() {
            if (root.activePlayer && root.currentArtUrl !== root.lastFetchedUrl) {
                fallbackArtTimer.stop();
                root.artRetryCount = 0;
                root.artFetchStalled = false;
                root.fetchArt();
            }
        }
        function onTrackTitleChanged() {
            fallbackArtTimer.restart();
        }
        function onMetadataChanged() {
            if (root.activePlayer && root.currentArtUrl !== root.lastFetchedUrl) {
                fallbackArtTimer.stop();
                root.artRetryCount = 0;
                root.artFetchStalled = false;
                root.fetchArt();
            }
        }
    }

    Process {
        id: artFetchProc
        command: [
            "bash",
            Caching.qsDir + "/media/art_fetch.sh",
            root.currentArtUrl,
            root.trackTitle,
            root.trackArtist
        ]
        onExited: {
            if (root.fetchPending) {
                root.fetchPending = false;
                artFetchProc.running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.deviceIcon = d.deviceIcon || "󰓃";
                        root.deviceName = d.deviceName || "Speaker";
                        root.currentTrackHash = d.trackHash || "";

                        if (d.isPlaceholder === false) {
                            root.artUrl = d.artUrl || "";
                            root.blur = d.blur || "";
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                            root.lastSuccessfulHash = d.trackHash || "";
                            root.lastFetchedUrl = root.currentArtUrl;
                            root.artFetchStalled = false;
                        } else {
                            if (root.artUrl === "" || !root.currentArtUrl) {
                                root.artUrl = d.artUrl || "";
                                root.blur = d.blur || "";
                                root.grad = d.grad || "";
                                root.textColor = d.textColor || "#cdd6f4";
                            }
                        }
                    } catch(e) {}
                }
            }
        }
    }

    Timer {
        id: retryTimer
        interval: root.artRetryCount < 10 ? 600 : 2500
        repeat: true
        running: root.hasActivePlayer && root.currentTrackHash !== "" && root.currentTrackHash !== root.lastSuccessfulHash && root.artRetryCount < 30
        onTriggered: {
            root.artRetryCount += 1;
            if (root.artRetryCount >= 30) {
                root.artFetchStalled = true;
            } else {
                root.fetchArt();
            }
        }
    }

    function fetchArt() {
        if (artFetchProc.running) {
            root.fetchPending = true;
            return;
        }
        root.fetchPending = false;
        artFetchProc.running = true;
    }

    function forceArtRefresh() {
        root.artRetryCount = 0;
        root.lastFetchedUrl = "";
        root.lastSuccessfulHash = "";
        root.currentTrackHash = "";
        root.artFetchStalled = false;
        fallbackArtTimer.stop();
        root.fetchArt();
    }
}
