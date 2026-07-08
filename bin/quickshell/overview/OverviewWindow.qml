import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

Item {
    id: windowItem

    required property real wsScale
    required property real screenX
    required property real screenY

    property var toplevel: null
    property string title: ""
    property string appId: ""
    property bool isFocused: false

    anchors.fill: parent

    MatugenColors { id: mocha }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.85)
        radius: 8
        border.width: isFocused ? 2 : 1
        border.color: isFocused ? mocha.mauve : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15)
        clip: true

        ScreencopyView {
            anchors.fill: parent
            anchors.margins: 1
            captureSource: toplevel
            live: Config.overviewOpen
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(255, 255, 255, 0.05)
            visible: mouseArea.containsMouse
        }

        Rectangle {
            id: titleBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22
            color: Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.8)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                Image {
                    width: 12
                    height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    source: {
                        let iconName = getIconForAppId(appId)
                        return Quickshell.iconPath(iconName) || ""
                    }
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    width: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: title || "Window"
                    font.family: "Outfit"
                    font.pixelSize: 9
                    color: mocha.text
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            id: closeButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            width: 16
            height: 16
            radius: 8
            color: closeMouse.containsMouse ? mocha.red : Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.7)
            visible: mouseArea.containsMouse || closeMouse.containsMouse

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 8
                color: closeMouse.containsMouse ? mocha.base : mocha.text
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (toplevel) toplevel.close()
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onClicked: {
            if (toplevel) {
                Config.overviewOpen = false
                toplevel.activate()
            } else {
                Config.overviewOpen = false
                Config.sh("niri msg action focus-window --id " + modelData.id)
            }
        }
    }

    function getIconForAppId(idStr) {
        if (!idStr) return "application-x-executable";
        let lower = idStr.toLowerCase();
        if (lower.includes("brave")) return "brave-browser";
        if (lower.includes("chrome")) return "google-chrome";
        if (lower.includes("firefox")) return "firefox";
        if (lower.includes("kitty")) return "terminal";
        if (lower.includes("foot")) return "terminal";
        if (lower.includes("alacritty")) return "terminal";
        if (lower.includes("code")) return "com.visualstudio.code";
        if (lower.includes("nautilus")) return "org.gnome.Nautilus";
        if (lower.includes("thunar")) return "system-file-manager";
        if (lower.includes("spotify")) return "spotify";
        if (lower.includes("discord")) return "discord";
        if (lower.includes("steam")) return "steam";
        if (lower.includes("obsidian")) return "obsidian";
        if (lower.includes("telegram")) return "telegram";
        return idStr;
    }
}
