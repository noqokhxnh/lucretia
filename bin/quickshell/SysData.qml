pragma Singleton
import QtQuick
import Quickshell
import "components"

Item {
    id: root
    
    // --- Reactive Bindings to Unified Daemon Client ---
    readonly property int cpu: QsDaemonClient.sysData.cpu
    readonly property int ramPercent: QsDaemonClient.sysData.ramPercent
    readonly property real ramGb: QsDaemonClient.sysData.ramGb
    readonly property int temp: QsDaemonClient.sysData.temp
    readonly property real netRx: QsDaemonClient.sysData.netRx
    readonly property real netTx: QsDaemonClient.sysData.netTx
    
    // --- Legacy Interface Compatibility ---
    property int subscribers: 0
    function subscribe() { subscribers++; }
    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }
}
