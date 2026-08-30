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
    id: weatherWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    readonly property bool isBottomBar: barWindow ? (barWindow.barPosition === "bottom") : false

    property string weatherIcon: Weather.currentIcon
    property string weatherTemp: Weather.currentTempFormatted
    property string weatherHex: Weather.currentHex
    property bool isWeatherLoading: Weather.isLoading || !Weather.isReady

    property int animDuration: 600
    property real targetX: 0
    x: targetX

    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging
        NumberAnimation { duration: weatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }

    property real horizontalPadding: barWindow ? barWindow.s(14) : 14
    property real baseWidth: weatherRow.implicitWidth + (horizontalPadding * 2)
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
        NumberAnimation { duration: weatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
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
        color: weatherWidgetRoot.isHovered ? ThemeBackend.surface0 : ThemeBackend.base
        property bool showBorder: (!weatherWidgetRoot.isGrouped && !weatherWidgetRoot.isSolid)
        border.width: showBorder ? 1 : 0
        border.color: showBorder ? (weatherWidgetRoot.isHovered ? ThemeBackend.surface1 : ThemeBackend.surface0) : "transparent"
        visible: weatherWidgetRoot.paintOwnBackground && height > 0

        Behavior on color { enabled: barWindow ? !barWindow.positionChanging : true; ColorAnimation { duration: 250 } }
    }

    Behavior on width {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: weatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on height {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: weatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
    }

    transform: Translate {
        y: weatherWidgetRoot.showLayout ? 0 : (barWindow ? (weatherWidgetRoot.isBottomBar ? barWindow.s(20) : barWindow.s(-20)) : (weatherWidgetRoot.isBottomBar ? 20 : -20))
        Behavior on y {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    Timer {
        running: barWindow && barWindow.isStartupReady
        interval: 120
        onTriggered: weatherWidgetRoot.showLayout = true
    }

    Item {
        id: topArea
        width: parent.width
        height: barWindow ? barWindow.barHeight : 30
        y: weatherWidgetRoot.isBottomBar ? (parent.height - height) : 0

        Row {
            id: weatherRow
            anchors.centerIn: parent
            spacing: barWindow ? barWindow.s(8) : 8

            LoaderIcon {
                id: weatherLoader
                anchors.verticalCenter: parent.verticalCenter
                width: barWindow ? barWindow.s(22) : 22
                height: barWindow ? barWindow.s(22) : 22
                accentColor: ThemeBackend.mauve
                running: weatherWidgetRoot.isWeatherLoading
                visible: weatherWidgetRoot.isWeatherLoading
            }

            Text {
                text: weatherIcon
                anchors.verticalCenter: parent.verticalCenter
                font.family: "Iosevka Nerd Font"
                font.pixelSize: barWindow ? barWindow.s(20) : 20
                color: Qt.tint(weatherHex, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.4))
                visible: !weatherWidgetRoot.isWeatherLoading && weatherIcon !== ""
            }
            Text {
                text: weatherTemp
                anchors.verticalCenter: parent.verticalCenter
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(15) : 15
                font.weight: Font.Black
                color: ThemeBackend.peach
                visible: !weatherWidgetRoot.isWeatherLoading
            }
        }
    }
}
