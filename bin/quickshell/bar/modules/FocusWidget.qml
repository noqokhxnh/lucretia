import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../reusables"
import "../../singletons"
import "../../"

Rectangle {
    id: focusWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetX: 0

    readonly property string displayText: CurrentFocus.displayText
    readonly property bool isFocused: CurrentFocus.isFocused

    property real leftPadding: isSolid ? 0 : (barWindow ? barWindow.s(6) : 6)
    property real rightPadding: isSolid ? 0 : (barWindow ? barWindow.s(12) : 12)
    property real targetWidth: (moduleActive && isFocused) ? (leftPadding + focusIconButton.width + innerLayout.spacing + titleTextMain.implicitWidth + rightPadding) : 0

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    y: barWindow ? barWindow.baseOffsetY : 0
    height: barWindow ? barWindow.barHeight : 30
    radius: ThemeBackend.borderRadius
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    border.width: (isGrouped || isSolid) ? 0 : 1
    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    clip: true

    width: targetWidth
    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    opacity: (moduleActive && isFocused) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Row {
        id: innerLayout
        anchors.left: parent.left
        anchors.leftMargin: focusWidgetRoot.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: isSolid ? 0 : (barWindow ? barWindow.s(6) : 6)

        property bool initAnimTrigger: !barWindow || barWindow.startupCascadeFinished

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            y: innerLayout.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        IconButton {
            id: focusIconButton
            width: barWindow ? barWindow.s(30) : 30
            height: barWindow ? barWindow.s(30) : 30
            cornerRadius: barWindow ? barWindow.s(10) : 10
            buttonIcon: "✦"
            iconFontSize: barWindow ? barWindow.s(15) : 15
            accentColor: isSolid ? "transparent" : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                if (Caching.serpantinumDir) {
                    Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle applauncher"])
                }
            }
        }

        Item {
            id: titleClipRect
            width: titleTextMain.implicitWidth
            height: titleTextMain.implicitHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            property int marqueeSpacing: barWindow ? barWindow.s(30) : 30

            Item {
                id: marqueeContainer
                height: parent.height

                Row {
                    spacing: titleClipRect.marqueeSpacing
                    Text {
                        id: titleTextMain
                        text: focusWidgetRoot.displayText
                        color: ThemeBackend.text
                        font.pixelSize: barWindow ? barWindow.s(12) : 12

                        onTextChanged: {
                            titleAnim.stop();
                            marqueeContainer.x = 0;
                            if (titleTextMain.implicitWidth > titleClipRect.width) {
                                titleAnim.start();
                            }
                        }
                    }

                    Text {
                        id: titleTextClone
                        text: titleTextMain.text
                        color: ThemeBackend.text
                        font.pixelSize: barWindow ? barWindow.s(12) : 12
                        visible: titleTextMain.implicitWidth > titleClipRect.width
                    }
                }

                SequentialAnimation {
                    id: titleAnim
                    loops: Animation.Infinite
                    running: titleTextMain.implicitWidth > titleClipRect.width

                    PauseAnimation { duration: 3000 }

                    NumberAnimation {
                        target: marqueeContainer
                        property: "x"
                        from: 0
                        to: -(titleTextMain.implicitWidth + titleClipRect.marqueeSpacing)
                        duration: Math.max(1, (titleTextMain.implicitWidth + titleClipRect.marqueeSpacing) * 25)
                    }

                    PropertyAction { target: marqueeContainer; property: "x"; value: 0 }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        z: -1
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle applauncher"])
            }
        }
    }
}
