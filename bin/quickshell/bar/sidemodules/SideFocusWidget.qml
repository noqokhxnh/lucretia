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
    id: sideFocusRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0

    readonly property string displayText: CurrentFocus.displayText
    readonly property bool isFocused: CurrentFocus.isFocused

    property real topPadding: isSolid ? 0 : (barWindow ? barWindow.s(6) : 6)
    property real bottomPadding: isSolid ? 0 : (barWindow ? barWindow.s(12) : 12)
    property real targetHeight: (moduleActive && isFocused) ? (topPadding + focusIconButton.height + innerLayout.spacing + titleTextMain.implicitWidth + bottomPadding) : 0

    x: barWindow ? barWindow.baseOffsetX : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    width: barWindow ? barWindow.barHeight : 30
    height: targetHeight
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    radius: ThemeBackend.borderRadius
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    border.width: (isGrouped || isSolid) ? 0 : 1
    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    clip: true

    opacity: (moduleActive && isFocused) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Column {
        id: innerLayout
        anchors.top: parent.top
        anchors.topMargin: sideFocusRoot.topPadding
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: isSolid ? 0 : (barWindow ? barWindow.s(6) : 6)

        property bool initAnimTrigger: !barWindow || barWindow.startupCascadeFinished

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            x: innerLayout.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
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
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: {
                if (Caching.serpantinumDir) {
                    Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle applauncher"])
                }
            }
        }

        Item {
            id: titleClipRect
            width: focusIconButton.width
            height: titleTextMain.implicitWidth
            clip: true
            anchors.horizontalCenter: parent.horizontalCenter

            property int marqueeSpacing: barWindow ? barWindow.s(30) : 30

            Item {
                id: rotator
                anchors.centerIn: parent
                width: titleClipRect.height
                height: titleClipRect.width
                rotation: 90

                Item {
                    id: marqueeContainer
                    height: parent.height

                    Row {
                        spacing: titleClipRect.marqueeSpacing
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: titleTextMain
                            text: sideFocusRoot.displayText
                            color: ThemeBackend.text
                            font.pixelSize: barWindow ? barWindow.s(12) : 12

                            onTextChanged: {
                                titleAnim.stop();
                                marqueeContainer.x = 0;
                                if (titleTextMain.implicitWidth > titleClipRect.height) {
                                    titleAnim.start();
                                }
                            }
                        }

                        Text {
                            id: titleTextClone
                            text: titleTextMain.text
                            color: ThemeBackend.text
                            font.pixelSize: barWindow ? barWindow.s(12) : 12
                            visible: titleTextMain.implicitWidth > titleClipRect.height
                        }
                    }

                    SequentialAnimation {
                        id: titleAnim
                        loops: Animation.Infinite
                        running: titleTextMain.implicitWidth > titleClipRect.height

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
