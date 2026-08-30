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
    id: sideWeatherWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    readonly property bool isRightBar: barWindow ? (barWindow.barPosition === "right") : false

    property string weatherIcon: Weather.currentIcon
    property string weatherTemp: {
        let raw = Weather.currentTemp !== "" ? Weather.currentTemp : Weather.currentTempFormatted;
        if (!raw || raw === "") return "--°";
        let intPart = raw.split(".")[0].replace(/[^\d-]/g, "");
        return (intPart !== "" ? intPart : "--") + "°";
    }
    property string weatherHex: Weather.currentHex
    property bool isWeatherLoading: Weather.isLoading || !Weather.isReady

    property int animDuration: 600
    property real targetY: 0
    y: targetY

    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging
        NumberAnimation { duration: sideWeatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }

    property real verticalPadding: barWindow ? barWindow.s(12) : 12
    property real baseHeight: weatherCol.implicitHeight + (verticalPadding * 2)
    property real baseWidth: barWindow ? barWindow.barHeight : 40

    property real targetWidth: moduleActive ? baseWidth : 0
    property real targetHeight: moduleActive ? baseHeight : 0

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

    property real targetX: isRightBar ? (parent ? (parent.width - targetWidth) : 0) : 0
    x: targetX

    Behavior on x {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideWeatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }

    width: targetWidth
    height: targetHeight

    readonly property bool isBarOpaque: (barWindow && barWindow.barOpacity !== undefined) ? (barWindow.barOpacity >= 1.0) : true
    readonly property bool paintOwnBackground: (!isGrouped && !isSolid)
    readonly property bool paintBaseBackground: (!isGrouped && !isSolid) || isBarOpaque

    color: "transparent"
    border.width: 0
    clip: true
    visible: (height > 0 || opacity > 0) && (!barWindow || !barWindow.positionChanging)
    opacity: (showLayout && moduleActive && (!barWindow || !barWindow.positionChanging)) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0

    Rectangle {
        id: bgRect
        z: -1
        width: parent.width
        height: parent.height
        radius: ThemeBackend.borderRadius
        color: sideWeatherWidgetRoot.isHovered ? ThemeBackend.surface0 : ThemeBackend.base
        property bool showBorder: (!sideWeatherWidgetRoot.isGrouped && !sideWeatherWidgetRoot.isSolid)
        border.width: showBorder ? 1 : 0
        border.color: showBorder ? (sideWeatherWidgetRoot.isHovered ? ThemeBackend.surface1 : ThemeBackend.surface0) : "transparent"
        visible: sideWeatherWidgetRoot.paintOwnBackground && width > 0

        Behavior on color { enabled: barWindow ? !barWindow.positionChanging : true; ColorAnimation { duration: 250 } }
    }

    Behavior on width {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideWeatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on height {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideWeatherWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
    }

    transform: Translate {
        x: sideWeatherWidgetRoot.showLayout ? 0 : (barWindow ? (sideWeatherWidgetRoot.isRightBar ? barWindow.s(20) : barWindow.s(-20)) : (sideWeatherWidgetRoot.isRightBar ? 20 : -20))
        Behavior on x {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    Timer {
        running: barWindow && barWindow.isStartupReady
        interval: 120
        onTriggered: sideWeatherWidgetRoot.showLayout = true
    }

    Item {
        id: topArea
        width: barWindow ? barWindow.barHeight : 40
        height: parent.height
        x: sideWeatherWidgetRoot.isRightBar ? (parent.width - width) : 0

        Column {
            id: weatherCol
            anchors.centerIn: parent
            spacing: barWindow ? barWindow.s(3) : 3

            LoaderIcon {
                id: weatherLoader
                anchors.horizontalCenter: parent.horizontalCenter
                width: barWindow ? barWindow.s(20) : 20
                height: barWindow ? barWindow.s(20) : 20
                accentColor: ThemeBackend.mauve
                running: sideWeatherWidgetRoot.isWeatherLoading
                visible: sideWeatherWidgetRoot.isWeatherLoading
            }

            Text {
                text: weatherIcon
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: "Iosevka Nerd Font"
                font.pixelSize: barWindow ? barWindow.s(18) : 18
                color: Qt.tint(weatherHex, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.4))
                visible: !sideWeatherWidgetRoot.isWeatherLoading && weatherIcon !== ""
            }

            Text {
                text: weatherTemp
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(12) : 12
                font.weight: Font.Black
                color: ThemeBackend.peach
                visible: !sideWeatherWidgetRoot.isWeatherLoading
            }
        }
    }
}
