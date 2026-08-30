import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideVolRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0
    property bool showLayout: false
    property alias volPill: volBtn

    readonly property real sysVolume: Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0
    readonly property bool isMuted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false

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
        running: sideVolRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: sideVolRoot.showLayout = true
    }

    IconButton {
        id: volBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(30) : 30
        height: barWindow ? barWindow.s(30) : 30
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
        buttonIcon: isMuted || sysVolume === 0 ? "󰖁" : (sysVolume > 50 ? "󰕾" : "󰖀")
        iconFontSize: barWindow ? barWindow.s(15) : 15
        accentColor: (!isMuted && sysVolume > 0) ? ThemeBackend.mauve : ThemeBackend.surface1
        textColor: (!isMuted && sysVolume > 0) ? ThemeBackend.base : ThemeBackend.subtext0
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"])
    }
}
