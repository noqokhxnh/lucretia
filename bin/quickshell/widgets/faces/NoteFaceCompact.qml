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
    property real minHeight: 100
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.8
    property real maxAspect: 2.8
    property bool isRound: false

    property string wImagePath: ""
    property string currentNoteId: ""
    readonly property string effectiveNoteId: {
        if (wImagePath && wImagePath !== "") return wImagePath;
        if (currentNoteId && currentNoteId !== "") return currentNoteId;
        return Notes.activeNoteId || "";
    }
    onWImagePathChanged: {
        if (wImagePath && wImagePath !== "") {
            currentNoteId = wImagePath;
        }
    }

    readonly property var currentNote: (Notes.revision, Notes.getNote(effectiveNoteId))
    readonly property var tasks: (Notes.revision, Notes.parseTasks(currentNote ? currentNote.content : ""))
    readonly property int totalTasks: {
        let count = 0;
        for (let i = 0; i < tasks.length; i++) {
            if (tasks[i].isTask) count++;
        }
        return count;
    }
    readonly property int completedTasks: {
        let count = 0;
        for (let i = 0; i < tasks.length; i++) {
            if (tasks[i].isTask && tasks[i].checked) count++;
        }
        return count;
    }
    readonly property real progress: totalTasks > 0 ? (completedTasks / totalTasks) : 0

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    function getNoteTitle() {
        if (!currentNote || !currentNote.content) return I18n.t("widgets.types.note");
        let lines = currentNote.content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let t = lines[i].trim().replace(/^#+\s*/, "").replace(/^[-*•]\s*(\[[ xXvV]\]\s*)?/, "").trim();
            if (t.length > 0) {
                return t.length > 18 ? (t.substring(0, 16) + "…") : t;
            }
        }
        return I18n.t("widgets.types.note");
    }

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.surface0
        radius: ThemeBackend.borderRadius * 1.5
        border.color: Qt.alpha(ThemeBackend.surface1, 0.8)
        border.width: 1
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: s(10)
            spacing: s(6)

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: s(6)

                Text {
                    text: "󰠮"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(15)
                    color: ThemeBackend.mauve
                }

                Text {
                    text: root.getNoteTitle()
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: s(11)
                    font.bold: true
                    color: ThemeBackend.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: root.totalTasks > 0
                    implicitWidth: countText.implicitWidth + s(10)
                    implicitHeight: s(18)
                    radius: height / 2
                    color: root.completedTasks === root.totalTasks ? Qt.alpha(ThemeBackend.green, 0.2) : Qt.alpha(ThemeBackend.mauve, 0.15)
                    border.color: root.completedTasks === root.totalTasks ? Qt.alpha(ThemeBackend.green, 0.5) : Qt.alpha(ThemeBackend.mauve, 0.3)
                    border.width: 1

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.completedTasks + "/" + root.totalTasks
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: s(9)
                        font.bold: true
                        color: root.completedTasks === root.totalTasks ? ThemeBackend.green : ThemeBackend.mauve
                    }
                }

                IconButton {
                    size: s(20)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰅂"
                    iconFontSize: s(11)
                    accentColor: "transparent"
                    textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.subtext0
                    onClicked: Notes.openNotesPopup()
                }
            }

            // Task Items
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: s(4)

                Repeater {
                    model: {
                        let filtered = [];
                        for (let i = 0; i < root.tasks.length; i++) {
                            if (root.tasks[i].isTask) {
                                filtered.push(root.tasks[i]);
                                if (filtered.length >= 4) break;
                            }
                        }
                        return filtered;
                    }

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: s(6)

                        Rectangle {
                            Layout.preferredWidth: s(15)
                            Layout.preferredHeight: s(15)
                            Layout.alignment: Qt.AlignVCenter
                            radius: s(4)
                            color: modelData.checked ? ThemeBackend.mauve : (cbMouseArea.containsMouse ? Qt.alpha(ThemeBackend.mauve, 0.15) : "transparent")
                            border.color: modelData.checked ? ThemeBackend.mauve : ThemeBackend.surface2
                            border.width: 1.2
                            antialiasing: true

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(9)
                                font.bold: true
                                color: ThemeBackend.crust
                                visible: modelData.checked
                            }

                            MouseArea {
                                id: cbMouseArea
                                anchors.fill: parent
                                anchors.margins: -s(3)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Notes.toggleTask(root.effectiveNoteId, modelData.lineIndex);
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(11)
                            font.strikeout: modelData.checked
                            color: modelData.checked ? ThemeBackend.overlay0 : ThemeBackend.text
                            elide: Text.ElideRight

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Notes.toggleTask(root.effectiveNoteId, modelData.lineIndex);
                                }
                            }
                        }
                    }
                }

                // Placeholder if no tasks
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.totalTasks === 0

                    Text {
                        anchors.centerIn: parent
                        text: I18n.t("notes.no_tasks")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: s(11)
                        color: ThemeBackend.overlay0
                    }
                }
            }

            // Bottom Mini Progress Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.totalTasks > 0 ? 2 : 0
                color: Qt.alpha(ThemeBackend.surface1, 0.6)
                radius: 1
                visible: root.totalTasks > 0

                Rectangle {
                    height: parent.height
                    width: parent.width * root.progress
                    color: root.completedTasks === root.totalTasks ? ThemeBackend.green : ThemeBackend.mauve
                    radius: 1
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }
        }
    }
}
