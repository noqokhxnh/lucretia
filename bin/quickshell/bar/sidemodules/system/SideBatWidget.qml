import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideBatRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0
    property bool showLayout: false
    property alias batPill: batBtn

    property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop
    readonly property int batCap: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isCharging: UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    readonly property string batIcon: isDesktop ? "󰐥" : (isCharging ? "󰂄" : (batCap > 20 ? "󰁹" : "󰂃"))

    x: barWindow ? barWindow.baseOffsetX : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    width: barWindow ? barWindow.barHeight : 40
    height: barWindow ? barWindow.barHeight : 40

    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    radius: Math.min(ThemeBackend.borderRadius, width / 2)
    border.width: (isGrouped || isSolid) ? 0 : 1
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    clip: true
    layer.enabled: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: sideBatRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: sideBatRoot.showLayout = true
    }

    transform: Translate {
        y: sideBatRoot.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Rectangle {
        id: batBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(28) : 28
        height: barWindow ? barWindow.s(28) : 28
        radius: Math.min(Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2)), width / 2)
        color: ThemeBackend.surface0
        border.color: ThemeBackend.surface1
        border.width: 1
        clip: true

        property real value: sideBatRoot.isDesktop ? 0.0 : (UPower.displayDevice.ready ? UPower.displayDevice.percentage : 0.0)
        property color accentColor: sideBatRoot.isDesktop ? ThemeBackend.red : (sideBatRoot.isCharging ? ThemeBackend.green : (sideBatRoot.batCap <= 20 ? ThemeBackend.red : ThemeBackend.teal))
        property bool initAnimTrigger: false

        property real animValue: value
        Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

        property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))

        Timer {
            running: sideBatRoot.moduleActive && sideBatRoot.showLayout && !batBtn.initAnimTrigger
            interval: 150
            onTriggered: batBtn.initAnimTrigger = true
        }

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            y: batBtn.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        // --- Hardware-accelerated GPU fill (SceneGraph) ---
        Item {
            id: fillContainer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(parent.height, Math.max(0, parent.height * batBtn.fillRatio))
            clip: true
            visible: batBtn.fillRatio > 0

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: batBtn.height
                radius: batBtn.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(batBtn.accentColor, 1.25) }
                    GradientStop { position: 1.0; color: batBtn.accentColor }
                }
                opacity: 0.95
            }
        }

        Text {
            anchors.centerIn: parent
            text: sideBatRoot.batIcon
            font.family: ThemeBackend.fontFamily
            font.pixelSize: sideBatRoot.isDesktop ? (barWindow ? barWindow.s(16) : 16) : (barWindow ? barWindow.s(13.5) : 13.5)
            color: sideBatRoot.isDesktop ? ThemeBackend.red : ThemeBackend.subtext0
        }

        Item {
            id: waveClipBox
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(parent.height, Math.max(0, parent.height * batBtn.fillRatio))
            clip: true
            visible: batBtn.fillRatio > 0

            Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: batBtn.height

                Text {
                    anchors.centerIn: parent
                    text: sideBatRoot.batIcon
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: sideBatRoot.isDesktop ? (barWindow ? barWindow.s(16) : 16) : (barWindow ? barWindow.s(13.5) : 13.5)
                    color: ThemeBackend.crust
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["bash", Caching.home + "/.config/niri/bin/qs_manager.sh", "toggle", "system"])
        }
    }
}
