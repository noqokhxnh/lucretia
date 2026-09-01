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

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.surfaceVariant ?? ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        border.color: Qt.alpha(ThemeBackend.surface1, 0.6)
        border.width: 1
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.max(10, Math.min(20, root.width * 0.04))
            spacing: Math.max(4, Math.min(10, root.height * 0.025))

            // Header: Month/Year navigation & Can Chi
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: Qt.formatDateTime(root.currentViewDate, "MMMM yyyy").toUpperCase()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(12, Math.min(17, root.height * 0.065))
                        font.weight: Font.Black
                        color: ThemeBackend.text
                    }

                    Text {
                        text: {
                            let m = root.currentViewDate.getMonth() + 1;
                            let y = root.currentViewDate.getFullYear();
                            let dInfo = Lunar.getDetailsForDate(15, m, y);
                            return (dInfo ? (dInfo.canChiMonth + " • " + dInfo.canChiYear) : "");
                        }
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(9, Math.min(12, root.height * 0.045))
                        font.weight: Font.DemiBold
                        color: ThemeBackend.mauve
                        elide: Text.ElideRight
                    }
                }

                // Reset to today button
                IconButton {
                    size: Math.max(22, Math.min(30, root.height * 0.11))
                    cornerRadius: Math.max(4, size * 0.25)
                    buttonIcon: "󰃭"
                    iconFontSize: Math.max(10, size * 0.5)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    opacity: root.monthOffset !== 0 ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    onClicked: root.monthOffset = 0
                }

                // Prev month
                IconButton {
                    size: Math.max(22, Math.min(30, root.height * 0.11))
                    cornerRadius: Math.max(4, size * 0.25)
                    buttonIcon: ""
                    iconFontSize: Math.max(10, size * 0.5)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    onClicked: root.monthOffset -= 1
                }

                // Next month
                IconButton {
                    size: Math.max(22, Math.min(30, root.height * 0.11))
                    cornerRadius: Math.max(4, size * 0.25)
                    buttonIcon: ""
                    iconFontSize: Math.max(10, size * 0.5)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    onClicked: root.monthOffset += 1
                }
            }

            // Days of week header
            RowLayout {
                Layout.fillWidth: true
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
                        font.pixelSize: Math.max(9, Math.min(12, root.height * 0.045))
                        color: index >= 5 ? ThemeBackend.peach : ThemeBackend.overlay0
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // 7x6 Calendar Grid
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
                        color: modelData.isToday ? ThemeBackend.mauve : (cellMa.containsMouse ? ThemeBackend.surface2 : "transparent")
                        border.color: modelData.isToday ? Qt.lighter(ThemeBackend.mauve, 1.2) : (modelData.isLunar1st || modelData.isLunar15th ? Qt.alpha(modelData.isLunar1st ? ThemeBackend.red : ThemeBackend.yellow, 0.3) : "transparent")
                        border.width: 1

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
                                font.pixelSize: Math.max(9, Math.min(14, parent.height * 0.48))
                                font.weight: modelData.isToday ? Font.Black : (modelData.isCurrentMonth ? Font.Bold : Font.Normal)
                                color: modelData.isToday ? ThemeBackend.crust : (modelData.isCurrentMonth ? ThemeBackend.text : ThemeBackend.surface2)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Lunar day (Bottom)
                            Text {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(8, parent.height * 0.4)
                                text: modelData.lunarDayText
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(7, Math.min(10, parent.height * 0.34))
                                font.weight: (modelData.isLunar1st || modelData.isLunar15th) ? Font.Black : Font.Normal
                                color: {
                                    if (modelData.isToday) return Qt.darker(ThemeBackend.crust, 1.2);
                                    if (!modelData.isCurrentMonth) return ThemeBackend.surface2;
                                    if (modelData.isLunar1st) return ThemeBackend.red;
                                    if (modelData.isLunar15th) return ThemeBackend.yellow;
                                    return ThemeBackend.subtext0;
                                }
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            // Footer info: Solar term & Zodiac Day
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    implicitHeight: Math.max(16, Math.min(22, root.height * 0.08))
                    implicitWidth: ftTietKhi.implicitWidth + 12
                    radius: height / 2
                    color: ThemeBackend.surface1

                    Text {
                        id: ftTietKhi
                        anchors.centerIn: parent
                        text: " " + Lunar.solarTerm
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(8, Math.min(11, root.height * 0.042))
                        font.weight: Font.Bold
                        color: ThemeBackend.peach
                    }
                }

                Rectangle {
                    implicitHeight: Math.max(16, Math.min(22, root.height * 0.08))
                    implicitWidth: ftHoangDao.implicitWidth + 12
                    radius: height / 2
                    color: Lunar.isAuspiciousDay ? Qt.alpha(ThemeBackend.green, 0.18) : Qt.alpha(ThemeBackend.surface1, 0.8)

                    Text {
                        id: ftHoangDao
                        anchors.centerIn: parent
                        text: (Lunar.isAuspiciousDay ? "★ " : "• ") + Lunar.dayZodiacType + ": " + Lunar.dayZodiacName
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(8, Math.min(11, root.height * 0.042))
                        font.weight: Font.Bold
                        color: Lunar.isAuspiciousDay ? ThemeBackend.green : ThemeBackend.subtext0
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Lunar.moonPhaseIcon + " " + Lunar.moonPhaseName
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: Math.max(8, Math.min(11, root.height * 0.042))
                    color: ThemeBackend.subtext0
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
