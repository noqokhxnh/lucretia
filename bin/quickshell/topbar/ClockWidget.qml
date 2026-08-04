import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property var barWindow
    required property var mocha

    spacing: barWindow.s(24)

    ColumnLayout {
        spacing: -2
        Text {
            text: root.barWindow.timeStr
            Layout.alignment: Qt.AlignLeft
            font.family: "JetBrains Mono"
            font.pixelSize: root.barWindow.s(16)
            font.weight: Font.Black
            color: root.mocha.blue
        }
        Text {
            text: root.barWindow.dateStr
            Layout.alignment: Qt.AlignLeft
            font.family: "JetBrains Mono"
            font.pixelSize: root.barWindow.s(11)
            font.weight: Font.Bold
            color: root.mocha.subtext0
        }
    }

    RowLayout {
        spacing: root.barWindow.s(8)
        Text {
            text: root.barWindow.weatherIcon
            Layout.alignment: Qt.AlignVCenter
            font.family: "Iosevka Nerd Font"
            font.pixelSize: root.barWindow.s(24)
            color: Qt.tint(root.barWindow.weatherHex, Qt.rgba(root.mocha.mauve.r, root.mocha.mauve.g, root.mocha.mauve.b, 0.4))
        }
        Text {
            text: root.barWindow.weatherTemp
            Layout.alignment: Qt.AlignVCenter
            font.family: "JetBrains Mono"
            font.pixelSize: root.barWindow.s(17)
            font.weight: Font.Black
            color: root.mocha.peach
        }
    }
}
