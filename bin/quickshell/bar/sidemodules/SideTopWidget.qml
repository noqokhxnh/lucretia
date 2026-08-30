import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Rectangle {
    id: sideTopRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0
    property bool showLayout: false
    property alias helpButton: helpBtn

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
    enabled: moduleActive

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: sideTopRoot.moduleActive && barWindow && barWindow.isStartupReady
        interval: 50
        onTriggered: sideTopRoot.showLayout = true
    }

    IconButton {
        id: helpBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(30) : 30
        height: barWindow ? barWindow.s(30) : 30
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
        buttonIcon: "󰒓"
        iconOffsetX: -2
        iconFontSize: barWindow ? barWindow.s(15) : 15
        accentColor: ThemeBackend.surface0
        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle guide"])
    }
}
