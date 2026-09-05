pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    readonly property string backendScript: Caching.qsDir + "/notes/notes_backend"
    readonly property string notesPath: (Quickshell.env("HOME") || "/home/khxnh") + "/.local/share/quickshell/notes.json"
    readonly property string tempFile: (Caching.runDir ? Caching.runDir : "/tmp") + "/qs_note_sync.txt"

    property var notes: []
    property int count: notes ? notes.length : 0
    property string activeNoteId: ""
    readonly property var activeNote: getNote(activeNoteId)
    property bool isReady: false
    property int revision: 0
    property real lastSelfSaveTime: 0

    signal notesUpdated()

    FileView {
        id: notesFileWatcher
        path: root.notesPath
        watchChanges: true
        onLoaded: {
            if (Date.now() - root.lastSelfSaveTime < 1500) {
                root.syncDiskTimestamps();
                return;
            }
            root.reload();
        }
    }

    Component.onCompleted: {
        root.reload();
    }

    function syncDiskTimestamps() {
        try {
            let txt = notesFileWatcher.text().trim();
            if (txt && txt.length > 0) {
                let parsed = JSON.parse(txt);
                if (Array.isArray(parsed) && root.notes) {
                    for (let i = 0; i < parsed.length; i++) {
                        let item = parsed[i];
                        let local = root.notes.find(n => n.id === item.id);
                        if (local) {
                            local.updated_at = item.updated_at;
                        }
                    }
                }
            }
        } catch (e) {}
    }

    function reload() {
        try {
            let txt = notesFileWatcher.text().trim();
            if (txt && txt.length > 0) {
                let parsed = JSON.parse(txt);
                if (Array.isArray(parsed)) {
                    if (!root.notes || root.notes.length === 0) {
                        parsed.sort((a, b) => (b.updated_at || 0) - (a.updated_at || 0));
                        root.notes = parsed;
                        if (!root.activeNoteId && parsed.length > 0) {
                            root.activeNoteId = parsed[0].id;
                        }
                    } else {
                        // Maintain existing stable note order so notes don't jump around
                        let orderMap = {};
                        for (let i = 0; i < root.notes.length; i++) {
                            orderMap[root.notes[i].id] = i;
                        }
                        parsed.sort((a, b) => {
                            let orderA = orderMap[a.id] !== undefined ? orderMap[a.id] : 9999;
                            let orderB = orderMap[b.id] !== undefined ? orderMap[b.id] : 9999;
                            return orderA - orderB;
                        });
                        root.notes = parsed;
                        if (!parsed.some(n => n.id === root.activeNoteId) && parsed.length > 0) {
                            root.activeNoteId = parsed[0].id;
                        }
                    }
                }
            } else {
                root.notes = [];
            }
        } catch (e) {
            console.log("Notes.qml reload parse error:", e);
        }
        root.isReady = true;
        root.revision++;
        root.notesUpdated();
    }

    function getNote(id) {
        if (!root.notes || root.notes.length === 0) return null;
        if (!id) return root.notes[0];
        let found = root.notes.find(n => n.id === id);
        return found ? found : root.notes[0];
    }

    function getNoteIndex(id) {
        if (!root.notes || root.notes.length === 0) return -1;
        if (!id) return 0;
        return root.notes.findIndex(n => n.id === id);
    }

    function nextNote(currentId) {
        if (!root.notes || root.notes.length <= 1) return root.getNote(currentId);
        let idx = root.getNoteIndex(currentId);
        let nextIdx = (idx + 1) % root.notes.length;
        return root.notes[nextIdx];
    }

    function prevNote(currentId) {
        if (!root.notes || root.notes.length <= 1) return root.getNote(currentId);
        let idx = root.getNoteIndex(currentId);
        let prevIdx = (idx - 1 + root.notes.length) % root.notes.length;
        return root.notes[prevIdx];
    }

    function parseTasks(content) {
        if (!content || typeof content !== "string") return [];
        let lines = content.split("\n");
        let tasks = [];

        const taskRegex = /^(\s*([-\*\+]|\d+[\.\)])?\s*\[)([ xXvV])(\]\s*)(.*)$/;
        const colonCheckRegex = /^(.*?)\s*[:;]\s*([vVxX])\s*$/;
        const separatorRegex = /^\s*[-=_*~]{3,}\s*$/;

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];
            let trimmed = line.trim();
            if (trimmed === "") continue;

            let m = line.match(taskRegex);
            if (m) {
                let checkChar = m[3].toLowerCase();
                tasks.push({
                    lineIndex: i,
                    text: m[5] ? m[5].trim() : "",
                    checked: (checkChar === "x" || checkChar === "v"),
                    isTask: true,
                    isHeading: false,
                    raw: line
                });
                continue;
            }

            let mColon = line.match(colonCheckRegex);
            if (mColon) {
                let status = mColon[2].toLowerCase();
                tasks.push({
                    lineIndex: i,
                    text: mColon[1] ? mColon[1].trim() : "",
                    checked: (status === "v"),
                    isTask: true,
                    isHeading: false,
                    raw: line
                });
                continue;
            }

            // Headings and Separators
            if (trimmed.startsWith("#") || separatorRegex.test(trimmed)) {
                tasks.push({
                    lineIndex: i,
                    text: trimmed.startsWith("#") ? trimmed.replace(/^#+\s*/, "") : "───",
                    checked: false,
                    isTask: false,
                    isHeading: true,
                    raw: line
                });
                continue;
            }

            // Plain text lines treated as task items
            tasks.push({
                lineIndex: i,
                text: trimmed.replace(/^[-*•]\s*/, ""),
                checked: false,
                isTask: true,
                isHeading: false,
                raw: line
            });
        }
        return tasks;
    }

    function toggleTask(noteId, lineIndex) {
        let note = getNote(noteId);
        if (!note || !note.content) return;

        let lines = note.content.split("\n");
        if (lineIndex < 0 || lineIndex >= lines.length) return;

        let line = lines[lineIndex];
        const taskRegex = /^(\s*([-\*\+]|\d+[\.\)])?\s*\[)([ xXvV])(\]\s*)(.*)$/;
        const colonCheckRegex = /^(.*?)\s*[:;]\s*([vVxX])\s*$/;

        let match = line.match(taskRegex);
        if (match) {
            let cur = match[3].toLowerCase();
            let isChecked = (cur === "x" || cur === "v");
            let nextCheck = isChecked ? " " : "x";
            lines[lineIndex] = match[1] + nextCheck + match[4] + match[5];
        } else {
            let mColon = line.match(colonCheckRegex);
            if (mColon) {
                let cur = mColon[2].toLowerCase();
                let isChecked = (cur === "v");
                let nextCheck = isChecked ? "X" : "V";
                lines[lineIndex] = mColon[1] + ": " + nextCheck;
            } else {
                // If it was plain line, turn into task line checked
                lines[lineIndex] = "- [x] " + line.trim().replace(/^[-*•]\s*/, "");
            }
        }

        let newContent = lines.join("\n");
        saveNoteContent(note.id, newContent);
    }

    function addTask(noteId, taskText) {
        let text = (taskText || "").trim();
        if (!text) return;

        let note = getNote(noteId);
        let taskLine = "- [ ] " + text;

        if (!note) {
            createNote(taskLine);
            return;
        }

        let newContent = note.content ? (note.content + "\n" + taskLine) : taskLine;
        saveNoteContent(note.id, newContent);
    }

    function deleteTask(noteId, lineIndex) {
        let note = getNote(noteId);
        if (!note || !note.content) return;

        let lines = note.content.split("\n");
        if (lineIndex < 0 || lineIndex >= lines.length) return;

        lines.splice(lineIndex, 1);
        let newContent = lines.join("\n");
        saveNoteContent(note.id, newContent);
    }

    function saveNoteContent(noteId, newContent) {
        if (!noteId) return;

        root.lastSelfSaveTime = Date.now();

        // Optimistic in-memory update with fresh object references
        if (root.notes) {
            let copy = [];
            let now = Date.now() / 1000;
            let found = false;
            for (let i = 0; i < root.notes.length; i++) {
                let item = root.notes[i];
                if (item.id === noteId) {
                    copy.push(Object.assign({}, item, {
                        content: newContent,
                        updated_at: now
                    }));
                    found = true;
                } else {
                    copy.push(item);
                }
            }
            if (!found) {
                copy.push({
                    id: noteId,
                    content: newContent,
                    created_at: now,
                    updated_at: now
                });
            }
            root.notes = copy;
            root.revision++;
            root.notesUpdated();
        }

        // Write to backend safely
        let tmp = (Caching.runDir ? Caching.runDir : "/tmp") + "/qs_note_" + noteId + ".txt";
        let escapedText = newContent.replace(/'/g, "'\\''");
        let writeCmd = "printf '%s' '" + escapedText + "' > '" + tmp + "' && '" + root.backendScript + "' update '" + noteId + "' '" + tmp + "' && rm -f '" + tmp + "'";
        Quickshell.execDetached(["bash", "-c", writeCmd]);
    }

    function createNote(initialContent) {
        let p = addProcessComponent.createObject(root, {
            initialContent: initialContent || ""
        });
        p.running = true;
    }

    function deleteNote(noteId) {
        if (!noteId) return;
        Quickshell.execDetached([root.backendScript, "delete", noteId]);
    }

    function openNotesPopup() {
        Quickshell.execDetached(["bash", "-c", "~/.config/niri/bin/qs_manager.sh toggle notes"]);
    }

    Component {
        id: addProcessComponent
        Process {
            id: p
            property string initialContent: ""
            command: [root.backendScript, "add"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let newId = this.text.trim();
                    if (newId) {
                        root.activeNoteId = newId;
                        if (p.initialContent) {
                            root.saveNoteContent(newId, p.initialContent);
                        }
                        root.reload();
                    }
                    p.destroy();
                }
            }
        }
    }
}
