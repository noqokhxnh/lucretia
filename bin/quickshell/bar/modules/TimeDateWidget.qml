import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../reusables"
import "../../"

Rectangle {
    id: timeDateRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    readonly property bool isBottomBar: barWindow ? (barWindow.barPosition === "bottom") : false

    readonly property string timeStr: DateTime.time
    readonly property string timeOnlyStr: DateTime.timeOnly
    readonly property string fullDateStr: DateTime.fullDate
    property int typeInIndex: 0
    property string dateStr: fullDateStr.substring(0, typeInIndex)

    onFullDateStrChanged: {
        if (typeInIndex >= fullDateStr.length) {
            typeInIndex = fullDateStr.length;
        }
    }

    Timer {
        id: typewriterTimer
        interval: 30
        running: timeDateRoot.moduleActive && barWindow && barWindow.isStartupReady && typeInIndex < fullDateStr.length
        repeat: true
        onTriggered: typeInIndex += 1
    }

    property int animDuration: 600
    property real targetX: 0
    x: targetX

    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }

    property real horizontalPadding: barWindow ? barWindow.s(14) : 14
    property real baseWidth: timeCol.width + (horizontalPadding * 2)
    property real baseHeight: barWindow ? barWindow.barHeight : 30

    property real targetHeight: baseHeight
    property real targetWidth: moduleActive ? baseWidth : 0

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "calendar"]);
            }
        }
    }

    property bool isHovered: bgMouse.containsMouse
    property bool showLayout: false

    property real targetY: barWindow ? barWindow.baseOffsetY : 0
    y: targetY

    Behavior on y {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }

    width: targetWidth
    height: targetHeight

    readonly property bool isBarOpaque: (barWindow && barWindow.barOpacity !== undefined) ? (barWindow.barOpacity >= 1.0) : true
    readonly property bool paintOwnBackground: (!isGrouped && !isSolid)
    readonly property bool paintBaseBackground: (!isGrouped && !isSolid) || isBarOpaque

    color: "transparent"
    border.width: 0
    clip: true
    visible: (width > 0 || opacity > 0) && (!barWindow || !barWindow.positionChanging)
    opacity: (showLayout && moduleActive && (!barWindow || !barWindow.positionChanging)) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0

    Rectangle {
        id: bgRect
        z: -1
        width: parent.width
        height: parent.height
        radius: ThemeBackend.borderRadius
        color: timeDateRoot.isHovered ? ThemeBackend.surface0 : ThemeBackend.base
        property bool showBorder: (!timeDateRoot.isGrouped && !timeDateRoot.isSolid)
        border.width: showBorder ? 1 : 0
        border.color: showBorder ? (timeDateRoot.isHovered ? ThemeBackend.surface1 : ThemeBackend.surface0) : "transparent"
        visible: timeDateRoot.paintOwnBackground && height > 0

        Behavior on color { enabled: barWindow ? !barWindow.positionChanging : true; ColorAnimation { duration: 250 } }
    }

    Behavior on width {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on height {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
    }

    transform: Translate {
        y: timeDateRoot.showLayout ? 0 : (barWindow ? (timeDateRoot.isBottomBar ? barWindow.s(20) : barWindow.s(-20)) : (timeDateRoot.isBottomBar ? 20 : -20))
        Behavior on y {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    Timer {
        running: barWindow && barWindow.isStartupReady
        interval: 120
        onTriggered: timeDateRoot.showLayout = true
    }

    Item {
        id: topArea
        width: parent.width
        height: barWindow ? barWindow.barHeight : 30
        y: timeDateRoot.isBottomBar ? (parent.height - height) : 0

        Column {
            id: timeCol
            anchors.left: parent.left
            anchors.leftMargin: timeDateRoot.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text {
                anchors.left: parent.left
                text: timeStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(15) : 15
                font.weight: Font.Black
                color: ThemeBackend.blue
            }
            Text {
                anchors.left: parent.left
                text: dateStr
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(10) : 10
                font.weight: Font.Bold
                color: ThemeBackend.subtext0
            }
        }
    }
}
