pragma Singleton
import QtQuick
import Quickshell
import "../"
import "../components"
import "../singletons"

Item {
    id: root

    property int barCount: 32
    property var barLevels: {
        let arr = [];
        for (let i = 0; i < barCount; i++) arr.push(0.0);
        return arr;
    }
    property var rawBarLevels: barLevels
    property int activeConsumers: 0

    property bool inverted: Config.getSetting("visualizer.inverted", Config.getSetting("cava.inverted", false))
    property string orientation: Config.getSetting("visualizer.orientation", Config.getSetting("cava.orientation", "vertical"))

    function setInverted(val) {
        let b = Boolean(val);
        root.inverted = b;
        Config.setSetting("visualizer.inverted", b);
    }

    function toggleInverted() {
        setInverted(!root.inverted);
    }

    function setOrientation(val) {
        let norm = "vertical";
        if (val === "horizontal" || val === "horizontal_right") norm = "horizontal_right";
        else if (val === "horizontal_left") norm = "horizontal_left";
        root.orientation = norm;
        Config.setSetting("visualizer.orientation", norm);
    }

    function toggleOrientation(dir) {
        if (dir === "left") {
            if (root.orientation === "horizontal_left") setOrientation("vertical");
            else setOrientation("horizontal_left");
        } else if (dir === "right") {
            if (root.orientation === "horizontal_right" || root.orientation === "horizontal") setOrientation("vertical");
            else setOrientation("horizontal_right");
        } else {
            if (root.orientation === "vertical") setOrientation("horizontal_right");
            else setOrientation("vertical");
        }
    }

    function registerConsumer() {
        activeConsumers++;
        if (activeConsumers === 1) {
            QsDaemonClient.subscribeSpectrum();
        }
    }

    function unregisterConsumer() {
        activeConsumers = Math.max(0, activeConsumers - 1);
        if (activeConsumers === 0) {
            QsDaemonClient.unsubscribeSpectrum();
            resetBars();
        }
    }

    function resetBars() {
        let empty = [];
        for (let i = 0; i < root.barCount; i++) {
            empty.push(0.0);
        }
        root.barLevels = empty;
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.inverted = Config.getSetting("visualizer.inverted", Config.getSetting("cava.inverted", false));
            root.orientation = Config.getSetting("visualizer.orientation", Config.getSetting("cava.orientation", "vertical"));
        }
    }

    Connections {
        target: QsDaemonClient
        function onSpectrumReceived(levels) {
            if (Array.isArray(levels)) {
                root.barLevels = levels;
            }
        }
        function onIsConnectedChanged() {
            if (QsDaemonClient.isConnected && root.activeConsumers > 0) {
                QsDaemonClient.subscribeSpectrum();
            }
        }
    }

    onBarCountChanged: {
        if (activeConsumers > 0) {
            QsDaemonClient.setSpectrumBars(barCount);
        }
    }
}
