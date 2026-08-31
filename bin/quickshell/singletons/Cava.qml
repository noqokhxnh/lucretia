pragma Singleton
import QtQuick
import Quickshell
import "../components"

Item {
    id: root

    property int barCount: 32
    property var barLevels: {
        let arr = [];
        for (let i = 0; i < barCount; i++) arr.push(0.0);
        return arr;
    }
    property int activeConsumers: 0

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
        target: QsDaemonClient
        function onSpectrumReceived(levels) {
            if (Array.isArray(levels)) {
                root.barLevels = levels;
            }
        }
    }

    onBarCountChanged: {
        if (activeConsumers > 0) {
            QsDaemonClient.setSpectrumBars(barCount);
        }
    }
}
