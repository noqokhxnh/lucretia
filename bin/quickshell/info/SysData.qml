pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../components"

Item {
    id: root
    
    property int cpu: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int temp: 0
    property real netRx: 0
    property real netTx: 0
    property int diskPercent: 0
    property real diskGb: 0.0
    property real diskTotalGb: 0.0
    
    property int subscribers: 0
    
    function subscribe() { 
        subscribers++; 
        if (subscribers === 1) {
            QsDaemonClient.sendRequest("sys", "subscribe", {});
        }
    }
    
    function unsubscribe() { 
        subscribers = Math.max(0, subscribers - 1); 
        if (subscribers === 0) {
            QsDaemonClient.sendRequest("sys", "unsubscribe", {});
        }
    }

    function prewarm() {
        subscribe();
    }

    Connections {
        target: QsDaemonClient
        function onSysDataReceived(data) {
            if (!data) return;
            if (data.cpu !== undefined) root.cpu = data.cpu;
            if (data.ramPercent !== undefined) root.ramPercent = data.ramPercent;
            if (data.ramGb !== undefined) root.ramGb = data.ramGb;
            if (data.temp !== undefined) root.temp = data.temp;
            if (data.netRx !== undefined) root.netRx = data.netRx;
            if (data.netTx !== undefined) root.netTx = data.netTx;
            if (data.diskPercent !== undefined) root.diskPercent = data.diskPercent;
            if (data.diskGb !== undefined) root.diskGb = data.diskGb;
            if (data.diskTotalGb !== undefined) root.diskTotalGb = data.diskTotalGb;
        }
    }

    Component.onCompleted: {
        subscribe();
    }
}
