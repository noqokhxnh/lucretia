import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var barWindow
    required property var mocha

    implicitWidth: wsRow.implicitWidth
    implicitHeight: wsRow.implicitHeight

    Row {
        id: wsRow
        spacing: root.barWindow.s(4)

        Repeater {
            model: root.barWindow.workspaceCount

            delegate: Rectangle {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: root.barWindow.activeWorkspaceId === wsId
                readonly property bool isOccupied: root.barWindow.occupiedWorkspaceIds.indexOf(wsId) !== -1

                width: isActive ? root.barWindow.s(28) : root.barWindow.s(10)
                height: root.barWindow.s(10)
                radius: root.barWindow.s(5)
                color: isActive ? root.mocha.blue : (isOccupied ? root.mocha.subtext0 : root.mocha.surface1)

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.barWindow.sh("~/.config/niri/bin/qs_manager.sh " + wsId)
                }
            }
        }
    }
}
