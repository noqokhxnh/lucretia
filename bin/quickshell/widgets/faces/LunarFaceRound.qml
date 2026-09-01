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

    readonly property bool isSpecialDay: Lunar.lunarDay === 1 || Lunar.lunarDay === 15 || Lunar.festival !== ""
    readonly property color accentColor: isSpecialDay ? (Lunar.lunarDay === 1 ? ThemeBackend.red : (Lunar.lunarDay === 15 ? ThemeBackend.yellow : ThemeBackend.peach)) : ThemeBackend.mauve

    Rectangle {
        id: roundBody
        anchors.fill: parent
        radius: width / 2
        color: ThemeBackend.surfaceVariant ?? ThemeBackend.surface0
        border.color: root.isSpecialDay ? Qt.alpha(root.accentColor, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.6)
        border.width: Math.max(1, width * 0.015)
        antialiasing: true

        Behavior on border.color { ColorAnimation { duration: 250 } }

        // Decorative background orbit ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.82
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.alpha(root.accentColor, 0.15)
            border.width: Math.max(1, parent.width * 0.01)
            antialiasing: true
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.76
            height: parent.height * 0.76
            spacing: 0

            // 1. Top Moon Phase & Solar Date
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Text {
                    text: Lunar.moonPhaseIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: Math.max(10, Math.min(18, roundBody.width * 0.09))
                    color: root.accentColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: DateTime.shortDate
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.max(9, Math.min(13, roundBody.width * 0.065))
                    font.weight: Font.Black
                    color: ThemeBackend.subtext0
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // 2. Large Lunar Day in Center
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: Lunar.lunarDay < 10 ? ("0" + Lunar.lunarDay) : String(Lunar.lunarDay)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(20, Math.min(70, roundBody.width * 0.38))
                fontSizeMode: Text.Fit
                minimumPixelSize: 14
                font.weight: Font.Black
                color: root.accentColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            // 3. Lunar Month & Can Chi Year
            Text {
                Layout.fillWidth: true
                text: (Lunar.lunarDay === 15 ? "RẰM " : (Lunar.lunarDay === 1 ? "MÙNG 1 " : "")) + Lunar.monthName
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(8, Math.min(12, roundBody.width * 0.06))
                fontSizeMode: Text.Fit
                minimumPixelSize: 7
                font.weight: Font.Bold
                color: ThemeBackend.text
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // 4. Can Chi Year
            Text {
                Layout.fillWidth: true
                text: Lunar.canChiYear !== "" ? Lunar.canChiYear : ""
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(7, Math.min(11, roundBody.width * 0.052))
                fontSizeMode: Text.Fit
                minimumPixelSize: 6
                font.weight: Font.DemiBold
                color: ThemeBackend.overlay0
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
