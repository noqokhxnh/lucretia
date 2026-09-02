import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideSysMonRoot
    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0
    property bool showLayout: false

    property bool isSysVisible: moduleActive && showLayout

    function updateSubscription() {
        if (isSysVisible) {
            SysData.subscribe()
        } else {
            SysData.unsubscribe()
        }
    }

    Component.onCompleted: updateSubscription()
    Component.onDestruction: SysData.unsubscribe()
    onIsSysVisibleChanged: updateSubscription()

    x: barWindow ? barWindow.baseOffsetX : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    width: barWindow ? barWindow.barHeight : 40
    radius: Math.min(ThemeBackend.borderRadius, width / 2)
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    border.width: (isGrouped || isSolid) ? 0 : 1
    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    clip: true
    layer.enabled: true

    property real targetHeight: (moduleActive && sysCol.implicitHeight > 0) ? (sysCol.implicitHeight + (barWindow ? barWindow.s(10) : 10)) : 0
    height: targetHeight

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: sideSysMonRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: sideSysMonRoot.showLayout = true
    }

    transform: Translate {
        y: sideSysMonRoot.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    component SysMonPill: Rectangle {
        id: pillRoot
        property real value: 0
        property string icon: ""
        property color accentColor: ThemeBackend.mauve
        property bool initAnimTrigger: false

        property real animValue: value
        Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

        property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))

        height: sysCol.pillHeight
        width: sysCol.pillWidth
        radius: Math.min(Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2)), width / 2)
        color: ThemeBackend.surface0
        border.color: ThemeBackend.surface1
        border.width: 1
        clip: true

        Timer {
            running: sideSysMonRoot.moduleActive && sideSysMonRoot.showLayout && !initAnimTrigger
            interval: 150
            onTriggered: initAnimTrigger = true
        }

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            y: initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        // --- Hardware-accelerated GPU fill (SceneGraph) ---
        Item {
            id: fillContainer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(parent.height, Math.max(0, parent.height * pillRoot.fillRatio))
            clip: true
            visible: pillRoot.fillRatio > 0

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: pillRoot.height
                radius: pillRoot.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(pillRoot.accentColor, 1.25) }
                    GradientStop { position: 1.0; color: pillRoot.accentColor }
                }
                opacity: 0.95
            }
        }

        Text {
            anchors.centerIn: parent
            text: icon
            font.family: ThemeBackend.fontFamily
            font.pixelSize: barWindow ? barWindow.s(11.55) : 11.55
            color: ThemeBackend.subtext0
        }

        Item {
            id: waveClipBox
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(parent.height, Math.max(0, parent.height * pillRoot.fillRatio))
            clip: true
            visible: pillRoot.fillRatio > 0

            Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: pillRoot.height

                Text {
                    anchors.centerIn: parent
                    text: icon
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: barWindow ? barWindow.s(11.55) : 11.55
                    color: ThemeBackend.crust
                }
            }
        }
    }

    Column {
        id: sysCol
        anchors.centerIn: parent
        spacing: barWindow ? barWindow.s(6) : 6
        property int pillHeight: barWindow ? barWindow.s(28) : 28
        property int pillWidth: barWindow ? barWindow.s(28) : 28

        SysMonPill {
            value: isNaN(SysData.cpu) ? 0 : SysData.cpu / 100.0
            icon: "\uF2DB"
            accentColor: ThemeBackend.mauve
        }

        SysMonPill {
            value: isNaN(SysData.ramPercent) ? 0 : SysData.ramPercent / 100.0
            icon: "\uF538"
            accentColor: ThemeBackend.sapphire
        }

        SysMonPill {
            value: isNaN(SysData.temp) ? 0 : Math.max(0, Math.min(1, SysData.temp / 100.0))
            icon: "\uF2C9"
            accentColor: ThemeBackend.red
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["quickshell", "-p", Caching.mainQml, "ipc", "call", "floating", "showSystemUsage"]);
        }
    }
}
