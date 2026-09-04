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

    property real minWidth: 200
    property real minHeight: 260
    property real maxWidth: 700
    property real maxHeight: 900
    property real minAspect: 0.65
    property real maxAspect: 1.15
    property bool isRound: false

    readonly property bool isSpecialDay: Lunar.lunarDay === 1 || Lunar.lunarDay === 15 || (Lunar.festival && Lunar.festival !== "")
    readonly property color accentColor: isSpecialDay ? (Lunar.lunarDay === 1 ? ThemeBackend.red : (Lunar.lunarDay === 15 ? ThemeBackend.yellow : ThemeBackend.peach)) : ThemeBackend.mauve

    // Responsive sizing helpers
    readonly property real sH: Math.max(0.6, Math.min(1.5, root.height / 360))
    readonly property real sW: Math.max(0.6, Math.min(1.5, root.width / 260))
    readonly property real sMin: Math.min(sH, sW)

    Rectangle {
        id: cardBody
        anchors.fill: parent
        color: ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        border.color: root.isSpecialDay ? Qt.alpha(root.accentColor, 0.45) : Qt.alpha(ThemeBackend.surface1, 0.7)
        border.width: 1
        antialiasing: true

        Behavior on border.color { ColorAnimation { duration: 250 } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 1. Classic Calendar "Binder / Nẹp Treo" Top Ribbon
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(34, Math.min(52, 42 * root.sH))
                color: Qt.alpha(root.accentColor, 0.12)
                radius: ThemeBackend.borderRadius
                // Keep bottom corners square
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.radius
                    color: parent.color
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.alpha(root.accentColor, 0.25)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.max(10, 14 * root.sW)
                    anchors.rightMargin: Math.max(10, 14 * root.sW)
                    spacing: 8

                    // Month & Year display
                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(DateTime.now, "MMMM yyyy").toUpperCase()
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.max(11, Math.min(15, 13 * root.sMin))
                        font.weight: Font.Black
                        font.letterSpacing: 0.5
                        color: ThemeBackend.text
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Day of week pill badge
                    Rectangle {
                        implicitHeight: Math.max(20, Math.min(28, 24 * root.sH))
                        implicitWidth: dayNameText.implicitWidth + Math.max(12, 16 * root.sW)
                        radius: height / 2
                        color: {
                            let dayOfWeek = DateTime.now.getDay();
                            if (dayOfWeek === 0) return Qt.alpha(ThemeBackend.peach, 0.25); // Sunday
                            if (dayOfWeek === 6) return Qt.alpha(ThemeBackend.mauve, 0.25); // Saturday
                            return Qt.alpha(ThemeBackend.surface1, 0.8);
                        }
                        border.color: {
                            let dayOfWeek = DateTime.now.getDay();
                            if (dayOfWeek === 0) return Qt.alpha(ThemeBackend.peach, 0.5);
                            return Qt.alpha(ThemeBackend.surface2, 0.6);
                        }
                        border.width: 1

                        Text {
                            id: dayNameText
                            anchors.centerIn: parent
                            text: DateTime.dayName.toUpperCase()
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(9, Math.min(12, 10.5 * root.sMin))
                            font.weight: Font.Black
                            color: {
                                let dayOfWeek = DateTime.now.getDay();
                                if (dayOfWeek === 0) return ThemeBackend.peach;
                                return ThemeBackend.text;
                            }
                        }
                    }
                }
            }

            // Main Content Area inside the calendar block
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Math.max(10, Math.min(20, 14 * root.sMin))
                spacing: Math.max(6, Math.min(14, 10 * root.sH))

                // 2. Hero Solar Day (Large central numeral)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Math.max(65, 95 * root.sH)

                    Text {
                        id: solarDayNumber
                        anchors.centerIn: parent
                        text: DateTime.day
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.min(parent.width * 0.78, parent.height * 0.95)
                        font.weight: Font.Black
                        color: root.isSpecialDay ? root.accentColor : ThemeBackend.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // 3. Festival Banner (Visible only if special occasion)
                Rectangle {
                    visible: Lunar.festival !== ""
                    Layout.fillWidth: true
                    implicitHeight: Math.max(22, 26 * root.sH)
                    radius: Math.max(4, ThemeBackend.borderRadius - 2)
                    color: Qt.alpha(root.accentColor, 0.16)
                    border.color: Qt.alpha(root.accentColor, 0.45)
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: ""
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.max(9, Math.min(12, 11 * root.sMin))
                            color: root.accentColor
                        }
                        Text {
                            text: Lunar.festival
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(9, Math.min(12, 11 * root.sMin))
                            font.weight: Font.Black
                            color: root.accentColor
                            elide: Text.ElideRight
                        }
                        Text {
                            text: ""
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.max(9, Math.min(12, 11 * root.sMin))
                            color: root.accentColor
                        }
                    }
                }

                // 4. Lunar Date Core Card (Elevated Focus Area)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(56, Math.min(84, 68 * root.sH))
                    radius: Math.max(6, ThemeBackend.borderRadius - 2)
                    color: ThemeBackend.surface1
                    border.color: Qt.alpha(root.accentColor, 0.28)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.max(8, 10 * root.sMin)
                        spacing: Math.max(8, 12 * root.sW)

                        // Moon Phase Icon Badge
                        Rectangle {
                            implicitWidth: Math.max(34, Math.min(46, 40 * root.sMin))
                            implicitHeight: implicitWidth
                            radius: implicitWidth / 2
                            color: Qt.alpha(root.accentColor, 0.15)
                            border.color: Qt.alpha(root.accentColor, 0.3)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: Lunar.moonPhaseIcon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: Math.max(16, Math.min(22, 19 * root.sMin))
                                color: root.accentColor
                            }
                        }

                        // Lunar Date & Can Chi Information
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            // Lunar day & month name
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: {
                                        if (Lunar.lunarDay === 1) return "MÙNG 1";
                                        if (Lunar.lunarDay === 15) return "RẰM 15";
                                        return "NGÀY " + Lunar.lunarDay;
                                    }
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Math.max(12, Math.min(16, 14 * root.sMin))
                                    font.weight: Font.Black
                                    color: root.isSpecialDay ? root.accentColor : ThemeBackend.text
                                }

                                Text {
                                    text: "• " + Lunar.monthName.toUpperCase() + (Lunar.isLeap ? " (NHUẬN)" : "")
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Math.max(10.5, Math.min(14, 12.5 * root.sMin))
                                    font.weight: Font.Bold
                                    color: ThemeBackend.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Can Chi (Năm)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: "Năm " + Lunar.canChiYear
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Math.max(8.5, Math.min(11, 9.5 * root.sMin))
                                    font.weight: Font.Medium
                                    color: ThemeBackend.subtext0
                                }

                                Text {
                                    text: "• " + Lunar.animal
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: Math.max(8.5, Math.min(11, 9.5 * root.sMin))
                                    font.weight: Font.DemiBold
                                    color: ThemeBackend.subtext1
                                    visible: Lunar.animal !== ""
                                }
                            }

                            // Can Chi (Tháng & Ngày)
                            Text {
                                Layout.fillWidth: true
                                text: "Tháng " + Lunar.canChiMonth + " • Ngày " + Lunar.canChiDay
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Math.max(7.5, Math.min(10, 8.5 * root.sMin))
                                font.weight: Font.Medium
                                color: ThemeBackend.subtext0
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
