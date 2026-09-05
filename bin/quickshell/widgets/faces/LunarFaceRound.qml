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

        // Concentric Content Stack
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.72
            height: parent.height * 0.72
            spacing: 0

            // 1. Top Section: Solar Day of Week & Month Tag
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Rectangle {
                    implicitHeight: Math.max(14, Math.min(22, roundBody.width * 0.09))
                    implicitWidth: topDateText.implicitWidth + Math.max(10, roundBody.width * 0.06)
                    radius: height / 2
                    color: Qt.alpha(ThemeBackend.surface1, 0.7)

                    Text {
                        id: topDateText
                        anchors.centerIn: parent
                        text: DateTime.dayNameShort.toUpperCase() + ", " + Qt.formatDateTime(DateTime.now, "MMM yyyy").toUpperCase()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(7.5, Math.min(10.5, roundBody.width * 0.052))
                        font.weight: Font.Black
                        font.letterSpacing: 0.4
                        color: ThemeBackend.subtext0
                    }
                }
            }

            // 2. Center Hero: Solar Day Number (Primary)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    text: DateTime.day
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(22, Math.min(74, roundBody.width * 0.36))
                    font.weight: Font.Black
                    color: ThemeBackend.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // 3. Bottom Section: Lunar Date (Secondary, subtle & elegant)
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: 2

                // Lunar Date Badge (e.g. 󰽢 Âm: 23/7 hoặc MÙNG 1 / RẰM)
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: Math.max(14, Math.min(22, roundBody.width * 0.09))
                    implicitWidth: lunarPillText.implicitWidth + Math.max(10, roundBody.width * 0.06)
                    radius: height / 2
                    color: Qt.alpha(root.accentColor, 0.15)
                    border.color: Qt.alpha(root.accentColor, 0.35)
                    border.width: 1

                    RowLayout {
                        id: lunarPillText
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            text: {
                                if (Lunar.lunarDay === 15) return "RẰM 15 ÂM";
                                if (Lunar.lunarDay === 1) return "MÙNG 1 ÂM";
                                return "ÂM " + Lunar.lunarDay + "/" + Lunar.lunarMonth;
                            }
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(7.5, Math.min(10.5, roundBody.width * 0.052))
                            font.weight: Font.Black
                            color: root.accentColor
                        }
                    }
                }

                // Can Chi Year
                Text {
                    Layout.fillWidth: true
                    text: "Năm " + Lunar.canChiYear + (Lunar.animal !== "" ? (" (" + Lunar.animal + ")") : "")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(7, Math.min(10, roundBody.width * 0.046))
                    font.weight: Font.Medium
                    color: ThemeBackend.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
