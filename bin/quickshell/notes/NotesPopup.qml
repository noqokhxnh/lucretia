import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    implicitWidth: window.s(920)
    implicitHeight: window.s(640)

    function s(val) {
        return Scaler.s(val);
    }

    MatugenColors { id: _theme }
    
    readonly property color base: _theme.base
    readonly property color text: _theme.text
    readonly property color crust: _theme.crust
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color red: _theme.red || "#f38ba8"

    property string backendScript: Quickshell.env("HOME") + "/.config/niri/bin/quickshell/notes/notes_backend"
    property string tempFile: Quickshell.env("HOME") + "/.cache/qs_note_current.txt"

    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 600; easing.type: Easing.OutExpo; running: true 
    }

    // Pin & Drag
    property bool isPinned: false
    property bool isMinimized: false
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragStartMouseX: 0
    property real dragStartMouseY: 0
    property real dragStartOffsetX: 0
    property real dragStartOffsetY: 0
    property bool isDragging: false

    onIsPinnedChanged: {
        let shellPath = Quickshell.env("HOME") + "/.config/niri/bin/quickshell/Shell.qml";
        Quickshell.execDetached(["quickshell", "-p", shellPath, "ipc", "call", "main", "setWidgetPinned", isPinned ? "true" : "false"]);
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
                if (window.isMinimized) {
                    window.isMinimized = false;
                }
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
        id: card
        anchors.fill: parent
        radius: window.s(16)
        color: window.base
        border.color: window.surface1
        border.width: 1
        clip: true

        transform: Translate { y: (window.introPhase - 1) * window.s(60) }
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
                Layout.preferredWidth: window.s(280)
                Layout.fillHeight: true
                color: window.crust

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Sidebar Header — draggable title bar with pin & create
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(60)
                        color: dragHandle.containsMouse || dragHandle.pressed ? window.surface0 : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Title text
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: window.s(20)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "My Notes"
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(18)
                            font.weight: Font.Bold
                            color: window.mauve
                        }

                        // Pin button — always visible (opacity shows state)
                        Rectangle {
                            id: pinBtn
                            anchors.right: createBtn.left
                            anchors.rightMargin: window.s(8)
                            anchors.verticalCenter: parent.verticalCenter
                            width: window.s(32)
                            height: window.s(32)
                            radius: window.s(8)
                            color: pinMa.containsMouse ? (window.isPinned ? window.mauve : window.surface1) : (window.isPinned ? window.mauve : "transparent")
                            Behavior on color { ColorAnimation { duration: 200 } }
                            opacity: window.isPinned ? 1.0 : (pinMa.containsMouse ? 0.8 : 0.35)
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: window.isPinned ? "󰐃" : "󰐐" // filled pin / unfilled pin (Nerd Font)
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(15)
                                color: pinMa.containsMouse ? window.crust : window.text
                            }

                            MouseArea {
                                id: pinMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    window.isPinned = !window.isPinned;
                                }
                            }
                        }

                        // Create note button
                        Rectangle {
                            id: createBtn
                            anchors.right: parent.right
                            anchors.rightMargin: window.s(16)
                            anchors.verticalCenter: parent.verticalCenter
                            width: window.s(32)
                            height: window.s(32)
                            radius: window.s(8)
                            color: createMa.containsMouse ? window.mauve : window.surface1
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰐙" // Nerd font plus icon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(16)
                                font.weight: Font.Bold
                                color: createMa.containsMouse ? window.crust : window.text
                            }

                            MouseArea {
                                id: createMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: createNote()
                            }
                        }

                        // Drag handle — moves entire window (like PhotoBooth)
                        MouseArea {
                            id: dragHandle
                            anchors.fill: parent
                            anchors.rightMargin: window.s(96) // leave room for pin + create buttons
                            hoverEnabled: true
                            cursorShape: Qt.SizeAllCursor

                            property real lastGx: 0
                            property real lastGy: 0

                            onPressed: function(mouse) {
                                let gp = mapToItem(null, mouse.x, mouse.y);
                                lastGx = gp.x;
                                lastGy = gp.y;
                                masterWindow.disableMorph = true;
                                window.isDragging = true;
                            }
                            onPositionChanged: function(mouse) {
                                if (!window.isDragging) return;
                                let gp = mapToItem(null, mouse.x, mouse.y);
                                let dx = gp.x - lastGx;
                                let dy = gp.y - lastGy;
                                masterWindow._animX += dx;
                                masterWindow._animY += dy;
                                lastGx = gp.x;
                                lastGy = gp.y;
                            }
                            onReleased: function(mouse) {
                                masterWindow.disableMorph = false;
                                window.isDragging = false;
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
                        spacing: window.s(8)
                        topMargin: window.s(10)
                        bottomMargin: window.s(10)

                        delegate: Rectangle {
                            width: listView.width - window.s(24)
                            anchors.horizontalCenter: listView.horizontalCenter
                            height: window.s(72)
                            radius: window.s(12)
                            color: window.currentNoteId === model.id ? window.surface1 : (ma.containsMouse ? window.surface0 : "transparent")
                            border.color: window.currentNoteId === model.id ? window.mauve : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Preview Text
                            Column {
                                anchors.left: parent.left
                                anchors.right: deleteBtn.left
                                anchors.margins: window.s(12)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: window.s(4)

                                Text {
                                    width: parent.width
                                    text: model.content.trim() === "" ? "Untitled Note" : model.content.split('\n')[0]
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(14)
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
                                    font.pixelSize: window.s(11.5)
                                    color: window.surface2
                                    elide: Text.ElideRight
                                }
                            }

                            // Delete Button
                            Rectangle {
                                id: deleteBtn
                                anchors.right: parent.right
                                anchors.rightMargin: window.s(10)
                                anchors.verticalCenter: parent.verticalCenter
                                width: window.s(22)
                                height: window.s(22)
                                radius: window.s(6)
                                color: "transparent"
                                opacity: ma.containsMouse || window.currentNoteId === model.id ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴" // Nerd font trash icon
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(13)
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
                                anchors.rightMargin: window.s(36) // keep delete button clickable
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
                    anchors.margins: window.s(16)
                    radius: window.s(16)
                    color: window.surface0
                    border.color: window.surface1
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.bottomMargin: window.s(28)
                        clip: true
                        
                        TextArea {
                            id: textArea
                            text: ""
                            color: window.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(15)
                            wrapMode: TextEdit.Wrap
                            padding: window.s(18)
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
                                if (window.isPinned) {
                                    window.isMinimized = true;
                                    // Minimize without clearing the stack (keeps loaded for restore)
                                    let shellPath = Quickshell.env("HOME") + "/.config/niri/bin/quickshell/Shell.qml";
                                    Quickshell.execDetached(["quickshell", "-p", shellPath, "ipc", "call", "main", "hideWidget", ""]);
                                } else {
                                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    // Bottom bar: pinned badge + saving indicator
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: window.s(8)
                        spacing: window.s(10)

                        // Pinned badge
                        Text {
                            text: "󰐃 Pinned"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(11.5)
                            color: window.mauve
                            visible: window.isPinned
                            opacity: window.currentNoteId !== "" ? 1 : 0
                        }

                        // Saving indicator
                        Text {
                            text: window.isSaving ? "Saving..." : "Saved"
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(11.5)
                            color: window.surface2
                            opacity: window.currentNoteId !== "" ? 1 : 0
                        }
                    }
                }
            }
        }
    }
}
