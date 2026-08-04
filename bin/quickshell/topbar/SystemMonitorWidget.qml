import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property var barWindow
    required property var mocha

    spacing: barWindow.s(12)

    // CPU Indicator
    RowLayout {
        spacing: root.barWindow.s(4)
        Text {
            text: "󰍛"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: root.barWindow.s(14)
            color: root.mocha.teal
        }
        Text {
            text: root.barWindow.cpuPercent + "%"
            font.family: "JetBrains Mono"
            font.pixelSize: root.barWindow.s(12)
            font.weight: Font.Bold
            color: root.mocha.text
        }
    }

    // RAM Indicator
    RowLayout {
        spacing: root.barWindow.s(4)
        Text {
            text: "󰘚"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: root.barWindow.s(14)
            color: root.mocha.sapphire
        }
        Text {
            text: root.barWindow.ramPercent + "%"
            font.family: "JetBrains Mono"
            font.pixelSize: root.barWindow.s(12)
            font.weight: Font.Bold
            color: root.mocha.text
        }
    }
}
