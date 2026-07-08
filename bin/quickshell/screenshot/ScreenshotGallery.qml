import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: galleryRoot

    property real layoutWidth: 900
    property real layoutHeight: 700

    function s(val) {
        return Math.round(val * (galleryRoot.layoutWidth / 900.0));
    }

    MatugenColors { id: mocha }

    property var screenshotFiles: []
    readonly property string saveDir: {
        let xdg = Quickshell.env("XDG_PICTURES_DIR");
        let home = Quickshell.env("HOME");
        return (xdg !== "" ? xdg : (home + "/Pictures")) + "/Screenshots";
    }

    Component.onCompleted: {
        loadScreenshots();
    }

    Connections {
        target: galleryRoot
        function onVisibleChanged() {
            if (galleryRoot.visible) loadScreenshots();
        }
    }

    Process {
        id: listProcess
        command: ["bash", "-c", "ls -t '" + galleryRoot.saveDir + "/'*.png '" + galleryRoot.saveDir + "/'*.jpg '" + galleryRoot.saveDir + "/'*.jpeg 2>/dev/null | head -30"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                let files = txt !== "" ? txt.split("\n") : [];
                screenshotModel.clear();
                for (let i = 0; i < files.length; i++) {
                    let path = files[i].trim();
                    if (path !== "") {
                        let parts = path.split("/");
                        let name = parts[parts.length - 1];
                        screenshotModel.append({
                            "filePath": path,
                            "fileName": name,
                            "fileUrl": "file://" + path
                        });
                    }
                }
            }
        }
    }

    function loadScreenshots() {
        listProcess.running = true;
    }

    ListModel { id: screenshotModel }

    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introAnim
        from: 0; to: 1; duration: 600; easing.type: Easing.OutExpo; running: true
    }

    // Background
    Rectangle {
        anchors.fill: parent
        radius: s(24)
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.9)
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.05)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: s(24)
        spacing: s(16)

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "󰹑"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: s(28)
                color: mocha.green
            }

            Text {
                text: "Screenshot Gallery"
                font.family: "Outfit"
                font.pixelSize: s(26)
                font.weight: Font.Bold
                color: mocha.text
                Layout.fillWidth: true
                Layout.leftMargin: s(12)
            }

            // Refresh button
            Rectangle {
                width: s(36); height: s(36); radius: s(18)
                color: refreshMa.containsMouse ? mocha.surface1 : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(18)
                    color: mocha.subtext0
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: loadScreenshots()
                }
            }

            // Open folder button
            Rectangle {
                width: s(36); height: s(36); radius: s(18)
                color: folderMa.containsMouse ? mocha.surface1 : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰝰"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(18)
                    color: mocha.subtext0
                }
                MouseArea {
                    id: folderMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", galleryRoot.saveDir])
                }
            }
        }

        // Info bar
        Text {
            text: screenshotModel.count + " screenshots found"
            font.family: "JetBrains Mono"
            font.pixelSize: s(12)
            color: mocha.subtext0
            visible: screenshotModel.count > 0
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: screenshotModel.count === 0

            Column {
                anchors.centerIn: parent
                spacing: s(16)

                Text {
                    text: "󰹑"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(64)
                    color: mocha.surface2
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "No screenshots yet"
                    font.family: "Outfit"
                    font.pixelSize: s(20)
                    font.weight: Font.DemiBold
                    color: mocha.subtext0
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Take a screenshot to see it here"
                    font.family: "Outfit"
                    font.pixelSize: s(14)
                    color: mocha.overlay0
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Grid
        GridView {
            id: gridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: screenshotModel.count > 0

            cellWidth: s(270)
            cellHeight: s(180)

            model: screenshotModel

            ScrollBar.vertical: ScrollBar {
                active: true
                width: s(4)
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: s(4); radius: s(2); color: mocha.surface2 }
            }

            delegate: Item {
                width: gridView.cellWidth
                height: gridView.cellHeight

                property bool isHovered: delegateMa.containsMouse || (copyMa && copyMa.containsMouse) || (delMa && delMa.containsMouse)

                Rectangle {
                    id: card
                    anchors.fill: parent
                    anchors.margins: s(6)
                    radius: s(14)
                    color: mocha.surface0
                    border.width: 1
                    border.color: isHovered ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.4) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    clip: true

                    scale: isHovered ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    // Thumbnail
                    Image {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: s(3)
                        source: model.fileUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(s(280), s(180))

                        Rectangle {
                            anchors.fill: parent
                            color: mocha.surface0
                            visible: thumb.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent
                                text: "󰔟"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(24)
                                color: mocha.overlay0
                            }
                        }
                    }

                    // MouseArea for clicking/hovering the card, placed before bottom overlay so buttons get clicks
                    MouseArea {
                        id: delegateMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", model.filePath])
                    }

                    // Bottom overlay with filename
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: s(36)
                        color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.85)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: s(10)
                            anchors.rightMargin: s(6)
                            spacing: s(6)

                            Text {
                                text: model.fileName
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(10)
                                color: mocha.subtext0
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            // Copy button
                            Rectangle {
                                width: s(26); height: s(26); radius: s(6)
                                color: copyMa.containsMouse ? mocha.green : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                visible: isHovered

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆏"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: s(14)
                                    color: copyMa.containsMouse ? mocha.base : mocha.subtext0
                                }
                                MouseArea {
                                    id: copyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["bash", "-c", "wl-copy < '" + model.filePath + "' && notify-send -a 'Screenshot' 'Copied to clipboard'"]);
                                    }
                                }
                            }

                            // Delete button
                            Rectangle {
                                width: s(26); height: s(26); radius: s(6)
                                color: delMa.containsMouse ? mocha.red : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                visible: isHovered

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: s(14)
                                    color: delMa.containsMouse ? mocha.base : mocha.subtext0
                                }
                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["bash", "-c", "rm -f '" + model.filePath + "' && notify-send -a 'Screenshot' 'Screenshot deleted'"]);
                                        loadScreenshots();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
