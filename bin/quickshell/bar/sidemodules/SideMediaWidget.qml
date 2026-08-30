import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../reusables"
import "../../"

Rectangle {
    id: sideMediaRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool layoutAnimationsEnabled: true

    property var playerList: {
        if (!Mpris.players || !Mpris.players.values) return [];
        let list = [];
        let vals = Mpris.players.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i]) list.push(vals[i]);
        }
        return list;
    }

    property var manualPlayer: null

    property var targetPlayer: {
        if (manualPlayer) {
            for (let i = 0; i < playerList.length; i++) {
                if (playerList[i] === manualPlayer) return manualPlayer;
            }
        }
        return MprisController.activePlayer;
    }

    property bool hasTargetPlayer: targetPlayer !== null
    property bool isMediaActive: targetPlayer !== null && targetPlayer.playbackState !== MprisPlaybackState.Stopped && targetPlayer.trackTitle !== ""
    property bool isPlaying: targetPlayer ? (targetPlayer.playbackState === MprisPlaybackState.Playing || targetPlayer.isPlaying) : false
    readonly property bool isRightBar: barWindow ? (barWindow.barPosition === "right") : false

    property string rawArtUrl: (targetPlayer && targetPlayer === MprisController.activePlayer && MprisController.artUrl) ? MprisController.artUrl : (targetPlayer && targetPlayer.trackArtUrl ? targetPlayer.trackArtUrl : "")
    property string activeArtUrl: {
        if (!rawArtUrl) return "";
        if (rawArtUrl.indexOf("://") !== -1) return rawArtUrl;
        return "file://" + rawArtUrl;
    }

    property real baseWidth: barWindow ? barWindow.barHeight : 40
    property real baseHeight: barWindow ? barWindow.s(140) : 140
    property real targetHeight: baseHeight

    property real targetX: isRightBar ? (parent ? (parent.width - baseWidth) : 0) : 0
    property real targetY: 0

    x: targetX
    y: targetY
    width: baseWidth
    height: targetHeight
    z: 1
    clip: true

    color: "transparent"
    border.width: 0
    border.color: "transparent"

    opacity: moduleActive ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0 && (!barWindow || !barWindow.positionChanging)

    Behavior on x {
        enabled: layoutAnimationsEnabled && (barWindow ? !barWindow.positionChanging : true)
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }
    Behavior on width {
        enabled: layoutAnimationsEnabled && (barWindow ? !barWindow.positionChanging : true)
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }
    Behavior on height {
        enabled: layoutAnimationsEnabled && (barWindow ? !barWindow.positionChanging : true)
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        z: -1
        color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
        radius: ThemeBackend.borderRadius
        border.width: 0
        border.color: "transparent"
        clip: true

    }

    MouseArea {
        id: widgetMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            let pt = sideMediaRoot.mapToItem(null, 0, 0);
            let globX = isRightBar ? pt.x : (pt.x + width);
            let globY = pt.y + (height / 2);
            SideMusicController.itemEntered(barWindow ? barWindow.screen : null, globX, globY, isRightBar, false, true);
        }
        onExited: {
            SideMusicController.itemExited();
        }
        onClicked: {
            let pt = sideMediaRoot.mapToItem(null, 0, 0);
            let globX = isRightBar ? pt.x : (pt.x + width);
            let globY = pt.y + (height / 2);
            SideMusicController.toggle(barWindow ? barWindow.screen : null, globX, globY, isRightBar, false, true);
        }
    }

    Item {
        id: baseCol
        width: sideMediaRoot.baseWidth
        height: parent.height
        x: sideMediaRoot.isRightBar ? (parent.width - width) : 0
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: thumbBox
            anchors.top: parent.top
            anchors.topMargin: barWindow ? barWindow.s(8) : 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: barWindow ? barWindow.s(28) : 28
            height: barWindow ? barWindow.s(28) : 28
            radius: ThemeBackend.borderRadius
            color: ThemeBackend.surface1
            border.width: 1
            border.color: (isMediaActive && isPlaying) ? ThemeBackend.mauve : ThemeBackend.surface1
            clip: true

            Text {
                anchors.centerIn: parent
                text: "󰎈"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(13) : 13
                color: ThemeBackend.subtext0
                visible: !isMediaActive || sideMediaRoot.activeArtUrl === ""
            }

            Image {
                anchors.fill: parent
                source: sideMediaRoot.activeArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: isMediaActive && sideMediaRoot.activeArtUrl !== ""
            }

            Rectangle {
                anchors.fill: parent
                color: ThemeBackend.surface0
                opacity: 0.15
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Caching.serpantinumDir) {
                        Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"]);
                    }
                }
            }
        }

        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: barWindow ? barWindow.s(8) : 8
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: barWindow ? barWindow.s(4) : 4

            IconButton {
                width: barWindow ? barWindow.s(26) : 26
                height: barWindow ? barWindow.s(26) : 26
                cornerRadius: barWindow ? barWindow.s(8) : 8
                buttonIcon: "󰒮"
                iconFontSize: barWindow ? barWindow.s(13) : 13
                accentColor: ThemeBackend.surface0
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canGoPrevious) targetPlayer.previous()
            }

            IconButton {
                width: barWindow ? barWindow.s(28) : 28
                height: barWindow ? barWindow.s(28) : 28
                cornerRadius: barWindow ? barWindow.s(8) : 8
                buttonIcon: (isMediaActive && isPlaying) ? "󰏤" : "󰐊"
                iconFontSize: barWindow ? barWindow.s(15) : 15
                accentColor: ThemeBackend.surface0
                textColor: isHoveredOrHighlighted ? ThemeBackend.green : ThemeBackend.text
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canTogglePlaying) targetPlayer.togglePlaying()
            }

            IconButton {
                width: barWindow ? barWindow.s(26) : 26
                height: barWindow ? barWindow.s(26) : 26
                cornerRadius: barWindow ? barWindow.s(8) : 8
                buttonIcon: "󰒭"
                iconFontSize: barWindow ? barWindow.s(13) : 13
                accentColor: ThemeBackend.surface0
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canGoNext) targetPlayer.next()
            }
        }
    }
}
