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

    property real minWidth: 220
    property real minHeight: 180
    property real maxWidth: 900
    property real maxHeight: 1200
    property real minAspect: 0.5
    property real maxAspect: 2.6
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

    property real savedScrollY: 0
    property string pendingScrollAction: ""

    onTasksChanged: {
        if (pendingScrollAction === "end") {
            Qt.callLater(() => {
                taskListView.positionViewAtEnd();
                pendingScrollAction = "";
                savedScrollY = taskListView.contentY;
            });
        } else if (pendingScrollAction === "preserve" || savedScrollY > 0) {
            let targetY = savedScrollY;
            Qt.callLater(() => {
                let maxY = Math.max(0, taskListView.contentHeight - taskListView.height + taskListView.topMargin + taskListView.bottomMargin);
                taskListView.contentY = Math.min(maxY, Math.max(-taskListView.topMargin, targetY));
                pendingScrollAction = "";
            });
        }
    }

    property bool wantsKeyboardFocus: true

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    function getNoteTitle() {
        if (!currentNote || !currentNote.content) return I18n.t("widgets.types.note");
        let lines = currentNote.content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let t = lines[i].trim().replace(/^#+\s*/, "").replace(/^[-*•]\s*(\[[ xXvV]\]\s*)?/, "").trim();
            if (t.length > 0) {
                return t.length > 22 ? (t.substring(0, 20) + "…") : t;
            }
        }
        return I18n.t("widgets.types.note");
    }

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: ThemeBackend.surface0
        radius: ThemeBackend.borderRadius * 1.5
        border.color: Qt.alpha(ThemeBackend.surface1, 0.8)
        border.width: 1
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 1. Header Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(36, s(42))
                color: Qt.alpha(ThemeBackend.surface1, 0.45)
                radius: ThemeBackend.borderRadius * 1.5

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
                    color: Qt.alpha(ThemeBackend.surface2, 0.5)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: s(12)
                    anchors.rightMargin: s(10)
                    spacing: s(8)

                    // Note Icon
                    Text {
                        text: "󰠮"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: s(16)
                        color: ThemeBackend.mauve
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Note Switcher / Title
                    RowLayout {
                        spacing: s(4)
                        Layout.alignment: Qt.AlignVCenter

                        // Prev Note
                        IconButton {
                            size: s(22)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "‹"
                            iconFontSize: s(14)
                            accentColor: "transparent"
                            textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.subtext0
                            visible: Notes.count > 1
                            onClicked: {
                                root.savedScrollY = -taskListView.topMargin;
                                root.pendingScrollAction = "top";
                                let prev = Notes.prevNote(root.effectiveNoteId);
                                if (prev) root.currentNoteId = prev.id;
                            }
                        }

                        Text {
                            text: root.getNoteTitle()
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(12)
                            font.bold: true
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            Layout.maximumWidth: s(110)
                        }

                        // Next Note
                        IconButton {
                            size: s(22)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "›"
                            iconFontSize: s(14)
                            accentColor: "transparent"
                            textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.subtext0
                            visible: Notes.count > 1
                            onClicked: {
                                root.savedScrollY = -taskListView.topMargin;
                                root.pendingScrollAction = "top";
                                let next = Notes.nextNote(root.effectiveNoteId);
                                if (next) root.currentNoteId = next.id;
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Progress Pill Badge
                    Rectangle {
                        visible: root.totalTasks > 0
                        implicitWidth: progressText.implicitWidth + s(14)
                        implicitHeight: s(20)
                        radius: height / 2
                        color: root.completedTasks === root.totalTasks ? Qt.alpha(ThemeBackend.green, 0.2) : Qt.alpha(ThemeBackend.mauve, 0.15)
                        border.color: root.completedTasks === root.totalTasks ? Qt.alpha(ThemeBackend.green, 0.5) : Qt.alpha(ThemeBackend.mauve, 0.3)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: s(4)

                            Text {
                                id: progressText
                                text: root.completedTasks + "/" + root.totalTasks
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(10)
                                font.bold: true
                                color: root.completedTasks === root.totalTasks ? ThemeBackend.green : ThemeBackend.mauve
                            }
                        }
                    }

                    // Open Full Notes Popup Button
                    IconButton {
                        size: s(24)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰅂"
                        iconFontSize: s(13)
                        accentColor: "transparent"
                        textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.subtext0
                        onClicked: Notes.openNotesPopup()
                    }
                }
            }

            // Mini Progress Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.totalTasks > 0 ? 2 : 0
                color: Qt.alpha(ThemeBackend.surface1, 0.5)
                visible: root.totalTasks > 0

                Rectangle {
                    height: parent.height
                    width: parent.width * root.progress
                    color: root.completedTasks === root.totalTasks ? ThemeBackend.green : ThemeBackend.mauve
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }

            // 2. Checklist Items List
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: taskListView
                    anchors.fill: parent
                    anchors.topMargin: s(6)
                    anchors.bottomMargin: s(6)
                    anchors.leftMargin: s(12)
                    anchors.rightMargin: s(12)
                    spacing: s(6)
                    model: root.tasks
                    boundsBehavior: Flickable.StopAtBounds

                    onContentYChanged: {
                        if (root.pendingScrollAction === "" && (moving || dragging || flicking || contentY > 0)) {
                            root.savedScrollY = contentY;
                        }
                    }

                    delegate: Item {
                        id: taskDelegate
                        width: taskListView.width
                        height: modelData.isHeading ? s(26) : Math.max(s(28), taskRow.implicitHeight + s(4))

                        property bool isHovered: itemMouseArea.containsMouse

                        Rectangle {
                            anchors.fill: parent
                            radius: s(6)
                            color: taskDelegate.isHovered ? Qt.alpha(ThemeBackend.surface1, 0.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Heading Row
                        Text {
                            visible: modelData.isHeading
                            anchors.left: parent.left
                            anchors.leftMargin: s(4)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(12)
                            font.bold: true
                            color: ThemeBackend.mauve
                        }

                        // Task Row
                        RowLayout {
                            id: taskRow
                            visible: !modelData.isHeading
                            anchors.fill: parent
                            anchors.leftMargin: s(4)
                            anchors.rightMargin: s(6)
                            spacing: s(8)

                            // Checkbox
                            Rectangle {
                                id: checkboxBox
                                Layout.preferredWidth: s(18)
                                Layout.preferredHeight: s(18)
                                Layout.alignment: Qt.AlignVCenter
                                radius: s(5)
                                color: modelData.checked ? ThemeBackend.mauve : (checkboxMouseArea.containsMouse ? Qt.alpha(ThemeBackend.mauve, 0.15) : "transparent")
                                border.color: modelData.checked ? ThemeBackend.mauve : (checkboxMouseArea.containsMouse ? ThemeBackend.mauve : ThemeBackend.surface2)
                                border.width: 1.5
                                antialiasing: true

                                scale: checkboxMouseArea.pressed ? 0.85 : 1.0
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: s(11)
                                    font.bold: true
                                    color: ThemeBackend.crust
                                    visible: modelData.checked
                                }

                                MouseArea {
                                    id: checkboxMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -s(4)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.savedScrollY = taskListView.contentY;
                                        root.pendingScrollAction = "preserve";
                                        Notes.toggleTask(root.effectiveNoteId, modelData.lineIndex);
                                    }
                                }
                            }

                            // Task Text
                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(12)
                                font.strikeout: modelData.checked
                                color: modelData.checked ? ThemeBackend.overlay1 : ThemeBackend.text
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: textMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.savedScrollY = taskListView.contentY;
                                        root.pendingScrollAction = "preserve";
                                        Notes.toggleTask(root.effectiveNoteId, modelData.lineIndex);
                                    }
                                }
                            }

                            // Delete Task Button (appears on hover)
                            IconButton {
                                Layout.preferredWidth: s(20)
                                Layout.preferredHeight: s(20)
                                Layout.alignment: Qt.AlignVCenter
                                cornerRadius: s(4)
                                buttonIcon: "×"
                                iconFontSize: s(13)
                                accentColor: "transparent"
                                textColor: isHoveredOrHighlighted ? ThemeBackend.red : ThemeBackend.overlay0
                                opacity: taskDelegate.isHovered ? 1.0 : 0.0
                                visible: taskDelegate.isHovered
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                onClicked: {
                                    root.savedScrollY = taskListView.contentY;
                                    root.pendingScrollAction = "preserve";
                                    Notes.deleteTask(root.effectiveNoteId, modelData.lineIndex);
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }

                    // Empty State
                    Item {
                        anchors.centerIn: parent
                        width: parent.width - s(30)
                        height: emptyCol.implicitHeight
                        visible: root.tasks.length === 0

                        ColumnLayout {
                            id: emptyCol
                            anchors.centerIn: parent
                            spacing: s(6)

                            Text {
                                text: "󰄲"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(28)
                                color: ThemeBackend.overlay0
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: I18n.t("notes.no_tasks")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(12)
                                font.bold: true
                                color: ThemeBackend.subtext0
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: I18n.t("notes.add_task")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(10)
                                color: ThemeBackend.overlay1
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            // 3. Quick Add Bar at Bottom
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(34, s(38))
                color: Qt.alpha(ThemeBackend.surface1, 0.35)
                radius: ThemeBackend.borderRadius * 1.5

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.radius
                    color: parent.color
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.alpha(ThemeBackend.surface2, 0.4)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: s(10)
                    anchors.rightMargin: s(6)
                    spacing: s(6)

                    Text {
                        text: "󰐕"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: s(14)
                        color: addInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.subtext0
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: addInput.forceActiveFocus()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: addInput.forceActiveFocus()
                        }

                        TextInput {
                            id: addInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(11)
                            color: ThemeBackend.text
                            clip: true
                            selectByMouse: true

                            Text {
                                text: I18n.t("notes.add_task")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: s(11)
                                color: ThemeBackend.overlay0
                                visible: addInput.text.length === 0 && !addInput.activeFocus
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Keys.onEscapePressed: {
                                addInput.focus = false;
                            }

                            onAccepted: {
                                if (text.trim().length > 0) {
                                    root.pendingScrollAction = "end";
                                    Notes.addTask(root.effectiveNoteId, text);
                                    text = "";
                                }
                            }
                        }
                    }

                    IconButton {
                        size: s(24)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "↵"
                        iconFontSize: s(12)
                        accentColor: addInput.text.trim().length > 0 ? ThemeBackend.mauve : "transparent"
                        textColor: addInput.text.trim().length > 0 ? ThemeBackend.crust : ThemeBackend.overlay1
                        enabled: addInput.text.trim().length > 0
                        onClicked: {
                            if (addInput.text.trim().length > 0) {
                                root.pendingScrollAction = "end";
                                Notes.addTask(root.effectiveNoteId, addInput.text);
                                addInput.text = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
