import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "../../reusables"
import "../../"

Rectangle {
    id: mediaWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real contentWrapperWidth: 0
    property bool layoutAnimationsEnabled: true

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""

    property real targetX: 0

    x: targetX
    Behavior on x {
        enabled: barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && layoutAnimationsEnabled) : layoutAnimationsEnabled
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    radius: ThemeBackend.borderRadius
    border.width: (isGrouped || isSolid) ? 0 : 1
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    y: barWindow ? barWindow.baseOffsetY : 0
    height: barWindow ? barWindow.barHeight : 0
    clip: true
    layer.enabled: true

    property real colWidth: barWindow ? barWindow.s(120) : 120
    property real innerSpacing: barWindow ? barWindow.s(8) : 8
    property real btnSpacing: barWindow ? barWindow.s(4) : 4

    property real targetWidth: {
        if (!moduleActive) return 0;
        let iconW = barWindow ? barWindow.s(28) : 28;
        let gapInfo = barWindow ? barWindow.s(10) : 10;
        let btnW = (barWindow ? barWindow.s(30) : 30) * 3 + btnSpacing * 2;
        let margins = (barWindow ? barWindow.s(12) : 12) * 2;
        return iconW + gapInfo + colWidth + innerSpacing + btnW + margins;
    }

    width: targetWidth
    Behavior on width {
        enabled: barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && layoutAnimationsEnabled) : layoutAnimationsEnabled
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    opacity: moduleActive ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Item {
        id: mediaLayoutContainer
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: barWindow ? barWindow.s(12) : 12
        anchors.right: parent.right
        anchors.rightMargin: barWindow ? barWindow.s(12) : 12
        height: parent.height
        clip: true

        Row {
            id: innerMediaLayout
            anchors.verticalCenter: parent.verticalCenter
            spacing: mediaWidgetRoot.innerSpacing

            MouseArea {
                id: mediaInfoMouse
                width: infoLayout.implicitWidth
                height: mediaLayoutContainer.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"])

                Row {
                    id: infoLayout
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barWindow ? barWindow.s(10) : 10

                    scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                    Rectangle {
                        width: barWindow ? barWindow.s(28) : 28
                        height: barWindow ? barWindow.s(28) : 28
                        radius: ThemeBackend.borderRadius
                        color: ThemeBackend.surface1
                        border.width: 1
                        border.color: (isMediaActive && MprisController.isPlaying) ? ThemeBackend.mauve : ThemeBackend.surface1
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: barWindow ? barWindow.s(14) : 14
                            color: ThemeBackend.subtext0
                            visible: !isMediaActive || !MprisController.artUrl
                        }

                        Image {
                            anchors.fill: parent
                            source: (isMediaActive && MprisController.artUrl) ? "file://" + MprisController.artUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: isMediaActive && MprisController.artUrl !== ""
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: ThemeBackend.surface0
                            opacity: 0.15
                        }
                    }

                    Column {
                        spacing: -2
                        anchors.verticalCenter: parent.verticalCenter
                        width: mediaWidgetRoot.colWidth

                        Item {
                            id: titleClipRect
                            width: parent.width
                            height: titleTextMain.implicitHeight
                            clip: true

                            property int marqueeSpacing: barWindow ? barWindow.s(40) : 40

                            onWidthChanged: {
                                marqueeContainer.x = 0;
                                if (titleTextMain.implicitWidth > width) {
                                    titleAnim.restart();
                                } else {
                                    titleAnim.stop();
                                }
                            }

                            Item {
                                id: marqueeContainer
                                height: parent.height

                                Row {
                                    spacing: titleClipRect.marqueeSpacing
                                    Text {
                                        id: titleTextMain
                                        text: isMediaActive ? (player ? player.trackTitle : "") : I18n.t("music.nothing_playing")
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: barWindow ? barWindow.s(12) : 12
                                        color: ThemeBackend.text

                                        onTextChanged: {
                                            marqueeContainer.x = 0;
                                            if (implicitWidth > titleClipRect.width) {
                                                titleAnim.restart();
                                            } else {
                                                titleAnim.stop();
                                            }
                                        }
                                    }

                                    Text {
                                        id: titleTextClone
                                        text: titleTextMain.text
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: barWindow ? barWindow.s(12) : 12
                                        color: ThemeBackend.text
                                        visible: titleTextMain.implicitWidth > titleClipRect.width
                                    }
                                }

                                SequentialAnimation on x {
                                    id: titleAnim
                                    loops: Animation.Infinite
                                    running: titleTextMain.implicitWidth > titleClipRect.width

                                    onRunningChanged: {
                                        if (!running) marqueeContainer.x = 0;
                                    }

                                    PauseAnimation { duration: isMediaActive ? 3000 : 6000 }

                                    NumberAnimation {
                                        from: 0
                                        to: -(titleTextMain.implicitWidth + titleClipRect.marqueeSpacing)
                                        duration: (titleTextMain.implicitWidth + titleClipRect.marqueeSpacing) * (isMediaActive ? 25 : 65)
                                    }

                                    PropertyAction { target: marqueeContainer; property: "x"; value: 0 }
                                }
                            }
                        }

                        Text {
                            text: isMediaActive && player ? (mediaWidgetRoot.formatTime(MprisController.livePosition) + " / " + mediaWidgetRoot.formatTime(player.length)) : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: barWindow ? barWindow.s(10) : 10
                            color: ThemeBackend.subtext0
                            width: parent.width
                            elide: Text.ElideRight
                            visible: isMediaActive
                        }
                    }
                }
            }

            Row {
                id: buttonRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: mediaWidgetRoot.btnSpacing

                IconButton {
                    id: prevMediaButton
                    height: barWindow ? barWindow.s(30) : 30
                    width: barWindow ? barWindow.s(30) : 30
                    cornerRadius: barWindow ? barWindow.s(10) : 10
                    buttonIcon: "󰒮"
                    iconFontSize: barWindow ? barWindow.s(16) : 16
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoPrevious) player.previous()
                }

                IconButton {
                    id: playMediaButton
                    height: barWindow ? barWindow.s(30) : 30
                    width: barWindow ? barWindow.s(30) : 30
                    cornerRadius: barWindow ? barWindow.s(10) : 10
                    buttonIcon: (isMediaActive && MprisController.isPlaying) ? "󰏤" : "󰐊"
                    iconFontSize: barWindow ? barWindow.s(18) : 18
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.green : ThemeBackend.text
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
                }

                IconButton {
                    id: nextMediaButton
                    height: barWindow ? barWindow.s(30) : 30
                    width: barWindow ? barWindow.s(30) : 30
                    cornerRadius: barWindow ? barWindow.s(10) : 10
                    buttonIcon: "󰒭"
                    iconFontSize: barWindow ? barWindow.s(16) : 16
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoNext) player.next()
                }
            }
        }
    }
}
