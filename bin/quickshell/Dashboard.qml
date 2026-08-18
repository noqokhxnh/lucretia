import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "WindowRegistry.js" as Registry

Item {
    id: dashboardRoot

    property real layoutWidth: 1200
    property real layoutHeight: 800

    function s(val) {
        return Math.round(val * (layoutWidth / 1200.0));
    }

    MatugenColors {
        id: mocha
    }

    // --- Ambient orbit animation ---
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    property real introHeader: 0
    property real introTopSection: 0
    property real introBottomSection: 0

    ParallelAnimation {
        running: true
        NumberAnimation { target: dashboardRoot; property: "introHeader"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: dashboardRoot; property: "introTopSection"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
        }
        SequentialAnimation {
            PauseAnimation { duration: 300 }
            NumberAnimation { target: dashboardRoot; property: "introBottomSection"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutExpo }
        }
    }

    Component.onCompleted: {
        SysData.subscribe();
        updateCalendarGrid();
    }

    Component.onDestruction: {
        SysData.unsubscribe();
    }

    property var currentTime: new Date()

    property var cpuHistory: []
    property var ramHistory: []
    property var netHistory: []

    function pushHistory(arr, val) {
        let copy = arr.slice();
        copy.push(val);
        if (copy.length > 30) copy.shift();
        return copy;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            dashboardRoot.currentTime = new Date();
            if (dashboardRoot.currentTime.getHours() === 0 && dashboardRoot.currentTime.getMinutes() === 0) {
                updateCalendarGrid();
            }
            dashboardRoot.cpuHistory = dashboardRoot.pushHistory(dashboardRoot.cpuHistory, SysData.cpu);
            dashboardRoot.ramHistory = dashboardRoot.pushHistory(dashboardRoot.ramHistory, SysData.ramPercent);
            dashboardRoot.netHistory = dashboardRoot.pushHistory(dashboardRoot.netHistory, Math.min(100, (SysData.netRx + SysData.netTx) / 10485.76));
        }
    }

    // =========================================================
    // --- BACKGROUND & CONTAINER
    // =========================================================
    Rectangle {
        anchors.fill: parent
        radius: s(20)
        color: mocha.base
        border.color: mocha.surface0
        border.width: 1
        clip: true

        // Ambient color blobs
        Rectangle {
            width: parent.width * 0.5; height: width; radius: width / 2
            x: (parent.width * 0.75 - width / 2) + Math.cos(dashboardRoot.globalOrbitAngle * 1.5) * s(150)
            y: (parent.height * 0.3 - height / 2) + Math.sin(dashboardRoot.globalOrbitAngle * 1.5) * s(100)
            opacity: 0.025
            color: mocha.mauve
        }
        Rectangle {
            width: parent.width * 0.6; height: width; radius: width / 2
            x: (parent.width * 0.25 - width / 2) + Math.sin(dashboardRoot.globalOrbitAngle * 1.2) * s(-150)
            y: (parent.height * 0.7 - height / 2) + Math.cos(dashboardRoot.globalOrbitAngle * 1.2) * s(-120)
            opacity: 0.02
            color: mocha.blue
        }
        Rectangle {
            width: parent.width * 0.45; height: width; radius: width / 2
            x: (parent.width * 0.5 - width / 2) + Math.cos(dashboardRoot.globalOrbitAngle * -1.8) * s(180)
            y: (parent.height * 0.5 - height / 2) + Math.sin(dashboardRoot.globalOrbitAngle * -1.8) * s(-150)
            opacity: 0.015
            color: mocha.teal
        }
    }

    // =========================================================
    // --- MAIN CONTENT LAYOUT
    // =========================================================
    Item {
        anchors.fill: parent
        anchors.margins: s(24)

        // --- HEADER ---
        Item {
            id: headerSection
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: s(60)
            opacity: dashboardRoot.introHeader
            transform: Translate { y: (1 - dashboardRoot.introHeader) * s(20) }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: s(2)
                Text {
                    text: "Welcome back, " + Quickshell.env("USER")
                    font.family: "Outfit"
                    font.pixelSize: s(32)
                    font.weight: Font.Bold
                    color: mocha.text
                }
                Text {
                    text: Qt.formatDateTime(dashboardRoot.currentTime, "dddd, MMMM dd")
                    font.family: "Outfit"
                    font.pixelSize: s(14)
                    font.weight: Font.Medium
                    color: mocha.subtext0
                }
            }
        }

        // --- TOP SECTION: STATS & APPS ---
        Item {
            id: topSection
            anchors.top: headerSection.bottom
            anchors.topMargin: s(20)
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height - s(60) - s(40)) * 0.5
            opacity: dashboardRoot.introTopSection
            transform: Translate { y: (1 - dashboardRoot.introTopSection) * s(20) }

            // LEFT: SYSTEM MONITOR
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: s(400)
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.2)
                radius: s(16)
                border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: s(20)
                    spacing: s(10)

                    Text {
                        text: "System Health"
                        font.family: "Outfit"
                        font.pixelSize: s(16)
                        font.weight: Font.Bold
                        color: mocha.subtext0
                    }

                    GridLayout {
                        columns: 2
                        rowSpacing: s(10)
                        columnSpacing: s(10)
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StatCard {
                            title: "CPU"
                            statValue: SysData.cpu + "%"
                            statIcon: "󰻠"
                            accentColor: mocha.mauve
                            history: dashboardRoot.cpuHistory
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                        StatCard {
                            title: "RAM"
                            statValue: SysData.ramPercent + "%"
                            statIcon: "󰍛"
                            accentColor: mocha.blue
                            history: dashboardRoot.ramHistory
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                        StatCard {
                            title: "TEMP"
                            statValue: SysData.temp + "°C"
                            statIcon: "󰔄"
                            accentColor: mocha.red
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                        StatCard {
                            title: "NET"
                            statValue: dashboardRoot.formatNet(SysData.netRx + SysData.netTx)
                            statIcon: "󰖩"
                            accentColor: mocha.teal
                            history: dashboardRoot.netHistory
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }
                }
            }

            // RIGHT: APP GRID
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: s(420)
                anchors.right: parent.right
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.2)
                radius: s(16)
                border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: s(20)
                    spacing: s(15)

                    Text {
                        text: "Quickshell Widgets"
                        font.family: "Outfit"
                        font.pixelSize: s(16)
                        font.weight: Font.Bold
                        color: mocha.subtext0
                    }

                    GridView {
                        id: appGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cellWidth: s(160)
                        cellHeight: s(90)
                        clip: true

                        model: ListModel {
                            ListElement { name: "Control Center"; icon: "󰒓"; target: "controlcenter"; colorKey: "blue" }
                            ListElement { name: "Clipboard"; icon: "󰅌"; target: "clipboard"; colorKey: "peach" }
                            ListElement { name: "Monitors"; icon: "󰍹"; target: "monitors"; colorKey: "green" }
                            ListElement { name: "Focus Time"; icon: "󱎫"; target: "focustime"; colorKey: "mauve" }
                            ListElement { name: "Network"; icon: "󰖩"; target: "network"; colorKey: "sapphire" }
                            ListElement { name: "Volume"; icon: "󰕾"; target: "volume"; colorKey: "yellow" }
                            ListElement { name: "Updater"; icon: "󰚰"; target: "updater"; colorKey: "teal" }
                            ListElement { name: "Wallpaper"; icon: "󰸉"; target: "wallpaper"; colorKey: "pink" }
                        }

                        delegate: AppButton {
                            width: s(140)
                            height: s(80)
                            appName: model.name
                            appIcon: model.icon
                            appColor: {
                                // Some theme roles (e.g. monochrome) resolve to dark tones that
                                // vanish on the dark card — keep bright roles, lighten dark ones.
                                let c = mocha[model.colorKey];
                                return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.4 ? Qt.lighter(c, 1.9) : c;
                            }
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "~/.config/niri/bin/qs_manager.sh toggle " + model.target]);
                            }
                        }
                    }
                }
            }
        }

        // --- BOTTOM SECTION: LARGE CLOCK & CALENDAR ---
        Item {
            anchors.top: topSection.bottom
            anchors.topMargin: s(20)
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            opacity: dashboardRoot.introBottomSection
            transform: Translate { y: (1 - dashboardRoot.introBottomSection) * s(20) }

            // LARGE CLOCK
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: s(380)
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.2)
                radius: s(16)
                border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        text: Qt.formatTime(dashboardRoot.currentTime, "HH:mm")
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(140)
                        font.weight: Font.Black
                        color: mocha.text
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: Qt.formatDateTime(dashboardRoot.currentTime, "dddd, MMMM dd, yyyy")
                        font.family: "Outfit"
                        font.pixelSize: s(20)
                        font.weight: Font.Medium
                        color: mocha.subtext0
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: s(4)
                    }
                }
            }

            // MINI CALENDAR
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: s(360)
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.2)
                radius: s(16)
                border.color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: s(16)
                    spacing: s(10)

                    Text {
                        text: Qt.formatDateTime(dashboardRoot.currentTime, "MMMM yyyy").toUpperCase()
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(14)
                        font.weight: Font.Black
                        color: mocha.text
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Day headers
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(11)
                                font.weight: Font.Black
                                color: mocha.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Calendar grid
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        columnSpacing: s(4)
                        rowSpacing: s(4)

                        Repeater {
                            model: calendarModel
                            delegate: Rectangle {
                                id: calDayCell
                                property bool isHovered: calDayMa.containsMouse
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: s(6)
                                color: isToday ? mocha.text : (isHovered && isCurrentMonth ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.3) : "transparent")

                                scale: isHovered && isCurrentMonth ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: "JetBrains Mono"
                                    font.weight: isToday ? Font.Black : Font.Bold
                                    font.pixelSize: s(12)
                                    color: isToday ? mocha.base : (isCurrentMonth ? mocha.text : mocha.surface0)
                                }

                                MouseArea {
                                    id: calDayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // --- CALENDAR LOGIC ---
    // =========================================================
    ListModel {
        id: calendarModel
    }

    function updateCalendarGrid() {
        let d = new Date(dashboardRoot.currentTime.getTime());
        d.setDate(1);
        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let todayDate = actualToday.getDate();

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();
        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    function formatNet(bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " K";
        return (bytes / 1048576).toFixed(1) + " M";
    }

    // =========================================================
    // --- INTERNAL COMPONENTS ---
    // =========================================================

    component StatCard: Rectangle {
        id: statCardRoot
        property string title: ""
        property string statValue: ""
        property string statIcon: ""
        property color accentColor: mocha.primary
        property var history: []
        property bool isHovered: false
        width: dashboardRoot.s(170)
        height: dashboardRoot.s(80)
        radius: dashboardRoot.s(12)
        color: isHovered ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.3) : "transparent"
        border.color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.5) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.25)
        border.width: 1
        clip: true

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        scale: isHovered ? 1.02 : 1.0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onContainsMouseChanged: statCardRoot.isHovered = containsMouse
        }

        // Sparkline
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.4
            spacing: 1
            visible: history.length > 0

            Repeater {
                model: history.length
                delegate: Rectangle {
                    property real val: index < history.length ? history[index] : 0
                    width: (parent.width - (history.length - 1)) / Math.max(1, history.length)
                    anchors.bottom: parent.bottom
                    height: Math.max(1, (val / 100.0) * parent.height)
                    radius: 1
                    color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08 + (index / Math.max(1, history.length - 1)) * 0.15)

                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: dashboardRoot.s(12)
            spacing: dashboardRoot.s(10)

            Text {
                text: statIcon
                font.family: "Nerd Font Mono"
                font.pixelSize: dashboardRoot.s(22)
                color: accentColor
            }
            Column {
                Text {
                    text: title
                    font.family: "Outfit"
                    font.pixelSize: dashboardRoot.s(11)
                    color: mocha.overlay1
                }
                Text {
                    text: statValue
                    font.family: "JetBrains Mono"
                    font.pixelSize: dashboardRoot.s(18)
                    font.weight: Font.Bold
                    color: mocha.text
                }
            }
        }
    }

    component AppButton: MouseArea {
        id: ma
        property string appName: ""
        property string appIcon: ""
        property color appColor: "#89b4fa"
        hoverEnabled: true

        Rectangle {
            anchors.fill: parent
            radius: dashboardRoot.s(12)
            color: ma.containsMouse ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.3) : "transparent"
            border.color: ma.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4) : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            scale: ma.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: dashboardRoot.s(6)

                Text {
                    text: ma.appIcon
                    Layout.alignment: Qt.AlignHCenter
                    font.family: "Nerd Font Mono"
                    font.pixelSize: dashboardRoot.s(28)
                    color: ma.appColor
                }
                Text {
                    text: ma.appName
                    Layout.alignment: Qt.AlignHCenter
                    font.family: "Outfit"
                    font.pixelSize: dashboardRoot.s(13)
                    color: ma.containsMouse ? mocha.text : mocha.overlay1
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }
}
