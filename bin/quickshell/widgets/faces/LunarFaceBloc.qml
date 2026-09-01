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

    property real minWidth: 220
    property real minHeight: 280
    property real maxWidth: 700
    property real maxHeight: 900
    property real minAspect: 0.65
    property real maxAspect: 1.1
    property bool isRound: false

    readonly property bool isSpecialDay: Lunar.lunarDay === 1 || Lunar.lunarDay === 15 || Lunar.festival !== ""
    readonly property color accentColor: isSpecialDay ? (Lunar.lunarDay === 1 ? ThemeBackend.red : (Lunar.lunarDay === 15 ? ThemeBackend.yellow : ThemeBackend.peach)) : ThemeBackend.mauve

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.surfaceVariant ?? ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        border.color: root.isSpecialDay ? Qt.alpha(root.accentColor, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.5)
        border.width: 1
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.max(10, Math.min(22, root.width * 0.05))
            spacing: Math.max(4, Math.min(10, root.height * 0.02))

            // 1. Top Header: Day of week & Month/Year
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    implicitHeight: Math.max(20, Math.min(28, root.height * 0.075))
                    implicitWidth: dayNameText.implicitWidth + 16
                    radius: height / 2
                    color: root.accentColor

                    Text {
                        id: dayNameText
                        anchors.centerIn: parent
                        text: DateTime.dayName.toUpperCase()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(9, Math.min(13, root.height * 0.04))
                        font.weight: Font.Black
                        color: ThemeBackend.crust
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Qt.formatDateTime(DateTime.now, "MMMM yyyy").toUpperCase()
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(10, Math.min(14, root.height * 0.045))
                    font.weight: Font.Black
                    color: ThemeBackend.subtext0
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // 2. Central Solar Day (Large Bloc number)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.max(60, root.height * 0.3)

                Text {
                    anchors.centerIn: parent
                    text: DateTime.day
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.min(parent.width * 0.7, parent.height * 0.95)
                    font.weight: Font.Black
                    color: root.isSpecialDay ? root.accentColor : (ThemeBackend.primary ?? ThemeBackend.text)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // 3. Festival Tag if any
            Rectangle {
                visible: Lunar.festival !== ""
                Layout.fillWidth: true
                implicitHeight: Math.max(22, root.height * 0.07)
                radius: Math.max(4, ThemeBackend.borderRadius - 2)
                color: Qt.alpha(root.accentColor, 0.2)
                border.color: Qt.alpha(root.accentColor, 0.45)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "★ " + Lunar.festival + " ★"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(9, Math.min(12, root.height * 0.038))
                    font.weight: Font.Black
                    color: root.accentColor
                }
            }

            // 4. Lunar Primary Info Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(45, root.height * 0.16)
                radius: Math.max(6, ThemeBackend.borderRadius - 2)
                color: Qt.alpha(ThemeBackend.surface1, 0.6)
                border.color: Qt.alpha(ThemeBackend.surface2, 0.4)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: Lunar.moonPhaseIcon
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.max(12, Math.min(16, root.height * 0.05))
                            color: root.accentColor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (Lunar.lunarDay === 15 ? "RẰM " : (Lunar.lunarDay === 1 ? "MÙNG 1 " : "NGÀY " + Lunar.lunarDay + " ")) + Lunar.monthName.toUpperCase()
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(11, Math.min(15, root.height * 0.05))
                            font.weight: Font.Black
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Năm " + Lunar.canChiYear + " • Tháng " + Lunar.canChiMonth + " • Ngày " + Lunar.canChiDay
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(8, Math.min(11, root.height * 0.036))
                        font.weight: Font.DemiBold
                        color: ThemeBackend.subtext0
                        elide: Text.ElideRight
                    }
                }
            }

            // 5. Auspicious Day & Solar Term Badges
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    implicitHeight: Math.max(16, Math.min(22, root.height * 0.065))
                    implicitWidth: hdText.implicitWidth + 12
                    radius: height / 2
                    color: Lunar.isAuspiciousDay ? Qt.alpha(ThemeBackend.green, 0.2) : Qt.alpha(ThemeBackend.surface1, 0.8)

                    Text {
                        id: hdText
                        anchors.centerIn: parent
                        text: (Lunar.isAuspiciousDay ? "★ " : "• ") + Lunar.dayZodiacType + ": " + Lunar.dayZodiacName
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(8, Math.min(10, root.height * 0.034))
                        font.weight: Font.Bold
                        color: Lunar.isAuspiciousDay ? ThemeBackend.green : ThemeBackend.subtext0
                    }
                }

                Rectangle {
                    implicitHeight: Math.max(16, Math.min(22, root.height * 0.065))
                    implicitWidth: tkText.implicitWidth + 12
                    radius: height / 2
                    color: ThemeBackend.surface2

                    Text {
                        id: tkText
                        anchors.centerIn: parent
                        text: " " + Lunar.solarTerm
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(8, Math.min(10, root.height * 0.034))
                        font.weight: Font.Bold
                        color: ThemeBackend.peach
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // 6. Auspicious Hours (Giờ Hoàng Đạo)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "GIỜ HOÀNG ĐẠO:"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(8, Math.min(10, root.height * 0.032))
                    font.weight: Font.Black
                    color: ThemeBackend.overlay0
                }

                Text {
                    Layout.fillWidth: true
                    text: Lunar.zodiacHoursStr
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(9, Math.min(11, root.height * 0.036))
                    font.weight: Font.Bold
                    color: ThemeBackend.text
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }
    }
}
