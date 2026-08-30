import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../reusables"
import "../../"

Rectangle {
    id: leftWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false

    property alias helpButton: helpButton

    property real targetX: 0
    property bool showLayout: false

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    y: barWindow.baseOffsetY
    height: barWindow.barHeight
    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    radius: ThemeBackend.borderRadius
    border.width: (isGrouped || isSolid) ? 0 : 1
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    clip: true

    property real targetWidth: moduleActive ? (leftLayout.width + barWindow.s(16)) : 0
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    enabled: moduleActive

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: leftWidgetRoot.showLayout ? 0 : barWindow.s(-60)
        Behavior on x { NumberAnimation { duration: 750; easing.type: Easing.OutQuint } }
    }

    Timer {
        running: leftWidgetRoot.moduleActive && barWindow.isStartupReady
        interval: 50
        onTriggered: leftWidgetRoot.showLayout = true
    }

    Row {
        id: leftLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: barWindow.s(8)
        spacing: barWindow.s(6)

        property int pillHeight: barWindow.s(30)

        IconButton {
            id: helpButton
            property bool initAnimTrigger: false
            height: leftLayout.pillHeight
            width: barWindow.s(32)
            visible: true
            iconOffsetX: -2

            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            buttonIcon: "󰒓"
            iconFontSize: barWindow.s(15)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2

            Timer { running: leftWidgetRoot.moduleActive && leftWidgetRoot.showLayout && !helpButton.initAnimTrigger; interval: 70; onTriggered: helpButton.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: helpButton.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle guide"])
        }
    }
}
