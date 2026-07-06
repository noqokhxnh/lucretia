import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    MatugenColors { id: _theme }
    
    readonly property color base: _theme.base
    readonly property color text: _theme.text
    readonly property color crust: _theme.crust
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color red: _theme.red || "#f38ba8"

    property string backendScript: Quickshell.env("HOME") + "/.config/niri/scripts/quickshell/notes/notes_backend"
    property string tempFile: Quickshell.env("HOME") + "/.cache/qs_note_current.txt"

    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 600; easing.type: Easing.OutExpo; running: true 
    }

    property string currentNoteId: ""
    property bool isSaving: false
    property bool isInitialLoad: true
    property bool isDirty: false
    property bool isProgrammaticTextChange: false



    Component.onCompleted: {
        loadNotes();
    }

    ListModel {
        id: notesModel
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                introPhaseAnim.restart();
                loadNotes();
            } else {
                saveCurrentNote();
            }
        }
    }

    Process {
        id: listProcess
        command: [window.backendScript, "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let items = JSON.parse(this.text);
                    notesModel.clear();
                    for (let i = 0; i < items.length; i++) {
                        notesModel.append(items[i]);
                    }
                    if (window.isInitialLoad && items.length > 0) {
                        selectNote(items[0].id, items[0].content);
                        window.isInitialLoad = false;
                    } else if (items.length === 0) {
                        textArea.text = "";
                        window.currentNoteId = "";
                    }
                } catch(e) {
                    console.log("Error parsing notes:", e);
                }
            }
        }
    }

    Process {
        id: addProcess
        command: [window.backendScript, "add"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let newId = this.text.trim();
                if (newId) {
                    window.currentNoteId = newId;
                    textArea.text = "";
                    loadNotes();
                    textArea.forceActiveFocus();
                }
            }
        }
    }

    Process {
        id: deleteProcess
        running: false
        onExited: {
            loadNotes();
        }
    }

    Process {
        id: updateProcess
        running: false
        onExited: {
            window.isSaving = false;
            loadNotes(); // Reload the list to update snippets in the sidebar
        }
    }

    function loadNotes() {
        listProcess.running = true;
    }

    function createNote() {
        saveCurrentNote();
        addProcess.running = true;
    }

    function deleteNote(id) {
        if (window.currentNoteId === id) {
            window.currentNoteId = "";
            textArea.text = "";
        }
        deleteProcess.command = [window.backendScript, "delete", id];
        deleteProcess.running = true;
    }

    function selectNote(id, content) {
        saveCurrentNote();
        window.currentNoteId = id;
        window.isProgrammaticTextChange = true;
        textArea.text = content;
        window.isProgrammaticTextChange = false;
        window.isDirty = false;
        // Don't trigger save immediately on load
        saveTimer.stop();
    }

    function saveCurrentNote() {
        if (window.currentNoteId === "" || !window.isDirty) return;
        window.isSaving = true;
        window.isDirty = false;
        let escapedText = textArea.text.replace(/'/g, "'\\''");
        let writeCmd = "echo -n '" + escapedText + "' > " + window.tempFile + " && " + window.backendScript + " update " + window.currentNoteId + " " + window.tempFile;
        updateProcess.command = ["bash", "-c", writeCmd];
        updateProcess.running = true;
    }

    Timer {
        id: saveTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            saveCurrentNote();
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: 16
        color: window.base
        border.color: window.surface1
        border.width: 1
        clip: true

        transform: Translate { y: (window.introPhase - 1) * 60 }
        opacity: window.introPhase

        OrbitBackground {
            color1: window.mauve
            color2: window.mauve
            opacity1: 0.06
            opacity2: 0.04
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Sidebar
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                color: window.crust

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Sidebar Header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        color: "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: "My Notes"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: window.mauve
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: 10
                            color: btnMa.containsMouse ? window.mauve : window.surface1
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰐙" // Nerd font plus icon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: btnMa.containsMouse ? window.crust : window.text
                            }

                            MouseArea {
                                id: btnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: createNote()
                            }
                        }
                    }

                    // Notes List
                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: notesModel
                        spacing: 8
                        topMargin: 10
                        bottomMargin: 10

                        delegate: Rectangle {
                            width: listView.width - 32
                            anchors.horizontalCenter: listView.horizontalCenter
                            height: 80
                            radius: 14
                            color: window.currentNoteId === model.id ? window.surface1 : (ma.containsMouse ? window.surface0 : "transparent")
                            border.color: window.currentNoteId === model.id ? window.mauve : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Preview Text
                            Column {
                                anchors.left: parent.left
                                anchors.right: deleteBtn.left
                                anchors.margins: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: model.content.trim() === "" ? "Untitled Note" : model.content.split('\n')[0]
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 15
                                    font.weight: window.currentNoteId === model.id ? Font.Bold : Font.Normal
                                    color: window.currentNoteId === model.id ? window.mauve : window.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: {
                                        let lines = model.content.split('\n');
                                        if (lines.length > 1) return lines[1];
                                        return "No additional text";
                                    }
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 12
                                    color: window.surface2
                                    elide: Text.ElideRight
                                }
                            }

                            // Delete Button
                            Rectangle {
                                id: deleteBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 15
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                radius: 6
                                color: "transparent"
                                opacity: ma.containsMouse || window.currentNoteId === model.id ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴" // Nerd font trash icon
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 14
                                    color: delMa.containsMouse ? window.red : window.surface2
                                }

                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        deleteNote(model.id);
                                    }
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                anchors.rightMargin: 40 // keep delete button clickable
                                hoverEnabled: true
                                onClicked: {
                                    if (window.currentNoteId !== model.id) {
                                        selectNote(model.id, model.content);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: window.surface1
            }

                // Main Editor
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 24
                        radius: 18
                        color: window.surface0
                        border.color: window.surface1
                        border.width: 1

                        ScrollView {
                            anchors.fill: parent
                            clip: true
                            
                            TextArea {
                                id: textArea
                                text: ""
                                color: window.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: 16
                                wrapMode: TextEdit.Wrap
                                padding: 24
                                background: Item {}
                                enabled: window.currentNoteId !== ""
                                
                                placeholderText: window.currentNoteId !== "" ? "Start writing your thoughts..." : "Select a note to view or edit"
                                placeholderTextColor: window.surface2

                                onTextChanged: {
                                    if (window.isProgrammaticTextChange) return;
                                    if (window.currentNoteId !== "" && textArea.focus) {
                                        window.isDirty = true;
                                        saveTimer.restart();
                                    }
                                }

                                Keys.onEscapePressed: {
                                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/scripts/qs_manager.sh", "close"]);
                                    event.accepted = true;
                                }
                            }
                        }

                        // Saving indicator
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 10
                            text: window.isSaving ? "Saving..." : "Saved"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            color: window.surface2
                            opacity: window.currentNoteId !== "" ? 1 : 0
                        }
                    }
                }
            }
        }
}
