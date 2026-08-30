import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import "../../../reusables"
import "../../../"

Rectangle {
    id: volWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false

    property real sysVolume: Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0
    property bool isMuted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false
    property string volPercent: sysVolume + "%"
    property string volIcon: isMuted || sysVolume === 0 ? "󰖁" : (sysVolume > 50 ? "󰕾" : "󰖀")
    property bool sysMuted: isMuted

    property bool isDraggingVol: false
    property bool isSoundActive: !isMuted && sysVolume > 0
    property real targetX: 0
    property bool showLayout: false
    property alias volPill: volPill

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }
    y: barWindow.baseOffsetY
    height: barWindow.barHeight
    radius: ThemeBackend.borderRadius
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    border.width: (isGrouped || isSolid) ? 0 : 1
    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    clip: true

    property real targetWidth: (moduleActive && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + barWindow.s(10)) : 0
    width: targetWidth

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: volWidgetRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: volWidgetRoot.showLayout = true
    }

    transform: Translate {
        x: volWidgetRoot.showLayout ? 0 : barWindow.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow.s(30)

        ClickButton {
            id: volPill
            property bool initAnimTrigger: false
            property bool isActive: isSoundActive

            height: sysLayout.pillHeight
            maxWidth: barWindow.s(100)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow.s(12)
            buttonIcon: volIcon
            iconFontSize: barWindow.s(15)
            buttonText: volPercent
            textFontSize: barWindow.s(12)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            accentColor: isActive ? ThemeBackend.mauve : ThemeBackend.surface1
            textColor: isActive ? ThemeBackend.base : ThemeBackend.subtext0

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            Timer { running: volWidgetRoot.moduleActive && volWidgetRoot.showLayout && !volPill.initAnimTrigger; interval: 250; onTriggered: volPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: volPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"])
            onRightClicked: if (Audio.defaultSink) Audio.toggleMute(Audio.defaultSink)

            property real wheelAccumulator: 0
            Timer {
                id: volWheelTimer
                interval: 200
                onTriggered: volPill.wheelAccumulator = 0
            }

            onWheel: wheel => {
                volWheelTimer.restart()
                volPill.wheelAccumulator += wheel.angleDelta.y
                const threshold = 120
                if (Math.abs(volPill.wheelAccumulator) >= threshold) {
                    let steps = Math.trunc(volPill.wheelAccumulator / threshold)
                    volPill.wheelAccumulator = volPill.wheelAccumulator % threshold
                    if (steps !== 0 && Audio.defaultSink) {
                        let newVol = Math.max(0, Math.min(100, sysVolume + (steps * 5)))
                        Audio.setVolume(Audio.defaultSink, newVol)
                    }
                }
            }
        }
    }
}
