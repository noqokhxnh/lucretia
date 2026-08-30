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
    property real layoutHeight: 620

    // Feedback state while matugen regenerates the theme
    property bool applyingTheme: false
    Timer { id: themeApplyFeedback; interval: 900; onTriggered: controlCenterRoot.applyingTheme = false }

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
        NumberAnimation { target: controlCenterRoot; property: "introMain"; from: 0; to: 1.0; duration: 600; easing.type: Easing.OutQuart }
    }

    // Main Card Container Background
    Rectangle {
        anchors.fill: parent
        radius: s(22)
        color: mocha.base
        border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.4)
        border.width: 1
        clip: true

        // Ambient background glow blobs
        Rectangle {
            width: parent.width * 0.75; height: width; radius: width / 2
            x: (parent.width * 0.6 - width / 2) + Math.cos(controlCenterRoot.globalOrbitAngle * 1.3) * s(60)
            y: (parent.height * 0.2 - height / 2) + Math.sin(controlCenterRoot.globalOrbitAngle * 1.3) * s(50)
            opacity: controlCenterRoot.applyingTheme ? 0.12 : 0.035
            Behavior on opacity { NumberAnimation { duration: 300 } }
            color: mocha.mauve
        }
        Rectangle {
            width: parent.width * 0.65; height: width; radius: width / 2
            x: (parent.width * 0.4 - width / 2) + Math.sin(controlCenterRoot.globalOrbitAngle * 1.1) * s(-50)
            y: (parent.height * 0.8 - height / 2) + Math.cos(controlCenterRoot.globalOrbitAngle * 1.1) * s(-40)
            opacity: controlCenterRoot.applyingTheme ? 0.10 : 0.03
            Behavior on opacity { NumberAnimation { duration: 300 } }
            color: mocha.blue
        }
    }

    // Main Scrollable Content Area
    Item {
        anchors.fill: parent
        anchors.margins: s(16)
        opacity: controlCenterRoot.introMain
        scale: 0.98 + (0.02 * controlCenterRoot.introMain)

        Flickable {
            anchors.fill: parent
            clip: true
            contentHeight: contentCol.height + s(16)
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                active: true
                width: s(4)
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: s(3); radius: s(2); color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.6) }
            }

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: s(14)

                // =============================================================
                // 1. Header Bar
                // =============================================================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    Rectangle {
                        width: s(36); height: s(36); radius: s(10)
                        color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.15)
                        border.color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.3)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰅃"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: s(18)
                            color: mocha.primary
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Control Center"
                            font.family: "Outfit"
                            font.pixelSize: s(18)
                            font.weight: Font.Bold
                            color: mocha.text
                        }
                        Text {
                            text: "System settings & theme customization"
                            font.family: "Outfit"
                            font.pixelSize: s(11)
                            color: mocha.subtext0
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // =============================================================
                // 2. Quick Toggles Row (DND & Beautify Screenshot)
                // =============================================================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    // DND Toggle Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: s(52)
                        radius: s(14)
                        color: Config.dndMode ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.18) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.35)
                        border.color: Config.dndMode ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.45) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.35)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: s(8)
                            Text {
                                text: Config.dndMode ? "󰂛" : "󰂚"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(18)
                                color: Config.dndMode ? mocha.red : mocha.subtext0
                            }
                            Text {
                                text: "Do Not Disturb"
                                font.family: "Outfit"
                                font.pixelSize: s(12)
                                font.weight: Font.DemiBold
                                color: Config.dndMode ? mocha.red : mocha.text
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.toggleDnd()
                        }
                    }

                    // Beautify Screenshot Toggle Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: s(52)
                        radius: s(14)
                        color: Config.beautifyScreenshot ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.18) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.35)
                        border.color: Config.beautifyScreenshot ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.45) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.35)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: s(8)
                            Text {
                                text: "󰃏"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(18)
                                color: Config.beautifyScreenshot ? mocha.yellow : mocha.subtext0
                            }
                            Text {
                                text: "Beauty Snap"
                                font.family: "Outfit"
                                font.pixelSize: s(12)
                                font.weight: Font.DemiBold
                                color: Config.beautifyScreenshot ? mocha.yellow : mocha.text
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

                // =============================================================
                // 3. Appearance Card (18 Theme Colors, Scheme Styles, Anim Speed)
                // =============================================================
                Rectangle {
                    Layout.fillWidth: true
                    height: appearanceCol.height + s(24)
                    radius: s(16)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.3)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                    border.width: 1

                    ColumnLayout {
                        id: appearanceCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(12)

                        // Section Title
                        RowLayout {
                            spacing: s(8)
                            Text {
                                text: "󰏘"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(15)
                                color: mocha.primary
                            }
                            Text {
                                text: "Theme & Aesthetics"
                                font.family: "Outfit"
                                font.pixelSize: s(13)
                                font.weight: Font.Bold
                                color: mocha.text
                            }

                            Item { Layout.fillWidth: true }

                            QsButton {
                                Layout.preferredWidth: s(104)
                                Layout.preferredHeight: s(22)
                                text: "Reset"
                                icon: "󰑮"
                                iconSize: 11
                                textSize: 10
                                textFont: "Outfit"
                                iconFont: "Iosevka Nerd Font"
                                radius: s(8)
                                baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.35)
                                hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.6)
                                textColor: mocha.text
                                iconColor: mocha.subtext0
                                ToolTip.visible: isHovered
                                ToolTip.text: "Use this wallpaper's own colors"
                                ToolTip.delay: 300
                                onClicked: {
                                    Config.activeHex = "";
                                    controlCenterRoot.applyingTheme = true;
                                    themeApplyFeedback.restart();
                                    Config.saveAppSettings();
                                    Quickshell.execDetached(["bash", "-c", Config.qsScriptsDir + "/wallpaper/matugen_apply.sh clear && " + Config.qsScriptsDir + "/wallpaper/matugen_reload.sh"]);
                                }
                            }

                            Text {
                                text: "󰇚"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(13)
                                color: mocha.primary
                                visible: controlCenterRoot.applyingTheme
                                RotationAnimation on rotation {
                                    from: 0; to: 360; duration: 700; loops: Animation.Infinite
                                    running: controlCenterRoot.applyingTheme
                                }
                            }
                            Text {
                                text: "Applying"
                                font.family: "Outfit"
                                font.pixelSize: s(10)
                                font.weight: Font.DemiBold
                                color: mocha.subtext0
                                visible: controlCenterRoot.applyingTheme
                            }
                        }

                        // Theme Swatches Grid (18 Colors)
                        GridLayout {
                            columns: 6
                            columnSpacing: s(10)
                            rowSpacing: s(10)
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter

                            Repeater {
                                model: [
                                    { hex: "#2563eb", name: "Electric Blue" },
                                    { hex: "#8b5cf6", name: "Purple Violet" },
                                    { hex: "#ec4899", name: "Hot Pink" },
                                    { hex: "#dc2626", name: "Crimson Red" },
                                    { hex: "#ea580c", name: "Sunset Orange" },
                                    { hex: "#d97706", name: "Amber Gold" },
                                    { hex: "#059669", name: "Emerald Green" },
                                    { hex: "#65a30d", name: "Lime Neon" },
                                    { hex: "#0d9488", name: "Mint Teal" },
                                    { hex: "#0891b2", name: "Cyan Aqua" },
                                    { hex: "#38bdf8", name: "Nordic Ice" },
                                    { hex: "#4f46e5", name: "Deep Indigo" },
                                    { hex: "#9333ea", name: "Neon Violet" },
                                    { hex: "#c026d3", name: "Fuchsia Pink" },
                                    { hex: "#f472b6", name: "Sakura" },
                                    { hex: "#94a3b8", name: "True Monochrome", scheme: "scheme-monochrome", forceHex: "#888888" },
                                    { hex: "#475569", name: "Slate Metallic" },
                                    { hex: "#fbbf24", name: "Bright Yellow" }
                                ]
                                delegate: Rectangle {
                                    property bool isHovered: cMa.containsMouse
                                    property bool isSelected: Config.activeHex === modelData.hex

                                    Layout.preferredWidth: s(36)
                                    Layout.preferredHeight: s(36)
                                    radius: s(18)
                                    color: modelData.hex
                                    border.width: isSelected ? 2 : 1
                                    border.color: isSelected ? mocha.text : (isHovered ? Qt.rgba(255, 255, 255, 0.8) : Qt.rgba(0, 0, 0, 0.25))

                                    scale: isHovered ? 1.15 : (isSelected ? 1.05 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                    ToolTip.visible: isHovered
                                    ToolTip.text: modelData.name
                                    ToolTip.delay: 250

                                    // Checkmark on the active swatch; dark/light pick depends on fill luminance
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰄲"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: s(15)
                                        font.weight: Font.Black
                                        opacity: isSelected ? 1.0 : 0.0
                                        scale: isSelected ? 1.0 : 0.3
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                        color: {
                                            let h = modelData.hex.replace("#", "");
                                            let r = parseInt(h.substr(0,2),16) / 255;
                                            let g = parseInt(h.substr(2,2),16) / 255;
                                            let b = parseInt(h.substr(4,2),16) / 255;
                                            return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? "black" : "white";
                                        }
                                    }

                                    MouseArea {
                                        id: cMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Config.activeHex = modelData.hex;
                                            controlCenterRoot.applyingTheme = true;
                                            themeApplyFeedback.restart();
                                            Config.saveAppSettings();
                                            let sc = modelData.scheme ? modelData.scheme : Config.selectedSchemeType;
                                            let hx = modelData.forceHex ? modelData.forceHex : modelData.hex;
                                            Quickshell.execDetached(["bash", "-c", "matugen color hex '" + hx + "' -t " + sc + " && " + Config.qsScriptsDir + "/wallpaper/matugen_apply.sh save '" + hx + "' '" + sc + "' && " + Config.qsScriptsDir + "/wallpaper/matugen_reload.sh"]);
                                        }
                                    }
                                }
                            }
                        }

                        // Divider Line
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                        }

                        // Scheme Style Selector Title
                        Text {
                            text: "Matugen Palette Algorithm"
                            font.family: "Outfit"
                            font.pixelSize: s(11)
                            font.weight: Font.DemiBold
                            color: mocha.subtext0
                        }

                        // Scheme Style Selector Tabs
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(6)

                            Repeater {
                                model: [
                                    { type: "scheme-tonal-spot", label: "Tonal" },
                                    { type: "scheme-vibrant", label: "Vibrant" },
                                    { type: "scheme-expressive", label: "Expressive" },
                                    { type: "scheme-fruit-salad", label: "Fruit" },
                                    { type: "scheme-monochrome", label: "Mono" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: s(28)
                                    radius: s(8)
                                    property bool isActive: Config.selectedSchemeType === modelData.type
                                    property bool isHovered: stMa.containsMouse

                                    color: isActive ? mocha.primary : (isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.5) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.25))
                                    border.width: 1
                                    border.color: isActive ? mocha.primary : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: "Outfit"
                                        font.pixelSize: s(11)
                                        font.weight: isActive ? Font.Bold : Font.Normal
                                        color: isActive ? mocha.base : mocha.text
                                    }

                                    MouseArea {
                                        id: stMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Config.selectedSchemeType = modelData.type;
                                            controlCenterRoot.applyingTheme = true;
                                            themeApplyFeedback.restart();
                                            Config.saveAppSettings();
                                            if (Config.activeHex === "") {
                                                Quickshell.execDetached(["bash", "-c", Config.qsScriptsDir + "/wallpaper/matugen_apply.sh scheme '" + modelData.type + "' && " + Config.qsScriptsDir + "/wallpaper/matugen_reload.sh"]);
                                            } else {
                                                Quickshell.execDetached(["bash", "-c", "matugen color hex '" + Config.activeHex + "' -t " + modelData.type + " && " + Config.qsScriptsDir + "/wallpaper/matugen_apply.sh save '" + Config.activeHex + "' '" + modelData.type + "' && " + Config.qsScriptsDir + "/wallpaper/matugen_reload.sh"]);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Animation Speed Controls
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(10)

                            Text {
                                text: "Animation Speed"
                                font.family: "Outfit"
                                font.pixelSize: s(11)
                                font.weight: Font.DemiBold
                                color: mocha.subtext0
                            }

                            QsSlider {
                                Layout.fillWidth: true
                                height: s(8)
                                from: 0.25; to: 2.0
                                value: Config.animSpeedMultiplier
                                activeColor: mocha.primary
                                trackColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.5)
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
                                font.pixelSize: s(11)
                                font.weight: Font.Bold
                                color: mocha.text
                                Layout.minimumWidth: s(36)
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // =============================================================
                // 4. Power Profile Card
                // =============================================================
                Rectangle {
                    Layout.fillWidth: true
                    height: powerCol.height + s(24)
                    radius: s(16)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.3)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                    border.width: 1

                    ColumnLayout {
                        id: powerCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(12)

                        RowLayout {
                            spacing: s(8)
                            Text {
                                text: "󰓅"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(15)
                                color: mocha.primary
                            }
                            Text {
                                text: "Power Management"
                                font.family: "Outfit"
                                font.pixelSize: s(13)
                                font.weight: Font.Bold
                                color: mocha.text
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(8)

                            Repeater {
                                model: [
                                    { key: "performance", label: "󰓅", title: "Perf", color1: "#f38ba8", color2: "#fab387" },
                                    { key: "balanced", label: "󰗑", title: "Balanced", color1: "#89b4fa", color2: "#74c7ec" },
                                    { key: "power-saver", label: "󰌪", title: "Saver", color1: "#a6e3a1", color2: "#94e2d5" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: s(46)
                                    radius: s(12)
                                    clip: true

                                    property bool isActive: Config.powerProfile === modelData.key
                                    property bool isHovered: ppMa.containsMouse

                                    color: isActive ? "transparent" : (isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.4) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.2))
                                    border.width: 1
                                    border.color: isActive ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.6) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: s(12)
                                        opacity: isActive ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: modelData.color1 }
                                            GradientStop { position: 1.0; color: modelData.color2 }
                                        }
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: s(6)
                                        Text {
                                            text: modelData.label
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: s(16)
                                            color: isActive ? mocha.base : mocha.text
                                        }
                                        Text {
                                            text: modelData.title
                                            font.family: "Outfit"
                                            font.pixelSize: s(11)
                                            font.weight: Font.Bold
                                            color: isActive ? mocha.base : mocha.text
                                        }
                                    }

                                    scale: isHovered ? 1.03 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

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

                        // Auto Power Switch Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(8)

                            Text {
                                text: "Auto Power Profile Switching"
                                font.family: "Outfit"
                                font.pixelSize: s(11)
                                font.weight: Font.Medium
                                color: mocha.subtext0
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: s(38); height: s(20); radius: s(10)
                                color: Config.autoPowerMode ? mocha.green : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    width: s(16); height: s(16); radius: s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Config.autoPowerMode ? s(20) : s(2)
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

                        // Auto Battery Saver (Display Hz & Animations) Switch Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(8)

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: "Auto Battery Saver"
                                    font.family: "Outfit"
                                    font.pixelSize: s(11)
                                    font.weight: Font.Medium
                                    color: mocha.text
                                }

                                Text {
                                    text: "Lower refresh rate (Hz), disable animations & brightness on battery"
                                    font.family: "Outfit"
                                    font.pixelSize: s(9)
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                width: s(38); height: s(20); radius: s(10)
                                color: Config.autoBatterySaver ? mocha.green : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    width: s(16); height: s(16); radius: s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Config.autoBatterySaver ? s(20) : s(2)
                                    color: mocha.base
                                    Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier); easing.type: Easing.OutExpo } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.autoBatterySaver = !Config.autoBatterySaver;
                                        saveTimer.restart();
                                    }
                                }
                            }
                        }

                        // Critical Battery Protection (suspend/shutdown on low battery)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(8)

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: "Critical Battery Protection"
                                    font.family: "Outfit"
                                    font.pixelSize: s(11)
                                    font.weight: Font.Medium
                                    color: mocha.text
                                }

                                Text {
                                    text: "Notify at 15%, auto suspend at 5% & shutdown at 2%"
                                    font.family: "Outfit"
                                    font.pixelSize: s(9)
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                width: s(38); height: s(20); radius: s(10)
                                color: Config.critProtect ? mocha.green : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    width: s(16); height: s(16); radius: s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Config.critProtect ? s(20) : s(2)
                                    color: mocha.base
                                    Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier); easing.type: Easing.OutExpo } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.critProtect = !Config.critProtect;
                                        saveTimer.restart();
                                    }
                                }
                            }
                        }

                        // Auto Bluetooth Off on Battery
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(8)

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: "Auto Turn Off Bluetooth"
                                    font.family: "Outfit"
                                    font.pixelSize: s(11)
                                    font.weight: Font.Medium
                                    color: mocha.text
                                }

                                Text {
                                    text: "Power off the Bluetooth radio when unplugged"
                                    font.family: "Outfit"
                                    font.pixelSize: s(9)
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                width: s(38); height: s(20); radius: s(10)
                                color: Config.bluetoothPowerSave ? mocha.green : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    width: s(16); height: s(16); radius: s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Config.bluetoothPowerSave ? s(20) : s(2)
                                    color: mocha.base
                                    Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier); easing.type: Easing.OutExpo } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.bluetoothPowerSave = !Config.bluetoothPowerSave;
                                        saveTimer.restart();
                                    }
                                }
                            }
                        }

                        // Turbo Boost Off on Battery
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: s(8)

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true

                                Text {
                                    text: "Turbo Boost Off on Battery"
                                    font.family: "Outfit"
                                    font.pixelSize: s(11)
                                    font.weight: Font.Medium
                                    color: mocha.text
                                }

                                Text {
                                    text: "Limit CPU turbo frequency while running on battery"
                                    font.family: "Outfit"
                                    font.pixelSize: s(9)
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                width: s(38); height: s(20); radius: s(10)
                                color: Config.boostPowerSave ? mocha.green : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    width: s(16); height: s(16); radius: s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Config.boostPowerSave ? s(20) : s(2)
                                    color: mocha.base
                                    Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier); easing.type: Easing.OutExpo } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.boostPowerSave = !Config.boostPowerSave;
                                        saveTimer.restart();
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // 5. TopBar Modules Section (Compact 2-Column Grid)
                // =============================================================
                Rectangle {
                    Layout.fillWidth: true
                    height: modulesCol.height + s(24)
                    radius: s(16)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.3)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                    border.width: 1

                    ColumnLayout {
                        id: modulesCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(10)

                        RowLayout {
                            spacing: s(8)
                            Text {
                                text: "󰍜"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(15)
                                color: mocha.primary
                            }
                            Text {
                                text: "TopBar Modules"
                                font.family: "Outfit"
                                font.pixelSize: s(13)
                                font.weight: Font.Bold
                                color: mocha.text
                            }
                        }

                        // 2-Column Grid Layout for Modules
                        GridLayout {
                            columns: 2
                            columnSpacing: s(10)
                            rowSpacing: s(8)
                            Layout.fillWidth: true

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
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: s(32)
                                    radius: s(8)
                                    color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.2)
                                    border.width: 1
                                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: s(8)
                                        anchors.rightMargin: s(8)
                                        spacing: s(6)

                                        Text {
                                            text: modelData.icon
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: s(13)
                                            color: Config.enabledModules[modelData.key] ? mocha.primary : mocha.subtext0
                                        }

                                        Text {
                                            text: modelData.label
                                            font.family: "Outfit"
                                            font.pixelSize: s(11)
                                            color: mocha.text
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            width: s(28); height: s(14); radius: s(7)
                                            color: Config.enabledModules[modelData.key] ? mocha.green : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
                                            Behavior on color { ColorAnimation { duration: 180 } }

                                            Rectangle {
                                                width: s(10); height: s(10); radius: s(5)
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: Config.enabledModules[modelData.key] ? s(15) : s(2)
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
                    }
                }

                // =============================================================
                // 6. Screen & Sleep Timeout Section
                // =============================================================
                Rectangle {
                    Layout.fillWidth: true
                    height: screenCol.height + s(24)
                    radius: s(16)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.3)
                    border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                    border.width: 1

                    ColumnLayout {
                        id: screenCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: s(14)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: s(10)

                        RowLayout {
                            spacing: s(8)
                            Text {
                                text: "󰤄"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(15)
                                color: mocha.primary
                            }
                            Text {
                                text: "Screen & Sleep Timeouts"
                                font.family: "Outfit"
                                font.pixelSize: s(13)
                                font.weight: Font.Bold
                                color: mocha.text
                            }
                        }

                        Repeater {
                            model: [
                                { label: "Lock Screen", color: mocha.mauve, prop: "idleLockTimeout", def: 10 },
                                { label: "Screen Off", color: mocha.blue, prop: "idleScreenOffTimeout", def: 5 },
                                { label: "Sleep", color: mocha.green, prop: "idleSleepTimeout", def: 60 }
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: s(8)

                                property int curVal: (Config[modelData.prop] !== undefined) ? Config[modelData.prop] : modelData.def

                                Text {
                                    text: modelData.label
                                    font.family: "Outfit"
                                    font.pixelSize: s(11)
                                    font.weight: Font.Medium
                                    color: mocha.text
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: curVal === 0 ? "Never" : curVal + "m"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: s(11)
                                    font.weight: Font.Bold
                                    color: modelData.color
                                    Layout.minimumWidth: s(44)
                                    horizontalAlignment: Text.AlignRight
                                }

                                QsButton {
                                    Layout.preferredWidth: s(28)
                                    Layout.preferredHeight: s(22)
                                    text: "-"
                                    textFont: "Outfit"
                                    textSize: 12
                                    baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                                    hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.6)
                                    textColor: mocha.text
                                    onClicked: {
                                        let val = Math.max(0, curVal - 5);
                                        if (Config[modelData.prop] !== val) {
                                            Config[modelData.prop] = val;
                                            saveTimer.restart();
                                        }
                                    }
                                }

                                QsButton {
                                    Layout.preferredWidth: s(28)
                                    Layout.preferredHeight: s(22)
                                    text: "+"
                                    textFont: "Outfit"
                                    textSize: 12
                                    baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                                    hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.6)
                                    textColor: mocha.text
                                    onClicked: {
                                        let val = Math.min(180, curVal + 5);
                                        if (Config[modelData.prop] !== val) {
                                            Config[modelData.prop] = val;
                                            saveTimer.restart();
                                        }
                                    }
                                }

                                QsButton {
                                    Layout.preferredWidth: s(36)
                                    Layout.preferredHeight: s(22)
                                    text: "Def"
                                    textFont: "Outfit"
                                    textSize: 10
                                    baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
                                    hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.5)
                                    textColor: mocha.subtext0
                                    onClicked: {
                                        if (Config[modelData.prop] !== modelData.def) {
                                            Config[modelData.prop] = modelData.def;
                                            saveTimer.restart();
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
