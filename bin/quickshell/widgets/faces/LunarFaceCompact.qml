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

    readonly property bool isSpecialDay: Lunar.lunarDay === 1 || Lunar.lunarDay === 15 || (Lunar.festival && Lunar.festival !== "")
    readonly property color accentColor: isSpecialDay ? (Lunar.lunarDay === 1 ? ThemeBackend.red : (Lunar.lunarDay === 15 ? ThemeBackend.yellow : ThemeBackend.peach)) : ThemeBackend.mauve

    readonly property real sH: Math.max(0.7, Math.min(1.5, root.height / 120))
    readonly property real sW: Math.max(0.7, Math.min(1.5, root.width / 280))
    readonly property real sMin: Math.min(sH, sW)

    Rectangle {
        id: bgCard
        anchors.fill: parent
        color: ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        border.color: root.isSpecialDay ? Qt.alpha(root.accentColor, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.7)
        border.width: 1
        antialiasing: true

        Behavior on border.color { ColorAnimation { duration: 250 } }

        // Subtle background glow
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -Math.min(parent.width, parent.height) * 0.12
            width: Math.min(parent.width, parent.height) * 0.85
            height: width
            radius: width / 2
            color: root.accentColor
            opacity: 0.06
            antialiasing: true
        }

        Item {
            anchors.fill: parent
            anchors.margins: Math.max(8, Math.min(16, 12 * root.sMin))

            RowLayout {
                anchors.fill: parent
                spacing: Math.max(8, Math.min(16, 12 * root.sW))

                // Left Hero Tile: Lunar Day + Moon Phase
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.max(parent.height * 0.85, 68 * root.sMin)
                    radius: Math.max(6, ThemeBackend.borderRadius - 2)
                    color: ThemeBackend.surface1
                    border.color: Qt.alpha(root.accentColor, 0.35)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.max(4, 6 * root.sMin)
                        spacing: 1

                        // Moon Phase Icon at top of tile
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Lunar.moonPhaseIcon
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.max(11, Math.min(16, 13 * root.sMin))
                            color: root.accentColor
                        }

                        // Hero Lunar Day
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: Lunar.lunarDay < 10 ? ("0" + Lunar.lunarDay) : String(Lunar.lunarDay)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.min(parent.width * 0.7, parent.height * 0.52)
                            font.weight: Font.Black
                            color: root.accentColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Day label (e.g. MÙNG 1 / RẰM / NGÀY 23)
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitHeight: Math.max(14, Math.min(20, 16 * root.sH))
                            implicitWidth: Math.min(parent.width - 4, tileLabelText.implicitWidth + 10)
                            radius: height / 2
                            color: root.isSpecialDay ? Qt.alpha(root.accentColor, 0.2) : Qt.alpha(ThemeBackend.surface2, 0.7)

                            Text {
                                id: tileLabelText
                                anchors.centerIn: parent
                                width: parent.width - 4
                                text: {
                                    if (Lunar.lunarDay === 15) return "RẰM";
                                    if (Lunar.lunarDay === 1) return "MÙNG 1";
                                    return "NGÀY " + Lunar.lunarDay;
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(7.5, Math.min(10, 8.5 * root.sMin))
                                font.weight: Font.Black
                                color: root.isSpecialDay ? root.accentColor : ThemeBackend.text
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Right Panel: Solar Info, Can Chi & Badges
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.max(2, Math.min(6, 4 * root.sH))

                    // Row 1: Solar Date formatted cleanly
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "󰸗"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.max(11, Math.min(14, 12 * root.sMin))
                            color: ThemeBackend.mauve
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: DateTime.dayName + ", " + DateTime.shortDate + "/" + DateTime.year
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(11, Math.min(14.5, 12.5 * root.sMin))
                            font.weight: Font.Black
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // Row 2: Lunar Month Name & Year Can Chi
                    Text {
                        Layout.fillWidth: true
                        text: Lunar.monthName + (Lunar.canChiYear !== "" ? (" • Năm " + Lunar.canChiYear) : "")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(9.5, Math.min(12.5, 11 * root.sMin))
                        font.weight: Font.DemiBold
                        color: ThemeBackend.subtext0
                        elide: Text.ElideRight
                    }

                    // Row 3: Badges Row (Can Chi Day, Giờ Can Chi, Moon Phase / Festival)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // Can Chi Day badge
                        Rectangle {
                            implicitHeight: Math.max(16, Math.min(22, 19 * root.sH))
                            implicitWidth: dayCanChiText.implicitWidth + 12
                            radius: height / 2
                            color: Qt.alpha(ThemeBackend.surface1, 0.9)
                            border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                            border.width: 1

                            Text {
                                id: dayCanChiText
                                anchors.centerIn: parent
                                text: "Ngày " + Lunar.canChiDay
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(8, Math.min(10, 9 * root.sMin))
                                font.weight: Font.Bold
                                color: ThemeBackend.text
                            }
                        }

                        // Can Chi Giờ badge
                        Rectangle {
                            visible: Lunar.canChiHour !== ""
                            implicitHeight: Math.max(16, Math.min(22, 19 * root.sH))
                            implicitWidth: hourCanChiText.implicitWidth + 12
                            radius: height / 2
                            color: Qt.alpha(ThemeBackend.surface1, 0.7)
                            border.color: Qt.alpha(ThemeBackend.surface2, 0.4)
                            border.width: 1

                            Text {
                                id: hourCanChiText
                                anchors.centerIn: parent
                                text: "Giờ " + Lunar.canChiHour
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(8, Math.min(10, 9 * root.sMin))
                                font.weight: Font.DemiBold
                                color: ThemeBackend.subtext0
                            }
                        }

                        // Festival badge (if any)
                        Rectangle {
                            visible: Lunar.festival !== ""
                            implicitHeight: Math.max(16, Math.min(22, 19 * root.sH))
                            implicitWidth: festMoonText.implicitWidth + 12
                            radius: height / 2
                            color: Qt.alpha(root.accentColor, 0.2)
                            border.color: Qt.alpha(root.accentColor, 0.4)
                            border.width: 1

                            Text {
                                id: festMoonText
                                anchors.centerIn: parent
                                text: " " + Lunar.festival
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(8, Math.min(10, 9 * root.sMin))
                                font.weight: Font.Bold
                                color: root.accentColor
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
