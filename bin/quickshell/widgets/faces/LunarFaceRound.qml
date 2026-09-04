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

    property real minWidth: 100
    property real minHeight: 100
    property real maxWidth: 800
    property real maxHeight: 800
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true

    readonly property bool isSpecialDay: Lunar.lunarDay === 1 || Lunar.lunarDay === 15 || (Lunar.festival && Lunar.festival !== "")
    readonly property color accentColor: isSpecialDay ? (Lunar.lunarDay === 1 ? ThemeBackend.red : (Lunar.lunarDay === 15 ? ThemeBackend.yellow : ThemeBackend.peach)) : ThemeBackend.mauve

    readonly property real dialSize: Math.min(root.width, root.height)

    Rectangle {
        id: roundBody
        anchors.centerIn: parent
        width: root.dialSize
        height: root.dialSize
        radius: width / 2
        color: ThemeBackend.surface0
        border.color: root.isSpecialDay ? Qt.alpha(root.accentColor, 0.55) : Qt.alpha(ThemeBackend.surface1, 0.8)
        border.width: Math.max(1.5, width * 0.016)
        antialiasing: true

        Behavior on border.color { ColorAnimation { duration: 250 } }

        // Decorative outer orbit ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.alpha(root.accentColor, 0.16)
            border.width: Math.max(1, parent.width * 0.008)
            antialiasing: true
        }

        // Decorative inner orbit ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.68
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.alpha(ThemeBackend.surface2, 0.25)
            border.width: 1
            antialiasing: true
        }

        // Soft center glow
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.46
            height: width
            radius: width / 2
            color: root.accentColor
            opacity: 0.06
            antialiasing: true
        }

        // Concentric Content Stack (strictly bounded within safe circle area)
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.72
            height: parent.height * 0.72
            spacing: 0

            // 1. Top Section: Solar Date & Day of Week Badge
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Rectangle {
                    implicitHeight: Math.max(14, Math.min(22, roundBody.width * 0.09))
                    implicitWidth: topDateText.implicitWidth + Math.max(8, roundBody.width * 0.05)
                    radius: height / 2
                    color: Qt.alpha(ThemeBackend.surface1, 0.7)

                    Text {
                        id: topDateText
                        anchors.centerIn: parent
                        text: DateTime.shortDate + " " + DateTime.dayNameShort
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(7.5, Math.min(11, roundBody.width * 0.055))
                        font.weight: Font.Bold
                        color: ThemeBackend.subtext0
                    }
                }
            }

            // 2. Center Section: Moon Phase & Massive Lunar Numeral
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    // Moon Phase Icon
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Lunar.moonPhaseIcon
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: Math.max(12, Math.min(26, roundBody.width * 0.12))
                        color: root.accentColor
                    }

                    // Bold Lunar Day
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Lunar.lunarDay < 10 ? ("0" + Lunar.lunarDay) : String(Lunar.lunarDay)
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(18, Math.min(64, roundBody.width * 0.32))
                        font.weight: Font.Black
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // 3. Bottom Section: Lunar Month & Can Chi Year
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: 2

                // Special day badge (e.g. "MÙNG 1", "RẰM", hoặc Festival)
                Rectangle {
                    visible: root.isSpecialDay
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: Math.max(13, Math.min(20, roundBody.width * 0.08))
                    implicitWidth: statusText.implicitWidth + Math.max(8, roundBody.width * 0.05)
                    radius: height / 2
                    color: Qt.alpha(root.accentColor, 0.2)
                    border.color: Qt.alpha(root.accentColor, 0.4)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: {
                            if (Lunar.lunarDay === 15) return "RẰM";
                            if (Lunar.lunarDay === 1) return "MÙNG 1";
                            if (Lunar.festival !== "") return Lunar.festival;
                            return "";
                        }
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(7, Math.min(10, roundBody.width * 0.048))
                        font.weight: Font.Black
                        color: root.accentColor
                        elide: Text.ElideRight
                    }
                }

                // Month Name & Can Chi Year
                Text {
                    Layout.fillWidth: true
                    text: Lunar.monthName + (Lunar.canChiYear !== "" ? (" • " + Lunar.canChiYear) : "")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(7, Math.min(10.5, roundBody.width * 0.05))
                    font.weight: Font.Bold
                    color: ThemeBackend.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
