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

    property real minWidth: 160
    property real minHeight: 80
    property real maxWidth: 600
    property real maxHeight: 300
    property real minAspect: 1.2
    property real maxAspect: 3.5
    property bool isRound: false

    readonly property bool isSpecialDay: Lunar.lunarDay === 1 || Lunar.lunarDay === 15 || Lunar.festival !== ""
    readonly property color accentColor: isSpecialDay ? (Lunar.lunarDay === 1 ? ThemeBackend.red : (Lunar.lunarDay === 15 ? ThemeBackend.yellow : ThemeBackend.peach)) : ThemeBackend.mauve

    Rectangle {
        id: bgCard
        anchors.fill: parent
        color: ThemeBackend.surfaceVariant ?? ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        border.color: root.isSpecialDay ? Qt.alpha(root.accentColor, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.5)
        border.width: 1
        antialiasing: true

        Behavior on border.color { ColorAnimation { duration: 250 } }

        // Subtle background glow circle
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -Math.min(parent.width, parent.height) * 0.15
            width: Math.min(parent.width, parent.height) * 0.9
            height: width
            radius: width / 2
            color: root.accentColor
            opacity: 0.08
            antialiasing: true
        }

        Item {
            anchors.fill: parent
            anchors.margins: Math.max(8, Math.min(18, Math.min(parent.width, parent.height) * 0.1))

            RowLayout {
                anchors.fill: parent
                spacing: Math.max(8, Math.min(16, parent.width * 0.04))

                // Left block: Lunar Day + Lunar Month/Can Chi
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.max(parent.height * 0.9, 70)
                    radius: Math.max(6, ThemeBackend.borderRadius - 2)
                    color: Qt.alpha(root.accentColor, 0.14)
                    border.color: Qt.alpha(root.accentColor, 0.3)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: Lunar.lunarDay < 10 ? ("0" + Lunar.lunarDay) : String(Lunar.lunarDay)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: height * 0.8
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 14
                            font.weight: Font.Black
                            color: root.accentColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(14, parent.height * 0.3)
                            text: Lunar.dayStr
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(9, Math.min(12, parent.height * 0.22))
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 8
                            font.weight: Font.Bold
                            color: ThemeBackend.onSurface ?? ThemeBackend.text
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                // Right block: Solar info, Can Chi, Tiết khí, Festival
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.max(2, Math.min(6, parent.height * 0.04))

                    // Row 1: Solar Date + Moon Phase Icon
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: Lunar.moonPhaseIcon
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.max(12, Math.min(16, parent.height * 0.6))
                            color: root.accentColor
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: DateTime.shortDate + " (" + DateTime.dayNameShort + ")"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(11, Math.min(15, parent.height * 0.6))
                            font.weight: Font.Black
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // Row 2: Lunar Month Name & Year Can Chi
                    Text {
                        Layout.fillWidth: true
                        text: Lunar.monthName + (Lunar.canChiYear !== "" ? (" • " + Lunar.canChiYear) : "")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(10, Math.min(13, parent.height * 0.24))
                        font.weight: Font.DemiBold
                        color: ThemeBackend.subtext0
                        elide: Text.ElideRight
                    }

                    // Row 3: Can Chi Day & Tiết Khí / Festival badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            implicitHeight: Math.max(16, Math.min(22, parent.height * 0.9))
                            implicitWidth: dayCanChiText.implicitWidth + 10
                            radius: height / 2
                            color: ThemeBackend.surface2 ?? ThemeBackend.surface1

                            Text {
                                id: dayCanChiText
                                anchors.centerIn: parent
                                text: "Ngày " + Lunar.canChiDay
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(8, Math.min(10, parent.height * 0.55))
                                font.weight: Font.Bold
                                color: ThemeBackend.text
                            }
                        }

                        Rectangle {
                            visible: Lunar.festival !== "" || Lunar.solarTerm !== ""
                            implicitHeight: Math.max(16, Math.min(22, parent.height * 0.9))
                            implicitWidth: tietKhiText.implicitWidth + 10
                            radius: height / 2
                            color: Lunar.festival !== "" ? Qt.alpha(root.accentColor, 0.25) : (ThemeBackend.primaryContainer ?? ThemeBackend.surface1)

                            Text {
                                id: tietKhiText
                                anchors.centerIn: parent
                                text: Lunar.festival !== "" ? Lunar.festival : Lunar.solarTerm
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(8, Math.min(10, parent.height * 0.55))
                                font.weight: Font.Bold
                                color: Lunar.festival !== "" ? root.accentColor : (ThemeBackend.onPrimaryContainer ?? ThemeBackend.subtext0)
                                elide: Text.ElideRight
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
