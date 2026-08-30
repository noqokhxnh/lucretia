import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideWifiRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0
    property bool showLayout: false
    property alias wifiPill: wifiBtn

    y: targetY
    width: barWindow ? barWindow.barHeight : 40
    height: barWindow ? barWindow.barHeight : 40

    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    radius: ThemeBackend.borderRadius
    border.width: (isGrouped || isSolid) ? 0 : 1
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: sideWifiRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: sideWifiRoot.showLayout = true
    }

    IconButton {
        id: wifiBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(30) : 30
        height: barWindow ? barWindow.s(30) : 30
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
        buttonIcon: Networking.wifiEnabled ? "󰤨" : "󰤮"
        iconFontSize: barWindow ? barWindow.s(15) : 15
        accentColor: Networking.wifiEnabled ? ThemeBackend.blue : ThemeBackend.surface0
        textColor: Networking.wifiEnabled ? ThemeBackend.base : ThemeBackend.text
        iconOffsetX: -3
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network wifi"])
    }
}
