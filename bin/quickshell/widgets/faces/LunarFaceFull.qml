import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../reusables"
import "../../"
import "../../singletons"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 280
    property real minHeight: 220
    property real maxWidth: 900
    property real maxHeight: 700
    property real minAspect: 1.0
    property real maxAspect: 2.0
    property bool isRound: false

    property int monthOffset: 0
    property var currentViewDate: {
        let d = new Date();
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }

    property var gridData: []

    function updateGrid() {
        let y = root.currentViewDate.getFullYear();
        let m = root.currentViewDate.getMonth();
        root.gridData = Lunar.getMonthGrid(y, m);
    }

    onMonthOffsetChanged: updateGrid()
    Component.onCompleted: updateGrid()

    Connections {
        target: Lunar
        function onDetailsChanged() {
            root.updateGrid();
        }
    }

    // Responsive scaling factor
    readonly property real sH: Math.max(0.65, Math.min(1.5, root.height / 320))
    readonly property real sW: Math.max(0.65, Math.min(1.5, root.width / 420))
    readonly property real sMin: Math.min(sH, sW)

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        border.color: Qt.alpha(ThemeBackend.surface1, 0.7)
        border.width: 1
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.max(8, Math.min(18, 12 * root.sMin))
            spacing: Math.max(4, Math.min(10, 6 * root.sH))

            // 1. Header: Month/Year navigation & Can Chi information
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Title & Subtitle Column
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: Qt.formatDateTime(root.currentViewDate, "MMMM yyyy").toUpperCase()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(12, Math.min(18, 14.5 * root.sMin))
                        font.weight: Font.Black
                        font.letterSpacing: 0.5
                        color: ThemeBackend.text
                    }

                    Text {
                        text: {
                            let m = root.currentViewDate.getMonth() + 1;
                            let y = root.currentViewDate.getFullYear();
                            let dInfo = Lunar.getDetailsForDate(15, m, y);
                            return (dInfo ? ("Tháng " + dInfo.canChiMonth + " • Năm " + dInfo.canChiYear) : "");
                        }
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(9, Math.min(12, 10.5 * root.sMin))
                        font.weight: Font.DemiBold
                        color: ThemeBackend.mauve
                        elide: Text.ElideRight
                    }
                }

                // Quick Today jump button
                Rectangle {
                    visible: root.monthOffset !== 0
                    opacity: root.monthOffset !== 0 ? 1.0 : 0.0
                    implicitHeight: Math.max(22, Math.min(30, 26 * root.sH))
                    implicitWidth: todayBtnText.implicitWidth + 16
                    radius: height / 2
                    color: todayMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1
                    border.color: Qt.alpha(ThemeBackend.mauve, 0.4)
                    border.width: 1

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰃭"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.max(9, Math.min(12, 10.5 * root.sMin))
                            color: ThemeBackend.mauve
                        }
                        Text {
                            id: todayBtnText
                            text: "Hôm nay"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(8.5, Math.min(11, 9.5 * root.sMin))
                            font.weight: Font.Bold
                            color: ThemeBackend.text
                        }
                    }

                    MouseArea {
                        id: todayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset = 0
                    }
                }

                // Prev Month Button
                Rectangle {
                    implicitWidth: Math.max(22, Math.min(30, 26 * root.sH))
                    implicitHeight: implicitWidth
                    radius: implicitWidth / 2
                    color: prevMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: Math.max(10, Math.min(14, 12 * root.sMin))
                        color: ThemeBackend.text
                    }

                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset -= 1
                    }
                }

                // Next Month Button
                Rectangle {
                    implicitWidth: Math.max(22, Math.min(30, 26 * root.sH))
                    implicitHeight: implicitWidth
                    radius: implicitWidth / 2
                    color: nextMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: Math.max(10, Math.min(14, 12 * root.sMin))
                        color: ThemeBackend.text
                    }

                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset += 1
                    }
                }
            }

            // 2. Days of week header strip
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(18, Math.min(26, 22 * root.sH))
                radius: Math.max(4, ThemeBackend.borderRadius - 4)
                color: Qt.alpha(ThemeBackend.surface1, 0.4)

                RowLayout {
                    anchors.fill: parent
                    spacing: 2

                    Repeater {
                        model: [
                            I18n.t("calendar.days.mo") || "T2",
                            I18n.t("calendar.days.tu") || "T3",
                            I18n.t("calendar.days.we") || "T4",
                            I18n.t("calendar.days.th") || "T5",
                            I18n.t("calendar.days.fr") || "T6",
                            I18n.t("calendar.days.sa") || "T7",
                            I18n.t("calendar.days.su") || "CN"
                        ]

                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: Math.max(8.5, Math.min(11.5, 10 * root.sMin))
                            color: {
                                if (index === 6) return ThemeBackend.peach; // Sunday
                                if (index === 5) return ThemeBackend.mauve; // Saturday
                                return ThemeBackend.subtext0;
                            }
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // 3. 7x6 Calendar Grid
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2

                Repeater {
                    model: root.gridData

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Math.max(4, Math.min(8, height * 0.22))
                        color: {
                            if (modelData.isToday) return ThemeBackend.mauve;
                            if (cellMa.containsMouse) return ThemeBackend.surface2;
                            return "transparent";
                        }
                        border.color: {
                            if (modelData.isToday) return Qt.lighter(ThemeBackend.mauve, 1.2);
                            if (modelData.isLunar1st) return Qt.alpha(ThemeBackend.red, 0.4);
                            if (modelData.isLunar15th) return Qt.alpha(ThemeBackend.yellow, 0.4);
                            return "transparent";
                        }
                        border.width: 1
                        opacity: modelData.isCurrentMonth ? 1.0 : 0.35

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 1
                            spacing: 0

                            // Solar day (Top)
                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: String(modelData.solarDay)
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(9, Math.min(14, parent.height * 0.46))
                                font.weight: modelData.isToday ? Font.Black : (modelData.isCurrentMonth ? Font.Bold : Font.Normal)
                                color: modelData.isToday ? ThemeBackend.crust : (modelData.isCurrentMonth ? ThemeBackend.text : ThemeBackend.subtext1)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Lunar day (Bottom)
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(8, parent.height * 0.4)
                                spacing: 2

                                Item { Layout.fillWidth: true }

                                // Indicator dot for 1st or 15th
                                Rectangle {
                                    visible: !modelData.isToday && (modelData.isLunar1st || modelData.isLunar15th)
                                    width: Math.max(3, Math.min(5, parent.height * 0.3))
                                    height: width
                                    radius: width / 2
                                    color: modelData.isLunar1st ? ThemeBackend.red : ThemeBackend.yellow
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: modelData.lunarDayText
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Math.max(7, Math.min(10, parent.height * 0.34))
                                    font.weight: (modelData.isLunar1st || modelData.isLunar15th || modelData.isToday) ? Font.Black : Font.Medium
                                    color: {
                                        if (modelData.isToday) return Qt.darker(ThemeBackend.crust, 1.25);
                                        if (modelData.isLunar1st) return ThemeBackend.red;
                                        if (modelData.isLunar15th) return ThemeBackend.yellow;
                                        return ThemeBackend.subtext0;
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }

            // 4. Footer Bar: Today Lunar Status
            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                // Bottom Lunar pill badge
                Rectangle {
                    implicitHeight: Math.max(18, Math.min(24, 21 * root.sH))
                    implicitWidth: todayLunarText.implicitWidth + 14
                    radius: height / 2
                    color: Qt.alpha(ThemeBackend.surface1, 0.7)
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.5)
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            id: todayLunarText
                            text: "Hôm nay: " + (Lunar.lunarDay === 1 ? "Mùng 1" : (Lunar.lunarDay === 15 ? "Rằm" : "Ngày " + Lunar.lunarDay)) + " " + Lunar.monthName + " (" + Lunar.canChiDay + ")"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(8, Math.min(10.5, 9.5 * root.sMin))
                            font.weight: Font.Bold
                            color: ThemeBackend.text
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
