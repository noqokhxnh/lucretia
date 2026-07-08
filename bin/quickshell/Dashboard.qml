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
    
    // Scaling helper
    function s(val) {
        return Math.round(val * (layoutWidth / 1200.0));
    }

    MatugenColors { id: mocha }

    Component.onCompleted: {
        SysData.subscribe();
        updateCalendarGrid();
    }
    
    Component.onDestruction: {
        SysData.unsubscribe();
    }

    property var currentTime: new Date()

    // History arrays for sparkline graphs (30 samples)
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
        interval: 1000; running: true; repeat: true
        onTriggered: {
            dashboardRoot.currentTime = new Date();
            if (dashboardRoot.currentTime.getHours() === 0 && dashboardRoot.currentTime.getMinutes() === 0) {
                updateCalendarGrid();
            }
            // Push system data to history
            dashboardRoot.cpuHistory = dashboardRoot.pushHistory(dashboardRoot.cpuHistory, SysData.cpu);
            dashboardRoot.ramHistory = dashboardRoot.pushHistory(dashboardRoot.ramHistory, SysData.ramPercent);
            dashboardRoot.netHistory = dashboardRoot.pushHistory(dashboardRoot.netHistory, Math.min(100, (SysData.netRx + SysData.netTx) / 10485.76)); // normalize to 0-100
        }
    }

    // =========================================================
    // --- BACKGROUND & CONTAINER
    // =========================================================
    Rectangle {
        anchors.fill: parent
        radius: s(24)
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.85)
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1)
        
        // Glass effect
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.05)
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

            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "Welcome back, " + Quickshell.env("USER")
                    font.family: "Outfit"; font.pixelSize: s(32); font.weight: Font.Bold
                    color: mocha.text
                }
                Text {
                    text: "Control Center • System Overview"
                    font.family: "Outfit"; font.pixelSize: s(16)
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
            height: (parent.height - s(60) - s(40)) * 0.45 // 45% of remaining height

            // LEFT: SYSTEM MONITOR
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: s(400)
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                radius: s(20)
                border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: s(20)
                    spacing: s(10)

                    Text {
                        text: "System Health"
                        font.family: "Outfit"; font.pixelSize: s(18); font.weight: Font.Bold
                        color: mocha.subtext1
                    }

                    GridLayout {
                        columns: 2
                        rowSpacing: s(12); columnSpacing: s(12)
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StatCard { title: "CPU"; statValue: SysData.cpu + "%"; statIcon: "󰻠"; accentColor: mocha.mauve; history: dashboardRoot.cpuHistory; Layout.fillWidth: true; Layout.fillHeight: true }
                        StatCard { title: "RAM"; statValue: SysData.ramPercent + "%"; statIcon: "󰍛"; accentColor: mocha.blue; history: dashboardRoot.ramHistory; Layout.fillWidth: true; Layout.fillHeight: true }
                        StatCard { title: "TEMP"; statValue: SysData.temp + "°C"; statIcon: "󰔄"; accentColor: mocha.red; Layout.fillWidth: true; Layout.fillHeight: true }
                        StatCard { title: "NET"; statValue: dashboardRoot.formatNet(SysData.netRx + SysData.netTx); statIcon: "󰖩"; accentColor: mocha.teal; history: dashboardRoot.netHistory; Layout.fillWidth: true; Layout.fillHeight: true }
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
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                radius: s(20)
                border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: s(20)
                    spacing: s(15)

                    Text {
                        text: "Quickshell Widgets"
                        font.family: "Outfit"; font.pixelSize: s(18); font.weight: Font.Bold
                        color: mocha.subtext1
                    }

                    GridView {
                        id: appGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cellWidth: s(160); cellHeight: s(90)
                        clip: true

                        model: ListModel {
                            ListElement { name: "Control Center"; icon: "󰒓"; target: "controlcenter"; btnColor: "#89b4fa" }
                            ListElement { name: "Clipboard"; icon: "󰅌"; target: "clipboard"; btnColor: "#fab387" }
                            ListElement { name: "Monitors"; icon: "󰍹"; target: "monitors"; btnColor: "#a6e3a1" }
                            ListElement { name: "Focus Time"; icon: "󱎫"; target: "focustime"; btnColor: "#cba6f7" }
                            ListElement { name: "Network"; icon: "󰖩"; target: "network"; btnColor: "#74c7ec" }
                            ListElement { name: "Volume"; icon: "󰕾"; target: "volume"; btnColor: "#f9e2af" }
                            ListElement { name: "Updater"; icon: "󰚰"; target: "updater"; btnColor: "#94e2d5" }
                            ListElement { name: "Wallpaper"; icon: "󰸉"; target: "wallpaper"; btnColor: "#f5c2e7" }
                        }

                        delegate: AppButton {
                            width: s(140); height: s(80)
                            appName: model.name; appIcon: model.icon; appColor: model.btnColor
                            onClicked: { Quickshell.execDetached(["bash", "-c", "~/.config/niri/bin/qs_manager.sh toggle " + model.target]); }
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

            // LARGE CLOCK
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: s(380)
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                radius: s(20)
                border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: s(-5)

                    Text {
                        text: Qt.formatTime(dashboardRoot.currentTime, "HH:mm")
                        font.family: "JetBrains Mono"; font.pixelSize: s(160); font.weight: Font.Black
                        color: mocha.text
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: Qt.formatDateTime(dashboardRoot.currentTime, "dddd, MMMM dd, yyyy")
                        font.family: "Outfit"; font.pixelSize: s(24); font.weight: Font.Medium
                        color: mocha.mauve
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // MINI CALENDAR
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: s(360)
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                radius: s(20)
                border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: s(12)

                    Text {
                        text: Qt.formatDateTime(dashboardRoot.currentTime, "MMMM yyyy")
                        font.family: "Outfit"; font.pixelSize: s(20); font.weight: Font.Bold
                        color: mocha.subtext1
                        Layout.alignment: Qt.AlignHCenter
                    }

                    GridLayout {
                        id: calGrid
                        columns: 7
                        columnSpacing: s(8); rowSpacing: s(8)
                        Layout.alignment: Qt.AlignHCenter
                        
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            delegate: Text {
                                text: modelData
                                font.family: "JetBrains Mono"; font.pixelSize: s(12); font.weight: Font.Bold
                                color: (index >= 5) ? mocha.red : mocha.subtext0
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        Repeater {
                            model: calendarModel
                            delegate: Rectangle {
                                width: s(34); height: s(34); radius: s(8)
                                color: isToday ? mocha.mauve : "transparent"
                                border.width: isToday ? 0 : 1
                                border.color: isToday ? "transparent" : (isCurrentMonth ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1) : "transparent")
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: "JetBrains Mono"; font.pixelSize: s(14); font.weight: isToday ? Font.Bold : Font.Normal
                                    color: isToday ? mocha.base : (isCurrentMonth ? mocha.text : mocha.surface1)
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
    ListModel { id: calendarModel }

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
        property string title: ""; property string statValue: ""; property string statIcon: ""; property color accentColor: "#cba6f7"
        property var history: []
        width: dashboardRoot.s(170); height: dashboardRoot.s(80); radius: dashboardRoot.s(15)
        color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.3)
        clip: true
        
        // Sparkline background
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.45
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
                    color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.15 + (index / Math.max(1, history.length - 1)) * 0.25)
                    
                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }

        RowLayout {
            anchors.fill: parent; anchors.margins: dashboardRoot.s(12); spacing: dashboardRoot.s(12)
            Text { text: statIcon; font.family: "Nerd Font Mono"; font.pixelSize: dashboardRoot.s(24); color: accentColor }
            Column {
                Text { text: title; font.family: "Outfit"; font.pixelSize: dashboardRoot.s(12); color: mocha.subtext0 }
                Text { text: statValue; font.family: "JetBrains Mono"; font.pixelSize: dashboardRoot.s(18); font.weight: Font.Bold; color: mocha.text }
            }
        }
    }

    component AppButton: MouseArea {
        property string appName: ""; property string appIcon: ""; property color appColor: "#89b4fa"
        id: ma; hoverEnabled: true
        
        Rectangle {
            anchors.fill: parent; radius: dashboardRoot.s(15)
            color: ma.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.5) : "transparent"
            border.width: 1; border.color: ma.containsMouse ? mocha.text : "transparent"
            Behavior on color { ColorAnimation { duration: 200 } }
            
            ColumnLayout {
                anchors.centerIn: parent; spacing: dashboardRoot.s(8)
                Text { 
                    text: appIcon; Layout.alignment: Qt.AlignHCenter
                    font.family: "Nerd Font Mono"; font.pixelSize: dashboardRoot.s(32); color: ma.appColor 
                }
                Text { 
                    text: appName; Layout.alignment: Qt.AlignHCenter
                    font.family: "Outfit"; font.pixelSize: dashboardRoot.s(14); color: mocha.text 
                }
            }
        }
    }
}
