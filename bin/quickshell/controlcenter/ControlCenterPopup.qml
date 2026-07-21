import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../components"
import "../"

Item {
    id: controlCenterRoot

    property real layoutWidth: 420
    property real layoutHeight: 580

    function s(val) {
        return Math.round(val * (controlCenterRoot.layoutWidth / 420.0));
    }

    MatugenColors { id: mocha }

    // --- Ambient orbit animation ---
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    property real introMain: 0

    SequentialAnimation {
        running: true
        PauseAnimation { duration: 20 }
        NumberAnimation { target: controlCenterRoot; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }
    }

    // Background
    Rectangle {
        anchors.fill: parent
        radius: s(20)
        color: mocha.base
        border.color: mocha.surface0
        border.width: 1
        clip: true

        // Ambient blobs
        Rectangle {
            width: parent.width * 0.6; height: width; radius: width / 2
            x: (parent.width * 0.7 - width / 2) + Math.cos(controlCenterRoot.globalOrbitAngle * 1.3) * s(80)
            y: (parent.height * 0.3 - height / 2) + Math.sin(controlCenterRoot.globalOrbitAngle * 1.3) * s(60)
            opacity: 0.025
            color: mocha.mauve
        }
        Rectangle {
            width: parent.width * 0.5; height: width; radius: width / 2
            x: (parent.width * 0.3 - width / 2) + Math.sin(controlCenterRoot.globalOrbitAngle * 1.1) * s(-70)
            y: (parent.height * 0.7 - height / 2) + Math.cos(controlCenterRoot.globalOrbitAngle * 1.1) * s(-50)
            opacity: 0.02
            color: mocha.blue
        }
    }

    // Content
    Item {
        anchors.fill: parent
        anchors.margins: s(20)
        opacity: controlCenterRoot.introMain
        scale: 0.97 + (0.03 * controlCenterRoot.introMain)

        Flickable {
            anchors.fill: parent
            clip: true
            contentHeight: contentCol.height
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                active: true
                width: s(4)
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: s(3); radius: s(2); color: mocha.surface2 }
            }

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: s(16)

                // Header
                Text {
                    text: "Control Center"
                    font.family: "Outfit"
                    font.pixelSize: s(22)
                    font.weight: Font.Bold
                    color: mocha.text
                    Layout.bottomMargin: s(4)
                }

                // === Quick Toggles Row ===
                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(8)

                    // DND Toggle
                    Rectangle {
                        Layout.fillWidth: true
                        height: s(56)
                        radius: s(12)
                        color: Config.dndMode ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.15) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.15)
                        border.color: Config.dndMode ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.3) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: s(2)
                            Text {
                                text: Config.dndMode ? "󰂛" : "󰂚"
                                font.family: "Nerd Font Mono"
                                font.pixelSize: s(18)
                                color: Config.dndMode ? mocha.red : mocha.overlay0
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "DND"
                                font.family: "Outfit"
                                font.pixelSize: s(10)
                                font.weight: Font.Bold
                                color: Config.dndMode ? mocha.red : mocha.overlay1
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.toggleDnd()
                        }
                    }

                    // Screenshot Toggle
                    Rectangle {
                        Layout.fillWidth: true
                        height: s(56)
                        radius: s(12)
                        color: Config.beautifyScreenshot ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.15) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.15)
                        border.color: Config.beautifyScreenshot ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.3) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: s(2)
                            Text {
                                text: "󰃏"
                                font.family: "Nerd Font Mono"
                                font.pixelSize: s(18)
                                color: Config.beautifyScreenshot ? mocha.yellow : mocha.overlay0
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Beauty"
                                font.family: "Outfit"
                                font.pixelSize: s(10)
                                font.weight: Font.Bold
                                color: Config.beautifyScreenshot ? mocha.yellow : mocha.overlay1
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.beautifyScreenshot = !Config.beautifyScreenshot;
                                saveTimer.restart();
                            }
                        }
                    }
                }

                // === Appearance Card ===
                Rectangle {
                    Layout.fillWidth: true
                    height: appearanceCol.height + s(24)
                    radius: s(12)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.15)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                    border.width: 1

                    ColumnLayout {
                        id: appearanceCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(10)

                        Text {
                            text: "Theme"
                            font.family: "Outfit"
                            font.pixelSize: s(13)
                            font.weight: Font.Bold
                            color: mocha.overlay1
                        }

                        GridLayout {
                            columns: 6
                            columnSpacing: s(8)
                            rowSpacing: s(8)
                            Layout.fillWidth: true

                            Repeater {
                                model: [
                                    { hex: "#89b4fa" }, { hex: "#cba6f7" }, { hex: "#fab387" },
                                    { hex: "#a6e3a1" }, { hex: "#f38ba8" }, { hex: "#94e2d5" }
                                ]
                                delegate: Rectangle {
                                    property bool isHovered: cMa.containsMouse
                                    Layout.preferredWidth: s(36)
                                    Layout.preferredHeight: s(36)
                                    radius: s(18)
                                    color: modelData.hex
                                    border.width: 1
                                    border.color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.5) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.3)

                                    scale: isHovered ? 1.15 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                                    MouseArea {
                                        id: cMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["bash", "-c", "matugen color hex '" + modelData.hex + "' && " + Config.qsScriptsDir + "/wallpaper/matugen_reload.sh"])
                                    }
                                }
                            }
                        }

                        // Animation Speed
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(10)

                            Text {
                                text: "Speed"
                                font.family: "Outfit"
                                font.pixelSize: s(12)
                                color: mocha.overlay1
                            }

                            QsSlider {
                                Layout.fillWidth: true
                                height: s(8)
                                from: 0.25; to: 2.0
                                value: Config.animSpeedMultiplier
                                activeColor: mocha.mauve
                                trackColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                                onValueChanged: {
                                    if (Config.animSpeedMultiplier !== value) {
                                        Config.animSpeedMultiplier = value;
                                        saveTimer.restart();
                                    }
                                }
                            }

                            Text {
                                text: Config.animSpeedMultiplier.toFixed(2) + "x"
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(12)
                                font.weight: Font.Bold
                                color: mocha.text
                                Layout.minimumWidth: s(36)
                            }
                        }
                    }
                }

                // === Power Profile Card ===
                Rectangle {
                    Layout.fillWidth: true
                    height: powerCol.height + s(24)
                    radius: s(12)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.15)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                    border.width: 1

                    ColumnLayout {
                        id: powerCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(10)

                        Text {
                            text: "Power Profile"
                            font.family: "Outfit"
                            font.pixelSize: s(13)
                            font.weight: Font.Bold
                            color: mocha.overlay1
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(6)

                            Repeater {
                                model: [
                                    { key: "performance", label: "󰓅", color1: "#f38ba8", color2: "#fab387" },
                                    { key: "balanced", label: "󰗑", color1: "#89b4fa", color2: "#74c7ec" },
                                    { key: "power-saver", label: "󰌪", color1: "#a6e3a1", color2: "#94e2d5" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: s(44)
                                    radius: s(10)
                                    clip: true

                                    property bool isActive: Config.powerProfile === modelData.key
                                    property bool isHovered: ppMa.containsMouse

                                    color: isActive ? "transparent" : (isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.3) : "transparent")
                                    border.width: 1
                                    border.color: isActive ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.5) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: s(10)
                                        opacity: isActive ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: modelData.color1 }
                                            GradientStop { position: 1.0; color: modelData.color2 }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: "Nerd Font Mono"
                                        font.pixelSize: s(18)
                                        color: isActive ? mocha.base : mocha.text
                                    }

                                    scale: isHovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                                    MouseArea {
                                        id: ppMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.setPowerProfile(modelData.key)
                                    }
                                }
                            }
                        }

                        // Auto Power
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(8)

                            Text {
                                text: "Auto"
                                font.family: "Outfit"
                                font.pixelSize: s(12)
                                color: mocha.overlay1
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: s(36); height: s(18); radius: s(9)
                                color: Config.autoPowerMode ? mocha.green : mocha.surface1
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    width: s(14); height: s(14); radius: s(7)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Config.autoPowerMode ? s(19) : s(2)
                                    color: mocha.base
                                    Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier); easing.type: Easing.OutExpo } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { Config.autoPowerMode = !Config.autoPowerMode; saveTimer.restart(); }
                                }
                            }
                        }
                    }
                }

                // === TopBar Modules Card ===
                Rectangle {
                    Layout.fillWidth: true
                    height: modulesCol.height + s(24)
                    radius: s(12)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.15)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                    border.width: 1

                    ColumnLayout {
                        id: modulesCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(6)

                        Text {
                            text: "TopBar Modules"
                            font.family: "Outfit"
                            font.pixelSize: s(13)
                            font.weight: Font.Bold
                            color: mocha.overlay1
                            Layout.bottomMargin: s(4)
                        }

                        Repeater {
                            model: [
                                { key: "music", label: "Music", icon: "󰎆" },
                                { key: "battery", label: "Battery", icon: "󰁹" },
                                { key: "wifi", label: "Wi-Fi", icon: "󰖩" },
                                { key: "bluetooth", label: "Bluetooth", icon: "󰂯" },
                                { key: "volume", label: "Volume", icon: "󰕾" },
                                { key: "tray", label: "SysTray", icon: "󰍜" },
                                { key: "system", label: "System Info", icon: "󰻠" },
                                { key: "updater", label: "Update Alert", icon: "󰚰" },
                                { key: "dnd", label: "Do Not Disturb", icon: "󰂚" },
                                { key: "notes", label: "Quick Notes", icon: "󱇗" },
                                { key: "focustime", label: "Focus Time", icon: "󱎫" }
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                height: s(32)
                                spacing: s(8)

                                Text {
                                    text: modelData.icon
                                    font.family: "Nerd Font Mono"
                                    font.pixelSize: s(14)
                                    color: Config.enabledModules[modelData.key] ? mocha.blue : mocha.overlay0
                                }

                                Text {
                                    text: modelData.label
                                    font.family: "Outfit"
                                    font.pixelSize: s(12)
                                    color: mocha.text
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: s(32); height: s(16); radius: s(8)
                                    color: Config.enabledModules[modelData.key] ? mocha.green : mocha.surface1
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Rectangle {
                                        width: s(12); height: s(12); radius: s(6)
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Config.enabledModules[modelData.key] ? s(17) : s(2)
                                        color: mocha.base
                                        Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier); easing.type: Easing.OutExpo } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let mods = Object.assign({}, Config.enabledModules);
                                            if (mods[modelData.key] === undefined) mods[modelData.key] = false;
                                            else mods[modelData.key] = !mods[modelData.key];
                                            Config.enabledModules = mods;
                                            saveTimer.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // === Screen Timeout Card ===
                Rectangle {
                    Layout.fillWidth: true
                    height: screenCol.height + s(24)
                    radius: s(12)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.15)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                    border.width: 1

                    ColumnLayout {
                        id: screenCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(8)

                        Text {
                            text: "Screen & Sleep"
                            font.family: "Outfit"
                            font.pixelSize: s(13)
                            font.weight: Font.Bold
                            color: mocha.overlay1
                            Layout.bottomMargin: s(2)
                        }

                        Repeater {
                            model: [
                                { label: "Lock Screen", value: Config.idleLockTimeout, color: mocha.mauve, prop: "idleLockTimeout", def: 10 },
                                { label: "Screen Off", value: Config.idleScreenOffTimeout, color: mocha.blue, prop: "idleScreenOffTimeout", def: 5 },
                                { label: "Sleep", value: Config.idleSleepTimeout, color: mocha.green, prop: "idleSleepTimeout", def: 60 }
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: s(8)

                                Text {
                                    text: modelData.label
                                    font.family: "Outfit"
                                    font.pixelSize: s(12)
                                    color: mocha.text
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.value === 0 ? "Never" : modelData.value + "m"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: s(11)
                                    font.weight: Font.Bold
                                    color: modelData.color
                                    Layout.minimumWidth: s(40)
                                    horizontalAlignment: Text.AlignRight
                                }

                                QsButton {
                                    Layout.preferredWidth: s(32)
                                    Layout.preferredHeight: s(22)
                                    text: "-"
                                    textFont: "Outfit"
                                    textSize: 12
                                    baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                                    hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.5)
                                    textColor: mocha.text
                                    onClicked: {
                                        let val = Math.max(0, Config[modelData.prop] - 5);
                                        if (Config[modelData.prop] !== val) { Config[modelData.prop] = val; saveTimer.restart(); }
                                    }
                                }

                                QsButton {
                                    Layout.preferredWidth: s(32)
                                    Layout.preferredHeight: s(22)
                                    text: "+"
                                    textFont: "Outfit"
                                    textSize: 12
                                    baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                                    hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.5)
                                    textColor: mocha.text
                                    onClicked: {
                                        let val = Math.min(180, Config[modelData.prop] + 5);
                                        if (Config[modelData.prop] !== val) { Config[modelData.prop] = val; saveTimer.restart(); }
                                    }
                                }

                                QsButton {
                                    Layout.preferredWidth: s(42)
                                    Layout.preferredHeight: s(22)
                                    text: "Def"
                                    textFont: "Outfit"
                                    textSize: 10
                                    baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                                    hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.5)
                                    textColor: mocha.overlay1
                                    onClicked: {
                                        if (Config[modelData.prop] !== modelData.def) { Config[modelData.prop] = modelData.def; saveTimer.restart(); }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: s(10) }
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 150
        onTriggered: Config.applyControlCenterSettings()
    }

    Component.onDestruction: {
        if (saveTimer.running) {
            saveTimer.stop();
            Config.applyControlCenterSettings();
        }
    }
}
