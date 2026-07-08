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

    // Background
    Rectangle {
        anchors.fill: parent
        radius: s(24)
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.85)
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
        spacing: s(20)

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Control Center"
                font.family: "Outfit"
                font.pixelSize: s(26)
                font.weight: Font.Bold
                color: mocha.text
                Layout.fillWidth: true
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: scrollContent.height
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                active: true
                width: s(4)
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: s(4); radius: s(2); color: mocha.surface2 }
            }

            ColumnLayout {
                id: scrollContent
                width: parent.width
                spacing: s(15)

        // Section: Appearance (Theme & Color)
        Text { 
            text: "Appearance"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        GridLayout {
            columns: 6
            columnSpacing: s(10)
            rowSpacing: s(10)

            Repeater {
                model: [
                    { name: "Blue", hex: "#89b4fa" },
                    { name: "Mauve", hex: "#cba6f7" },
                    { name: "Peach", hex: "#fab387" },
                    { name: "Green", hex: "#a6e3a1" },
                    { name: "Red", hex: "#f38ba8" },
                    { name: "Teal", hex: "#94e2d5" }
                ]
                delegate: Rectangle {
                    width: s(46); height: s(46); radius: s(23)
                    color: modelData.hex
                    border.width: s(2)
                    border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1)
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: s(2)
                        border.color: mocha.base
                        visible: false // Could be tied to active color later
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "matugen color hex '" + modelData.hex + "' && " + Config.qsScriptsDir + "/wallpaper/matugen_reload.sh"]);
                        }
                    }
                }
            }
        }

        // Section: Animation Speed
        Text { 
            text: "Animation Speed"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: s(15)
            
            QsSlider {
                Layout.fillWidth: true
                height: s(12)
                from: 0.25
                to: 2.0
                value: Config.animSpeedMultiplier
                activeColor: mocha.mauve
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
                font.pixelSize: s(14)
                font.weight: Font.Bold
                color: mocha.text
                Layout.minimumWidth: s(45)
            }
        }

        // Section: Modules
        Text { 
            text: "TopBar Modules"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        GridLayout {
            columns: 2
            columnSpacing: s(12)
            rowSpacing: s(12)
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
                    height: s(50)
                    radius: s(12)
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: s(12)
                        spacing: s(10)
                        
                        Text {
                            text: modelData.icon
                            font.family: "Nerd Font Mono"
                            font.pixelSize: s(16)
                            color: Config.enabledModules[modelData.key] ? mocha.blue : mocha.subtext0
                        }
                        
                        Text {
                            text: modelData.label
                            font.family: "Outfit"
                            font.pixelSize: s(14)
                            color: mocha.text
                            Layout.fillWidth: true
                        }
                        
                        Rectangle {
                            width: s(40); height: s(22); radius: s(11)
                            color: Config.enabledModules[modelData.key] ? mocha.green : mocha.surface1
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Rectangle {
                                width: s(18); height: s(18); radius: s(9)
                                anchors.verticalCenter: parent.verticalCenter
                                x: Config.enabledModules[modelData.key] ? s(20) : s(2)
                                color: mocha.base
                                Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier) } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    let mods = Object.assign({}, Config.enabledModules);
                                    if (mods[modelData.key] === undefined) {
                                        mods[modelData.key] = false;
                                    } else {
                                        mods[modelData.key] = !mods[modelData.key];
                                    }
                                    Config.enabledModules = mods;
                                    saveTimer.restart();
                                }
                            }
                        }
                    }
                }
            }
        }

        // Section: Do Not Disturb
        Text { 
            text: "Do Not Disturb"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        Rectangle {
            Layout.fillWidth: true
            height: s(70)
            radius: s(16)
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

            RowLayout {
                anchors.fill: parent
                anchors.margins: s(12)
                spacing: s(10)

                Text {
                    text: Config.dndMode ? "󰂛" : "󰂚"
                    font.family: "Nerd Font Mono"
                    font.pixelSize: s(20)
                    color: Config.dndMode ? mocha.red : mocha.subtext0
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    Text {
                        text: "Do Not Disturb"
                        font.family: "Outfit"
                        font.pixelSize: s(14)
                        font.weight: Font.Bold
                        color: mocha.text
                    }

                    Text {
                        text: "Silence all notifications"
                        font.family: "Outfit"
                        font.pixelSize: s(11)
                        color: mocha.subtext1
                    }
                }

                Rectangle {
                    width: s(40); height: s(22); radius: s(11)
                    color: Config.dndMode ? mocha.red : mocha.surface1
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: s(18); height: s(18); radius: s(9)
                        anchors.verticalCenter: parent.verticalCenter
                        x: Config.dndMode ? s(20) : s(2)
                        color: mocha.base
                        Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier) } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.toggleDnd();
                        }
                    }
                }
            }
        }

        // Section: Power Profile
        Text { 
            text: "Power Profile"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: s(8)

            Repeater {
                model: [
                    { key: "performance", label: "󰓅 Perf", color1: "#f38ba8", color2: "#fab387" },
                    { key: "balanced", label: "󰗑 Balanced", color1: "#89b4fa", color2: "#74c7ec" },
                    { key: "power-saver", label: "󰌪 Saver", color1: "#a6e3a1", color2: "#94e2d5" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: s(44)
                    radius: s(12)
                    clip: true

                    property bool isActive: Config.powerProfile === modelData.key
                    property bool isHovered: ppMa.containsMouse

                    color: isActive ? "transparent" : (isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.5) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5))
                    border.width: 1
                    border.color: isActive ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: s(12)
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
                        font.family: "Outfit"
                        font.pixelSize: s(13)
                        font.weight: isActive ? Font.Bold : Font.DemiBold
                        color: isActive ? mocha.base : mocha.text
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    scale: isHovered ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

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

        // Section: System Automation
        Text { 
            text: "System Automation"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        Rectangle {
            Layout.fillWidth: true
            height: s(185)
            radius: s(16)
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: s(12)
                spacing: s(6)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    Text {
                        text: {
                            if (!Config.autoPowerMode) return "󰒓";
                            let cpu = SysData.cpu;
                            let temp = SysData.temp;
                            if (cpu >= 80 || temp >= 75) return "󰓅"; 
                            if (cpu <= 15 && temp <= 55) return "󰌪"; 
                            return "󰗑"; 
                        }
                        font.family: "Nerd Font Mono"
                        font.pixelSize: s(20)
                        color: {
                            if (!Config.autoPowerMode) return mocha.subtext0;
                            let cpu = SysData.cpu;
                            let temp = SysData.temp;
                            if (cpu >= 80 || temp >= 75) return mocha.red;
                            if (cpu <= 15 && temp <= 55) return mocha.green;
                            return mocha.blue;
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        Text {
                            text: "Auto Power Profiles"
                            font.family: "Outfit"
                            font.pixelSize: s(14)
                            font.weight: Font.Bold
                            color: mocha.text
                        }

                        Text {
                            text: "Scale profiles by CPU & Temp"
                            font.family: "Outfit"
                            font.pixelSize: s(11)
                            color: mocha.subtext1
                        }
                    }

                    Rectangle {
                        width: s(40); height: s(22); radius: s(11)
                        color: Config.autoPowerMode ? mocha.green : mocha.surface1
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: s(18); height: s(18); radius: s(9)
                            anchors.verticalCenter: parent.verticalCenter
                            x: Config.autoPowerMode ? s(20) : s(2)
                            color: mocha.base
                            Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier) } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.autoPowerMode = !Config.autoPowerMode;
                                saveTimer.restart();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    Text {
                        text: Config.autoPowerNotify ? "󰂚" : "󰂛"
                        font.family: "Nerd Font Mono"
                        font.pixelSize: s(18)
                        color: Config.autoPowerNotify ? mocha.blue : mocha.subtext0
                    }

                    Text {
                        text: "Show notifications on profile change"
                        font.family: "Outfit"
                        font.pixelSize: s(12)
                        color: mocha.text
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: s(40); height: s(22); radius: s(11)
                        color: Config.autoPowerNotify ? mocha.green : mocha.surface1
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: s(18); height: s(18); radius: s(9)
                            anchors.verticalCenter: parent.verticalCenter
                            x: Config.autoPowerNotify ? s(20) : s(2)
                            color: mocha.base
                            Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier) } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.autoPowerNotify = !Config.autoPowerNotify;
                                saveTimer.restart();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    Text {
                        text: "󰌪"
                        font.family: "Nerd Font Mono"
                        font.pixelSize: s(18)
                        color: Config.autoBatterySaver ? mocha.green : mocha.subtext0
                    }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        Text {
                            text: "Auto Battery Saver"
                            font.family: "Outfit"
                            font.pixelSize: s(14)
                            font.weight: Font.Bold
                            color: mocha.text
                        }

                        Text {
                            text: "Optimize settings when charger is unplugged"
                            font.family: "Outfit"
                            font.pixelSize: s(11)
                            color: mocha.subtext1
                        }
                    }

                    Rectangle {
                        width: s(40); height: s(22); radius: s(11)
                        color: Config.autoBatterySaver ? mocha.green : mocha.surface1
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: s(18); height: s(18); radius: s(9)
                            anchors.verticalCenter: parent.verticalCenter
                            x: Config.autoBatterySaver ? s(20) : s(2)
                            color: mocha.base
                            Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier) } }
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: s(2)

                    Text {
                        text: "Status: " + (Config.autoPowerMode ? "Active" : "Disabled")
                        font.family: "Outfit"
                        font.pixelSize: s(11)
                        font.weight: Font.DemiBold
                        color: Config.autoPowerMode ? mocha.green : mocha.subtext0
                    }

                    Item { Layout.fillWidth: true } 

                    Text {
                        text: "CPU: " + SysData.cpu + "%  •  Temp: " + SysData.temp + "°C"
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(11)
                        font.weight: Font.Bold
                        color: mocha.subtext1
                    }
                }
            }
        }

        // Section: Screen & Sleep Timeout
        Text { 
            text: "Screen & Sleep Timeout"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        Rectangle {
            Layout.fillWidth: true
            height: s(165)
            radius: s(16)
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: s(12)
                spacing: s(10)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    ColumnLayout {
                        spacing: s(2)
                        Layout.fillWidth: true

                        Text {
                            text: "Lock Screen"
                            font.family: "Outfit"
                            font.pixelSize: s(13)
                            font.weight: Font.DemiBold
                            color: mocha.text
                        }

                        Text {
                            text: Config.idleLockTimeout === 0 ? "Never" : Config.idleLockTimeout + "m"
                            font.family: "JetBrains Mono"
                            font.pixelSize: s(12)
                            font.weight: Font.Bold
                            color: mocha.mauve
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(50)
                        Layout.preferredHeight: s(28)
                        text: "-5m"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.text
                        onClicked: {
                            let val = Math.max(0, Config.idleLockTimeout - 5);
                            if (Config.idleLockTimeout !== val) {
                                Config.idleLockTimeout = val;
                                saveTimer.restart();
                            }
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(50)
                        Layout.preferredHeight: s(28)
                        text: "+5m"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.text
                        onClicked: {
                            let val = Math.min(180, Config.idleLockTimeout + 5);
                            if (Config.idleLockTimeout !== val) {
                                Config.idleLockTimeout = val;
                                saveTimer.restart();
                            }
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(65)
                        Layout.preferredHeight: s(28)
                        text: "Default"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.subtext1
                        onClicked: {
                            if (Config.idleLockTimeout !== 10) {
                                Config.idleLockTimeout = 10;
                                saveTimer.restart();
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    ColumnLayout {
                        spacing: s(2)
                        Layout.fillWidth: true

                        Text {
                            text: "Screen Off"
                            font.family: "Outfit"
                            font.pixelSize: s(13)
                            font.weight: Font.DemiBold
                            color: mocha.text
                        }

                        Text {
                            text: Config.idleScreenOffTimeout === 0 ? "Never" : Config.idleScreenOffTimeout + "m"
                            font.family: "JetBrains Mono"
                            font.pixelSize: s(12)
                            font.weight: Font.Bold
                            color: mocha.blue
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(50)
                        Layout.preferredHeight: s(28)
                        text: "-5m"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.text
                        onClicked: {
                            let val = Math.max(0, Config.idleScreenOffTimeout - 5);
                            if (Config.idleScreenOffTimeout !== val) {
                                Config.idleScreenOffTimeout = val;
                                saveTimer.restart();
                            }
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(50)
                        Layout.preferredHeight: s(28)
                        text: "+5m"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.text
                        onClicked: {
                            let val = Math.min(180, Config.idleScreenOffTimeout + 5);
                            if (Config.idleScreenOffTimeout !== val) {
                                Config.idleScreenOffTimeout = val;
                                saveTimer.restart();
                            }
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(65)
                        Layout.preferredHeight: s(28)
                        text: "Default"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.subtext1
                        onClicked: {
                            if (Config.idleScreenOffTimeout !== 5) {
                                Config.idleScreenOffTimeout = 5;
                                saveTimer.restart();
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    ColumnLayout {
                        spacing: s(2)
                        Layout.fillWidth: true

                        Text {
                            text: "Sleep/Suspend"
                            font.family: "Outfit"
                            font.pixelSize: s(13)
                            font.weight: Font.DemiBold
                            color: mocha.text
                        }

                        Text {
                            text: Config.idleSleepTimeout === 0 ? "Never" : Config.idleSleepTimeout + "m"
                            font.family: "JetBrains Mono"
                            font.pixelSize: s(12)
                            font.weight: Font.Bold
                            color: mocha.green
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(50)
                        Layout.preferredHeight: s(28)
                        text: "-5m"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.text
                        onClicked: {
                            let val = Math.max(0, Config.idleSleepTimeout - 5);
                            if (Config.idleSleepTimeout !== val) {
                                Config.idleSleepTimeout = val;
                                saveTimer.restart();
                            }
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(50)
                        Layout.preferredHeight: s(28)
                        text: "+5m"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.text
                        onClicked: {
                            let val = Math.min(180, Config.idleSleepTimeout + 5);
                            if (Config.idleSleepTimeout !== val) {
                                Config.idleSleepTimeout = val;
                                saveTimer.restart();
                            }
                        }
                    }

                    QsButton {
                        Layout.preferredWidth: s(65)
                        Layout.preferredHeight: s(28)
                        text: "Default"
                        textFont: "Outfit"
                        baseColor: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                        hoverColor: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.7)
                        textColor: mocha.subtext1
                        onClicked: {
                            if (Config.idleSleepTimeout !== 60) {
                                Config.idleSleepTimeout = 60;
                                saveTimer.restart();
                            }
                        }
                    }
                }
            }
        }

        // Section: Screenshot
        Text { 
            text: "Screenshot"
            font.family: "Outfit"
            font.pixelSize: s(16)
            color: mocha.subtext0
            font.weight: Font.DemiBold
            Layout.topMargin: s(10)
        }

        Rectangle {
            Layout.fillWidth: true
            height: s(85)
            radius: s(16)
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: s(12)
                spacing: s(6)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: s(10)

                    Text {
                        text: "󰃏"
                        font.family: "Nerd Font Mono"
                        font.pixelSize: s(20)
                        color: Config.beautifyScreenshot ? mocha.yellow : mocha.subtext0
                    }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        Text {
                            text: "Beautyshot"
                            font.family: "Outfit"
                            font.pixelSize: s(14)
                            font.weight: Font.Bold
                            color: mocha.text
                        }

                        Text {
                            text: "Decorate screenshots with shadows and rounded corners"
                            font.family: "Outfit"
                            font.pixelSize: s(11)
                            color: mocha.subtext1
                        }
                    }

                    Rectangle {
                        width: s(40); height: s(22); radius: s(11)
                        color: Config.beautifyScreenshot ? mocha.green : mocha.surface1
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: s(18); height: s(18); radius: s(9)
                            anchors.verticalCenter: parent.verticalCenter
                            x: Config.beautifyScreenshot ? s(20) : s(2)
                            color: mocha.base
                            Behavior on x { NumberAnimation { duration: Math.round(150 / Config.animSpeedMultiplier) } }
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: s(2)

                    Text {
                        text: "Status: " + (Config.beautifyScreenshot ? "Active" : "Disabled")
                        font.family: "Outfit"
                        font.pixelSize: s(11)
                        font.weight: Font.DemiBold
                        color: Config.beautifyScreenshot ? mocha.green : mocha.subtext0
                    }
                }
            }
        }

        Item { Layout.fillHeight: true } // Spacer
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: Config.applyControlCenterSettings()
    }
}
