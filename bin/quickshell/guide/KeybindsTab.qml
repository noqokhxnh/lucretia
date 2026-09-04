import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../singletons"

Item {
    id: keybindsTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property real cardRadius: ThemeBackend.clampedBorderRadius

    property string searchText: ""
    property string selectedCategory: "All"
    property var categoriesList: ["All"]

    property var rawKeybinds: []
    property var filteredKeybinds: []

    // Editor state
    property bool isEditing: false
    property bool isAdding: false
    property string editingOldCombo: ""
    property string editingCombo: ""
    property string editingAction: ""
    property string editingTitle: ""
    property bool isRecording: false

    // Modifiers state for editor
    property bool modSuper: false
    property bool modCtrl: false
    property bool modAlt: false
    property bool modShift: false
    property string keyName: ""

    // Delete confirmation state
    property string deletingCombo: ""
    property string deletingTitle: ""

    // Toast feedback state
    property string toastMessage: ""
    property string toastIcon: "󰄬"
    property color toastColor: ThemeBackend.green
    property bool toastVisible: false
    property bool toastCanUndo: false

    function showToast(msg, icon, col, canUndo) {
        toastMessage = msg;
        toastIcon = icon || "󰄬";
        toastColor = col || ThemeBackend.green;
        toastCanUndo = !!canUndo;
        toastVisible = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 3500
        repeat: false
        onTriggered: {
            keybindsTabRoot.toastVisible = false;
            keybindsTabRoot.toastCanUndo = false;
        }
    }

    FileView {
        id: configFileView
        path: Quickshell.env("HOME") + "/.config/niri/config.kdl"
        watchChanges: true
        onLoaded: {
            let txt = text();
            if (txt) keybindsTabRoot.parseConfig(txt);
        }
        onFileChanged: {
            configFileView.reload();
        }
    }

    function getTitleAndIcon(combo, action, category) {
        let title = "";
        let icon = "󰌌";
        let act = action.trim();

        if (act.indexOf("close-window") !== -1) {
            title = "Close Window";
            icon = "󰅖";
        } else if (act.indexOf("toggle-window-floating") !== -1) {
            title = "Toggle Floating";
            icon = "󰉈";
        } else if (act.indexOf("fullscreen-window") !== -1) {
            title = "Fullscreen";
            icon = "󰊓";
        } else if (act.indexOf("toggle-overview") !== -1) {
            title = "Toggle Overview";
            icon = "󰕰";
        } else if (act.indexOf("set-column-width") !== -1) {
            let isMinus = act.indexOf("-") !== -1;
            title = isMinus ? "Decrease Column Width" : "Increase Column Width";
            icon = "󰤻";
        } else if (act.indexOf("set-window-height") !== -1) {
            let isMinus = act.indexOf("-") !== -1;
            title = isMinus ? "Decrease Window Height" : "Increase Window Height";
            icon = "󰤻";
        } else if (act.indexOf("move-column-left") !== -1) {
            title = "Move Column Left";
            icon = "󰁍";
        } else if (act.indexOf("move-column-right") !== -1) {
            title = "Move Column Right";
            icon = "󰁔";
        } else if (act.indexOf("move-window-up") !== -1) {
            title = "Move Window Up";
            icon = "󰁝";
        } else if (act.indexOf("move-window-down") !== -1) {
            title = "Move Window Down";
            icon = "󰁅";
        } else if (act.indexOf("focus-column-left") !== -1) {
            title = "Focus Column Left";
            icon = "󰁍";
        } else if (act.indexOf("focus-column-right") !== -1) {
            title = "Focus Column Right";
            icon = "󰁔";
        } else if (act.indexOf("focus-window-or-monitor-up") !== -1) {
            title = "Focus Up / Monitor";
            icon = "󰁝";
        } else if (act.indexOf("focus-window-or-monitor-down") !== -1) {
            title = "Focus Down / Monitor";
            icon = "󰁅";
        } else if (act.indexOf("screenshot.sh") !== -1) {
            if (act.indexOf("--full") !== -1) title = "Screenshot (Full Screen)";
            else if (act.indexOf("--edit") !== -1) title = "Screenshot (Edit)";
            else title = "Screenshot (Area)";
            icon = "󰹑";
        } else if (act.indexOf("lock.sh") !== -1) {
            title = "Lock Screen";
            icon = "󰌾";
        } else if (act.indexOf("reload.sh") !== -1) {
            title = "Reload Quickshell";
            icon = "󰑐";
        } else if (act.indexOf("qs_manager.sh toggle") !== -1) {
            let m = act.match(/toggle\s+([a-zA-Z0-9_-]+)/);
            let panel = m ? m[1] : "Panel";
            title = "Toggle " + panel.charAt(0).toUpperCase() + panel.slice(1);
            if (panel === "clipboard") icon = "󰅌";
            else if (panel === "applauncher") icon = "󱓞";
            else if (panel === "settings") icon = "󰒓";
            else if (panel === "music") icon = "󰎆";
            else if (panel === "battery") icon = "󰁹";
            else if (panel === "wallpaper") icon = "󰸉";
            else if (panel === "calendar") icon = "󰸗";
            else if (panel === "photobooth") icon = "󰄀";
            else if (panel === "network") icon = "󰤨";
            else if (panel === "notes") icon = "󰠮";
            else if (panel === "focustime") icon = "󱎫";
            else if (panel === "volume") icon = "󰕾";
            else if (panel === "guide") icon = "󰌌";
            else if (panel === "monitors") icon = "󰍹";
            else icon = "󱓞";
        } else if (act.indexOf("qs_manager.sh") !== -1) {
            let m = act.match(/qs_manager\.sh\s+(\d+)(\s+move)?/);
            if (m) {
                let wsNum = m[1];
                let isMove = !!m[2];
                title = isMove ? ("Move to Workspace " + wsNum) : ("Switch to Workspace " + wsNum);
                icon = isMove ? "󰒭" : "󱂬";
            }
        } else if (act.indexOf("spawn \"foot\"") !== -1) {
            title = "Terminal (foot)";
            icon = "󰆍";
        } else if (act.indexOf("spawn \"zen-browser\"") !== -1) {
            title = "Web Browser (Zen)";
            icon = "󰖟";
        } else if (act.indexOf("spawn \"nautilus\"") !== -1) {
            title = "File Manager (Nautilus)";
            icon = "󰝰";
        } else if (act.indexOf("brightnessctl") !== -1) {
            title = act.indexOf("5%+") !== -1 ? "Brightness Up" : "Brightness Down";
            icon = act.indexOf("5%+") !== -1 ? "󰃠" : "󰃞";
        } else if (act.indexOf("wpctl") !== -1) {
            if (act.indexOf("@DEFAULT_AUDIO_SOURCE@") !== -1) {
                title = "Toggle Microphone Mute";
                icon = "󰍬";
            } else if (act.indexOf("toggle") !== -1) {
                title = "Toggle Audio Mute";
                icon = "󰝟";
            } else if (act.indexOf("5%+") !== -1) {
                title = "Volume Up";
                icon = "󰕾";
            } else {
                title = "Volume Down";
                icon = "󰕿";
            }
        } else if (act.indexOf("playerctl") !== -1) {
            title = "Play / Pause Media";
            icon = "󰐊";
        } else if (act.indexOf("swayosd-client --caps-lock") !== -1) {
            title = "Caps Lock Indicator";
            icon = "󰘲";
        }

        if (!title) {
            title = combo;
        }
        return { title: title, icon: icon };
    }

    function getCategoryInfo(cat) {
        if (cat === "All") return { label: I18n.t("guide.keybinds.all_categories", "All"), icon: "󰌌" };
        if (cat === "Basic Keybinds") return { label: "Basic", icon: "󰅖" };
        if (cat === "Window resizing") return { label: "Resize", icon: "󰤻" };
        if (cat === "Window movement") return { label: "Move", icon: "󰁔" };
        if (cat === "Focus movement") return { label: "Focus", icon: "󰁍" };
        if (cat === "Application Launchers") return { label: "Apps", icon: "󰆍" };
        if (cat === "Quickshell Panel Toggles") return { label: "Panels", icon: "󱓞" };
        if (cat === "Audio and Brightness Controls") return { label: "Audio & Light", icon: "󰕾" };
        if (cat === "Screenshot Controls") return { label: "Screenshots", icon: "󰹑" };
        if (cat === "Lock and Media Controls") return { label: "Lock & Media", icon: "󰌾" };
        if (cat === "Workspaces navigation & column move") return { label: "Workspaces", icon: "󱂬" };
        return { label: cat, icon: "󰌌" };
    }

    function getCategoryCount(cat) {
        if (cat === "All") return keybindsTabRoot.rawKeybinds.length;
        let c = 0;
        for (let i = 0; i < keybindsTabRoot.rawKeybinds.length; i++) {
            if (keybindsTabRoot.rawKeybinds[i].category === cat) c++;
        }
        return c;
    }

    function parseConfig(text) {
        if (!text) return;
        let lines = text.split("\n");
        let inBinds = false;
        let currentCategory = "General";
        let results = [];
        let cats = ["All"];

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (!inBinds) {
                if (line.startsWith("binds {") || line === "binds {") {
                    inBinds = true;
                }
                continue;
            }

            if (line === "}") {
                inBinds = false;
                break;
            }

            if (line.startsWith("// ---") && line.endsWith("---")) {
                let cat = line.replace(/^\/\/\s*---\s*/, "").replace(/\s*---\s*$/, "").trim();
                if (cat) {
                    currentCategory = cat;
                    if (cats.indexOf(cat) === -1) cats.push(cat);
                }
                continue;
            }

            if (line.startsWith("//")) continue;

            let match = line.match(/^([A-Za-z0-9_+-]+)\s*\{\s*(.*?)\s*\}$/);
            if (match) {
                let combo = match[1];
                let action = match[2];
                let parts = combo.split("+");
                let key = parts[parts.length - 1];
                let mods = parts.slice(0, parts.length - 1);

                let meta = getTitleAndIcon(combo, action, currentCategory);

                results.push({
                    combo: combo,
                    action: action,
                    category: currentCategory,
                    title: meta.title,
                    icon: meta.icon,
                    key: key,
                    mods: mods
                });
            }
        }

        let guideResults = [];
        let otherResults = [];
        for (let i = 0; i < results.length; i++) {
            let item = results[i];
            let isGuide = (item.action && item.action.indexOf("toggle guide") !== -1) || 
                          (item.title && item.title.toLowerCase().indexOf("guide") !== -1);
            if (isGuide) guideResults.push(item);
            else otherResults.push(item);
        }

        keybindsTabRoot.categoriesList = cats;
        keybindsTabRoot.rawKeybinds = guideResults.concat(otherResults);
        keybindsTabRoot.applyFilter();
    }

    function applyFilter() {
        let q = keybindsTabRoot.searchText.toLowerCase().trim();
        let cat = keybindsTabRoot.selectedCategory;
        let res = [];

        // Normalize query: remove spaces and '+' for combo matching (e.g. "super return" -> "super+return")
        let qCompact = q.replace(/[\s+]+/g, "+");

        let guideFiltered = [];
        let otherFiltered = [];

        for (let i = 0; i < keybindsTabRoot.rawKeybinds.length; i++) {
            let item = keybindsTabRoot.rawKeybinds[i];
            if (cat !== "All" && item.category !== cat) continue;
            if (q !== "") {
                let matchTitle = item.title && item.title.toLowerCase().indexOf(q) !== -1;
                let matchCombo = item.combo && (item.combo.toLowerCase().indexOf(q) !== -1 || item.combo.toLowerCase().indexOf(qCompact) !== -1);
                let matchAction = item.action && item.action.toLowerCase().indexOf(q) !== -1;
                let matchCat = item.category && item.category.toLowerCase().indexOf(q) !== -1;

                // Friendly aliases: "term" -> foot, "enter" -> return, "browser" -> zen
                let matchAlias = false;
                if (q.indexOf("term") !== -1 && item.action.indexOf("foot") !== -1) matchAlias = true;
                if (q.indexOf("enter") !== -1 && item.combo.toLowerCase().indexOf("return") !== -1) matchAlias = true;
                if (q.indexOf("browser") !== -1 && item.action.indexOf("zen") !== -1) matchAlias = true;
                if (q.indexOf("file") !== -1 && item.action.indexOf("nautilus") !== -1) matchAlias = true;

                if (!matchTitle && !matchCombo && !matchAction && !matchCat && !matchAlias) continue;
            }

            let isGuide = (item.action && item.action.indexOf("toggle guide") !== -1) || 
                          (item.title && item.title.toLowerCase().indexOf("guide") !== -1);
            if (isGuide) {
                guideFiltered.push(item);
            } else {
                otherFiltered.push(item);
            }
        }
        keybindsTabRoot.filteredKeybinds = guideFiltered.concat(otherFiltered);
    }

    onSearchTextChanged: applyFilter()
    onSelectedCategoryChanged: applyFilter()

    onVisibleChanged: {
        if (visible) {
            configFileView.reload();
            let txt = configFileView.text();
            if (txt) parseConfig(txt);
            isEditing = false;
            isAdding = false;
            isRecording = false;
            deletingCombo = "";
        }
    }

    Component.onCompleted: {
        let txt = configFileView.text();
        if (txt) parseConfig(txt);
    }

    function openEditor(item, isNew) {
        keybindsTabRoot.isAdding = isNew;
        keybindsTabRoot.isEditing = true;
        keybindsTabRoot.isRecording = false;
        keybindsTabRoot.deletingCombo = "";

        if (isNew) {
            keybindsTabRoot.editingOldCombo = "";
            keybindsTabRoot.editingCombo = "Super+";
            keybindsTabRoot.editingAction = 'spawn "foot";';
            keybindsTabRoot.editingTitle = "Custom Command";
            keybindsTabRoot.modSuper = true;
            keybindsTabRoot.modCtrl = false;
            keybindsTabRoot.modAlt = false;
            keybindsTabRoot.modShift = false;
            keybindsTabRoot.keyName = "";
        } else {
            keybindsTabRoot.editingOldCombo = (item && item.combo) ? item.combo : "";
            keybindsTabRoot.editingCombo = (item && item.combo) ? item.combo : "";
            keybindsTabRoot.editingAction = (item && item.action) ? item.action : "";
            keybindsTabRoot.editingTitle = (item && item.title) ? item.title : "";

            let mods = (item && item.mods) ? item.mods : [];
            keybindsTabRoot.modSuper = (mods.indexOf("Super") !== -1 || mods.indexOf("WIN") !== -1 || mods.indexOf("MOD4") !== -1);
            keybindsTabRoot.modCtrl = (mods.indexOf("Ctrl") !== -1 || mods.indexOf("CONTROL") !== -1);
            keybindsTabRoot.modAlt = (mods.indexOf("Alt") !== -1 || mods.indexOf("MOD1") !== -1);
            keybindsTabRoot.modShift = (mods.indexOf("Shift") !== -1 || mods.indexOf("SHIFT_L") !== -1 || mods.indexOf("SHIFT_R") !== -1);
            keybindsTabRoot.keyName = (item && item.key) ? item.key : "";
        }
    }

    function duplicateKeybind(item) {
        openEditor(item, true);
        editingTitle = (item.title || "Shortcut") + " (Copy)";
        keyName = "";
        updateComboFromState();
        showToast(I18n.t("guide.keybinds.cloned", "Shortcut copied! Pick a key combination."), "󰆏", ThemeBackend.peach, false);
    }

    function updateComboFromState() {
        let parts = [];
        if (modSuper) parts.push("Super");
        if (modCtrl) parts.push("Ctrl");
        if (modAlt) parts.push("Alt");
        if (modShift) parts.push("Shift");
        if (keyName && keyName.length > 0) parts.push(keyName);
        editingCombo = parts.join("+");
    }

    function isModifierKey(key) {
        return key === Qt.Key_Control || key === Qt.Key_Shift || key === Qt.Key_Alt ||
               key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R ||
               key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R;
    }

    function keyEventToString(key, text) {
        if (key === Qt.Key_Return || key === Qt.Key_Enter) return "Return";
        if (key === Qt.Key_Space) return "Space";
        if (key === Qt.Key_Tab) return "Tab";
        if (key === Qt.Key_Backtab) return "Backtab";
        if (key === Qt.Key_Backspace) return "BackSpace";
        if (key === Qt.Key_Escape) return "Escape";
        if (key === Qt.Key_Delete) return "Delete";
        if (key === Qt.Key_Insert) return "Insert";
        if (key === Qt.Key_Home) return "Home";
        if (key === Qt.Key_End) return "End";
        if (key === Qt.Key_PageUp) return "Page_Up";
        if (key === Qt.Key_PageDown) return "Page_Down";
        if (key === Qt.Key_Left) return "Left";
        if (key === Qt.Key_Right) return "Right";
        if (key === Qt.Key_Up) return "Up";
        if (key === Qt.Key_Down) return "Down";
        if (key === Qt.Key_Print) return "Print";
        if (key === Qt.Key_CapsLock) return "Caps_Lock";
        if (key >= Qt.Key_F1 && key <= Qt.Key_F12) return "F" + (key - Qt.Key_F1 + 1);
        if (key === Qt.Key_QuoteLeft || key === Qt.Key_AsciiTilde) return "grave";
        if (key === Qt.Key_Minus) return "minus";
        if (key === Qt.Key_Equal) return "equal";
        if (key === Qt.Key_BracketLeft) return "bracketleft";
        if (key === Qt.Key_BracketRight) return "bracketright";
        if (key === Qt.Key_Semicolon) return "semicolon";
        if (key === Qt.Key_Apostrophe) return "apostrophe";
        if (key === Qt.Key_Comma) return "comma";
        if (key === Qt.Key_Period) return "period";
        if (key === Qt.Key_Slash) return "slash";
        if (key === Qt.Key_Backslash) return "backslash";
        if (text && text.length === 1 && text.match(/[a-zA-Z0-9]/)) {
            return text.toUpperCase();
        }
        if (key >= Qt.Key_A && key <= Qt.Key_Z) {
            return String.fromCharCode(key);
        }
        if (key >= Qt.Key_0 && key <= Qt.Key_9) {
            return String.fromCharCode(key);
        }
        return "";
    }

    function checkConflict(combo) {
        if (!combo) return "";
        for (let i = 0; i < rawKeybinds.length; i++) {
            let item = rawKeybinds[i];
            if (item.combo.toLowerCase() === combo.toLowerCase()) {
                if (isEditing && !isAdding && item.combo.toLowerCase() === editingOldCombo.toLowerCase()) {
                    continue;
                }
                return item.title || item.action;
            }
        }
        return "";
    }

    function testExecute(action) {
        if (!action) return;
        let act = action.trim().replace(/;$/, "");
        if (act.startsWith("spawn ")) {
            let regex = /"([^"\\]*(?:\\.[^"\\]*)*)"/g;
            let match;
            let args = [];
            while ((match = regex.exec(act)) !== null) {
                args.push(match[1]);
            }
            if (args.length > 0) {
                Quickshell.execDetached(args);
                showToast(I18n.t("guide.keybinds.tested", "Executed: ") + args[0], "󰐊", ThemeBackend.blue, false);
                return;
            }
        }
        let tokens = act.split(/\s+/);
        let niriCmd = ["niri", "msg", "action"];
        for (let t of tokens) {
            if (t) niriCmd.push(t);
        }
        Quickshell.execDetached(niriCmd);
        showToast(I18n.t("guide.keybinds.tested", "Executed: ") + act, "󰐊", ThemeBackend.blue, false);
    }

    function saveKeybind() {
        if (!keyName || keyName.trim() === "") {
            showToast(I18n.t("guide.keybinds.validation_key", "Please choose or record a key name!"), "󰀦", ThemeBackend.yellow, false);
            return;
        }
        if (!editingAction || editingAction.trim() === "") {
            showToast(I18n.t("guide.keybinds.validation_action", "Please enter an action command!"), "󰀦", ThemeBackend.yellow, false);
            return;
        }

        let act = editingAction.trim();
        if (!act.endsWith(";")) act += ";";

        let cmd = [];
        if (isAdding) {
            cmd = ["bash", Quickshell.env("HOME") + "/.config/niri/bin/keybinds.sh", "add", editingCombo, act];
        } else {
            cmd = ["bash", Quickshell.env("HOME") + "/.config/niri/bin/keybinds.sh", "update", editingOldCombo, editingCombo, act];
        }

        Quickshell.execDetached(cmd);
        isEditing = false;
        isRecording = false;
        showToast(I18n.t("guide.keybinds.toast_saved", "Shortcut saved and applied live!"), "󰄬", ThemeBackend.green, true);
        reloadTimer.restart();
    }

    function requestDelete(combo, title) {
        keybindsTabRoot.deletingCombo = combo;
        keybindsTabRoot.deletingTitle = title || combo;
    }

    function confirmDelete() {
        if (!deletingCombo) return;
        let cmd = ["bash", Quickshell.env("HOME") + "/.config/niri/bin/keybinds.sh", "delete", deletingCombo];
        Quickshell.execDetached(cmd);
        showToast(I18n.t("guide.keybinds.toast_deleted", "Shortcut removed successfully!"), "󰆴", ThemeBackend.red, true);
        deletingCombo = "";
        reloadTimer.restart();
    }

    function cancelDelete() {
        deletingCombo = "";
        deletingTitle = "";
    }

    function restoreBackup() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/keybinds.sh", "reset"]);
        showToast(I18n.t("guide.keybinds.toast_restored", "Restored previous shortcuts configuration!"), "󰑐", ThemeBackend.green, false);
        toastCanUndo = false;
        reloadTimer.restart();
    }

    Timer {
        id: reloadTimer
        interval: 350
        repeat: false
        onTriggered: {
            configFileView.reload();
            let txt = configFileView.text();
            if (txt) keybindsTabRoot.parseConfig(txt);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: rootObj.s(16)
        spacing: rootObj.s(10)

        // -------------------------------------------------------------
        // HEADER ROW: Title, Search, Actions
        // -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj.s(8)

            ColumnLayout {
                spacing: rootObj.s(2)
                Layout.fillWidth: true
                Layout.minimumWidth: 0

                Text {
                    text: I18n.t("guide.tabs.keybinds", "Keybinds")
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: rootObj.s(18)
                    color: ThemeBackend.text
                }
                Text {
                    text: I18n.t("guide.keybinds.desc", "View, configure, and customize keyboard shortcuts for Niri and Quickshell.")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    color: ThemeBackend.subtext0
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }

            // Search Bar with Escape to clear & clear button
            Rectangle {
                Layout.preferredWidth: rootObj.s(190)
                Layout.preferredHeight: rootObj.s(32)
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.surface0
                border.color: searchInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.surface1
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: rootObj.s(8)
                    anchors.rightMargin: rootObj.s(8)
                    spacing: rootObj.s(6)

                    Text {
                        text: "󰍉"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(13)
                        color: searchInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.subtext0
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        color: ThemeBackend.text
                        clip: true
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: keybindsTabRoot.searchText = text

                        Keys.onEscapePressed: {
                            text = "";
                            keybindsTabRoot.searchText = "";
                        }

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.activeFocus
                            text: I18n.t("guide.keybinds.search_placeholder", "Search shortcuts...")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext1
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        visible: searchInput.text.length > 0
                        width: rootObj.s(16)
                        height: rootObj.s(16)
                        radius: rootObj.s(8)
                        color: clearMa.containsMouse ? ThemeBackend.surface2 : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            color: ThemeBackend.subtext0
                        }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                keybindsTabRoot.searchText = "";
                            }
                        }
                    }
                }
            }

            // Add Shortcut Button
            ClickButton {
                Layout.preferredHeight: rootObj.s(32)
                buttonText: I18n.t("guide.keybinds.add_shortcut", "+ Add Shortcut")
                buttonIcon: "󰐕"
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                textFontSize: rootObj.s(11)
                iconFontSize: rootObj.s(13)
                onClicked: keybindsTabRoot.openEditor(null, true)
            }

            // Reload Button
            Rectangle {
                Layout.preferredWidth: rootObj.s(32)
                Layout.preferredHeight: rootObj.s(32)
                radius: ThemeBackend.borderRadius
                color: reloadMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                border.color: ThemeBackend.surface1
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(14)
                    color: ThemeBackend.text
                }
                MouseArea {
                    id: reloadMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        configFileView.reload();
                        let txt = configFileView.text();
                        if (txt) keybindsTabRoot.parseConfig(txt);
                        keybindsTabRoot.showToast(I18n.t("guide.keybinds.reloaded", "Reloaded from config.kdl"), "󰑐", ThemeBackend.blue, false);
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // CATEGORY PILLS FILTER ROW (Flickable + Mouse Wheel scrolling)
        // -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj.s(8)

            Flickable {
                id: catFlickable
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(30)
                contentWidth: catRow.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Enable horizontal mouse wheel scrolling over category bar!
                WheelHandler {
                    target: catFlickable
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (wheel) => {
                        let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                        catFlickable.contentX = Math.max(0, Math.min(catFlickable.contentWidth - catFlickable.width, catFlickable.contentX - delta));
                    }
                }

                Row {
                    id: catRow
                    spacing: rootObj.s(6)

                    Repeater {
                        model: keybindsTabRoot.categoriesList
                        delegate: Rectangle {
                            id: catPill
                            property bool isSelected: keybindsTabRoot.selectedCategory === modelData
                            property var catInfo: keybindsTabRoot.getCategoryInfo(modelData)
                            property int catCount: keybindsTabRoot.getCategoryCount(modelData)

                            height: rootObj.s(26)
                            width: catRowLayout.implicitWidth + rootObj.s(18)
                            radius: rootObj.s(13)
                            color: isSelected ? ThemeBackend.mauve : (catMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                            border.color: isSelected ? ThemeBackend.mauve : ThemeBackend.surface1
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: catRowLayout
                                anchors.centerIn: parent
                                spacing: rootObj.s(5)

                                Text {
                                    text: catPill.catInfo.icon
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                    color: catPill.isSelected ? ThemeBackend.crust : ThemeBackend.mauve
                                }

                                Text {
                                    text: catPill.catInfo.label
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                    font.weight: catPill.isSelected ? Font.Bold : Font.Medium
                                    color: catPill.isSelected ? ThemeBackend.crust : ThemeBackend.subtext0
                                }

                                Rectangle {
                                    height: rootObj.s(14)
                                    width: countText.implicitWidth + rootObj.s(6)
                                    radius: rootObj.s(7)
                                    color: catPill.isSelected ? Qt.alpha(ThemeBackend.crust, 0.25) : ThemeBackend.surface1

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: String(catPill.catCount)
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: rootObj.s(9)
                                        font.bold: true
                                        color: catPill.isSelected ? ThemeBackend.crust : ThemeBackend.subtext1
                                    }
                                }
                            }

                            MouseArea {
                                id: catMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Clicking active category toggles back to All
                                    if (keybindsTabRoot.selectedCategory === modelData && modelData !== "All") {
                                        keybindsTabRoot.selectedCategory = "All";
                                    } else {
                                        keybindsTabRoot.selectedCategory = modelData;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: rootObj.s(22)
                Layout.preferredWidth: countBadgeText.implicitWidth + rootObj.s(14)
                radius: rootObj.s(11)
                color: Qt.alpha(ThemeBackend.surface1, 0.7)
                border.color: ThemeBackend.surface2
                border.width: 1

                Text {
                    id: countBadgeText
                    anchors.centerIn: parent
                    text: keybindsTabRoot.filteredKeybinds.length + " / " + keybindsTabRoot.rawKeybinds.length
                    font.family: "JetBrains Mono"
                    font.pixelSize: rootObj.s(10)
                    font.bold: true
                    color: ThemeBackend.subtext0
                }
            }
        }

        // -------------------------------------------------------------
        // MAIN CONTENT AREA: LIST OF KEYBINDS OR INLINE EDITOR
        // -------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: !keybindsTabRoot.isEditing && keybindsTabRoot.filteredKeybinds.length === 0
                spacing: rootObj.s(10)

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: rootObj.s(54)
                    height: rootObj.s(54)
                    radius: rootObj.s(27)
                    color: ThemeBackend.surface0
                    border.color: ThemeBackend.surface1
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰍉"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(26)
                        color: ThemeBackend.subtext1
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.t("guide.keybinds.empty", "No shortcuts found")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(14)
                    font.bold: true
                    color: ThemeBackend.text
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: keybindsTabRoot.searchText ? ("No matches for \"" + keybindsTabRoot.searchText + "\"") : "Try selecting a different category"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    color: ThemeBackend.subtext0
                }

                ClickButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: keybindsTabRoot.searchText.length > 0 || keybindsTabRoot.selectedCategory !== "All"
                    Layout.preferredHeight: rootObj.s(30)
                    buttonText: I18n.t("guide.keybinds.clear_search", "Clear filter")
                    buttonIcon: "󰅖"
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    textFontSize: rootObj.s(11)
                    onClicked: {
                        keybindsTabRoot.searchText = "";
                        keybindsTabRoot.selectedCategory = "All";
                        searchInput.text = "";
                    }
                }
            }

            // KEYBINDS LIST
            ListView {
                id: keybindsListView
                anchors.fill: parent
                anchors.rightMargin: rootObj.s(6)
                visible: !keybindsTabRoot.isEditing
                clip: true
                spacing: rootObj.s(6)
                model: keybindsTabRoot.filteredKeybinds
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: rootObj.s(4)
                        radius: rootObj.s(2)
                        color: ThemeBackend.surface2
                    }
                }

                delegate: Rectangle {
                    id: keybindItem
                    required property var modelData
                    required property int index

                    property bool isGuideItem: (keybindItem.modelData && ((keybindItem.modelData.action && keybindItem.modelData.action.indexOf("toggle guide") !== -1) || (keybindItem.modelData.title && keybindItem.modelData.title.toLowerCase().indexOf("guide") !== -1)))

                    width: keybindsListView.width
                    height: rootObj.s(52)
                    radius: ThemeBackend.borderRadius
                    color: itemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) :
                           (keybindItem.isGuideItem ? Qt.alpha(ThemeBackend.mauve, 0.08) : Qt.alpha(ThemeBackend.surface0, 0.4))
                    border.color: itemMa.containsMouse ? Qt.alpha(ThemeBackend.mauve, 0.5) :
                                  (keybindItem.isGuideItem ? Qt.alpha(ThemeBackend.mauve, 0.4) : ThemeBackend.surface1)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: keybindsTabRoot.openEditor(keybindItem.modelData, false)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: rootObj.s(12)
                        anchors.rightMargin: rootObj.s(10)
                        spacing: rootObj.s(10)

                        // Icon in Circle
                        Rectangle {
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            radius: rootObj.s(16)
                            color: Qt.alpha(ThemeBackend.surface1, 0.8)
                            border.color: ThemeBackend.surface2
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (keybindItem.modelData && keybindItem.modelData.icon) ? keybindItem.modelData.icon : "󰌌"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: rootObj.s(15)
                                color: ThemeBackend.mauve
                            }
                        }

                        // Title & Action
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            spacing: rootObj.s(2)

                            RowLayout {
                                spacing: rootObj.s(8)
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0

                                Text {
                                    text: (keybindItem.modelData && keybindItem.modelData.title) ? keybindItem.modelData.title : (keybindItem.modelData ? keybindItem.modelData.combo : "")
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.DemiBold
                                    font.pixelSize: rootObj.s(12)
                                    color: ThemeBackend.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                }

                                Rectangle {
                                    visible: keybindItem.isGuideItem
                                    height: rootObj.s(16)
                                    width: guideBadgeText.implicitWidth + rootObj.s(10)
                                    radius: rootObj.s(8)
                                    color: Qt.alpha(ThemeBackend.mauve, 0.2)
                                    border.color: ThemeBackend.mauve
                                    border.width: 1
                                    Text {
                                        id: guideBadgeText
                                        anchors.centerIn: parent
                                        text: "★ Guide"
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Bold
                                        font.pixelSize: rootObj.s(9)
                                        color: ThemeBackend.mauve
                                    }
                                }
                            }

                            Text {
                                text: (keybindItem.modelData && keybindItem.modelData.action) ? keybindItem.modelData.action : ""
                                font.family: "JetBrains Mono"
                                font.pixelSize: rootObj.s(10)
                                color: ThemeBackend.subtext1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                            }
                        }

                        // Tactile Keyboard Keycaps (Super + Shift + F)
                        Row {
                            id: keysRow
                            spacing: rootObj.s(4)
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredHeight: rootObj.s(26)

                            property var keysParts: (keybindItem.modelData && keybindItem.modelData.combo) ? keybindItem.modelData.combo.split("+") : []

                            Repeater {
                                model: keysRow.keysParts
                                delegate: Row {
                                    id: keyPartDelegate
                                    required property var modelData
                                    required property int index
                                    spacing: rootObj.s(4)

                                    property string kName: String(keyPartDelegate.modelData || "")
                                    property bool isSuper: kName === "Super" || kName === "WIN" || kName === "MOD4"
                                    property bool isShift: kName === "Shift"
                                    property bool isCtrl: kName === "Ctrl"
                                    property bool isAlt: kName === "Alt"

                                    // Keycap Rectangle
                                    Rectangle {
                                        height: rootObj.s(24)
                                        width: Math.max(rootObj.s(24), kText.implicitWidth + rootObj.s(12))
                                        radius: rootObj.s(5)
                                        color: keyPartDelegate.isSuper ? Qt.alpha(ThemeBackend.peach, 0.18) :
                                               (keyPartDelegate.isShift ? Qt.alpha(ThemeBackend.mauve, 0.18) :
                                               (keyPartDelegate.isCtrl ? Qt.alpha(ThemeBackend.blue, 0.18) :
                                               (keyPartDelegate.isAlt ? Qt.alpha(ThemeBackend.sapphire, 0.18) : ThemeBackend.surface1)))

                                        border.color: keyPartDelegate.isSuper ? ThemeBackend.peach :
                                                      (keyPartDelegate.isShift ? ThemeBackend.mauve :
                                                      (keyPartDelegate.isCtrl ? ThemeBackend.blue :
                                                      (keyPartDelegate.isAlt ? ThemeBackend.sapphire : ThemeBackend.surface2)))
                                        border.width: 1

                                        // Keycap 3D depth bottom edge
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: rootObj.s(2)
                                            radius: rootObj.s(2)
                                            color: Qt.alpha(ThemeBackend.crust, 0.35)
                                        }

                                        Text {
                                            id: kText
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -rootObj.s(1)
                                            text: {
                                                if (keyPartDelegate.kName === "Super") return "󰘳 Super";
                                                if (keyPartDelegate.kName === "Shift") return "󰘶 Shift";
                                                if (keyPartDelegate.kName === "Ctrl") return "Ctrl";
                                                if (keyPartDelegate.kName === "Alt") return "Alt";
                                                return keyPartDelegate.kName;
                                            }
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Bold
                                            font.pixelSize: rootObj.s(10)
                                            color: keyPartDelegate.isSuper ? ThemeBackend.peach :
                                                   (keyPartDelegate.isShift ? ThemeBackend.mauve :
                                                   (keyPartDelegate.isCtrl ? ThemeBackend.blue :
                                                   (keyPartDelegate.isAlt ? ThemeBackend.sapphire : ThemeBackend.text)))
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: keyPartDelegate.index < (keysRow.keysParts.length - 1)
                                        text: "+"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext1
                                    }
                                }
                            }
                        }

                        // Action Buttons: Test (󰐊), Duplicate (󰆏), Edit (󰏫), Delete (󰆴)
                        Row {
                            spacing: rootObj.s(3)
                            Layout.alignment: Qt.AlignVCenter

                            // 1. Test Run Button
                            Rectangle {
                                width: rootObj.s(26)
                                height: rootObj.s(26)
                                radius: rootObj.s(6)
                                color: testMa.containsMouse ? Qt.alpha(ThemeBackend.green, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐊"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(13)
                                    color: testMa.containsMouse ? ThemeBackend.green : ThemeBackend.subtext0
                                }
                                MouseArea {
                                    id: testMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: keybindsTabRoot.testExecute(keybindItem.modelData.action)
                                }
                            }

                            // 2. Duplicate Button
                            Rectangle {
                                width: rootObj.s(26)
                                height: rootObj.s(26)
                                radius: rootObj.s(6)
                                color: dupMa.containsMouse ? Qt.alpha(ThemeBackend.peach, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆏"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(13)
                                    color: dupMa.containsMouse ? ThemeBackend.peach : ThemeBackend.subtext0
                                }
                                MouseArea {
                                    id: dupMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: keybindsTabRoot.duplicateKeybind(keybindItem.modelData)
                                }
                            }

                            // 3. Edit Button
                            Rectangle {
                                width: rootObj.s(26)
                                height: rootObj.s(26)
                                radius: rootObj.s(6)
                                color: editMa.containsMouse ? Qt.alpha(ThemeBackend.blue, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰏫"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(13)
                                    color: editMa.containsMouse ? ThemeBackend.blue : ThemeBackend.subtext0
                                }
                                MouseArea {
                                    id: editMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: keybindsTabRoot.openEditor(keybindItem.modelData, false)
                                }
                            }

                            // 4. Delete Button
                            Rectangle {
                                width: rootObj.s(26)
                                height: rootObj.s(26)
                                radius: rootObj.s(6)
                                color: delMa.containsMouse ? Qt.alpha(ThemeBackend.red, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(13)
                                    color: delMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                                }
                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: keybindsTabRoot.requestDelete(keybindItem.modelData.combo, keybindItem.modelData.title)
                                }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // SET KEYBIND EDITOR PANEL (When editing or adding)
            // -------------------------------------------------------------
            Rectangle {
                id: editorCard
                anchors.fill: parent
                visible: keybindsTabRoot.isEditing
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.surface0
                border.color: ThemeBackend.surface1
                border.width: 1

                // Key recording catcher
                Item {
                    id: keyGrabber
                    anchors.fill: parent
                    focus: keybindsTabRoot.isRecording

                    Keys.onPressed: (event) => {
                        if (!keybindsTabRoot.isRecording) return;

                        if (event.key === Qt.Key_Escape) {
                            keybindsTabRoot.isRecording = false;
                            event.accepted = true;
                            return;
                        }

                        if (keybindsTabRoot.isModifierKey(event.key)) {
                            keybindsTabRoot.modSuper = (event.modifiers & Qt.MetaModifier) !== 0;
                            keybindsTabRoot.modCtrl = (event.modifiers & Qt.ControlModifier) !== 0;
                            keybindsTabRoot.modAlt = (event.modifiers & Qt.AltModifier) !== 0;
                            keybindsTabRoot.modShift = (event.modifiers & Qt.ShiftModifier) !== 0;
                            keybindsTabRoot.updateComboFromState();
                            event.accepted = true;
                            return;
                        }

                        let keyStr = keybindsTabRoot.keyEventToString(event.key, event.text);
                        if (!keyStr) return;

                        event.accepted = true;

                        keybindsTabRoot.modSuper = (event.modifiers & Qt.MetaModifier) !== 0;
                        keybindsTabRoot.modCtrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        keybindsTabRoot.modAlt = (event.modifiers & Qt.AltModifier) !== 0;
                        keybindsTabRoot.modShift = (event.modifiers & Qt.ShiftModifier) !== 0;

                        if (!keybindsTabRoot.modSuper && !keybindsTabRoot.modCtrl && !keybindsTabRoot.modAlt && !keybindsTabRoot.modShift) {
                            keybindsTabRoot.modSuper = true;
                        }

                        keybindsTabRoot.keyName = keyStr;
                        keybindsTabRoot.updateComboFromState();
                        keybindsTabRoot.isRecording = false;
                    }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: rootObj.s(16)
                    contentWidth: width
                    contentHeight: editorContentCol.implicitHeight + rootObj.s(30)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: editorContentCol
                        width: parent.width
                        spacing: rootObj.s(12)

                        // Title Bar of Editor
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: rootObj.s(10)

                            Text {
                                text: keybindsTabRoot.isAdding ? I18n.t("guide.keybinds.add_title", "Add New Keybinding") : I18n.t("guide.keybinds.edit_title", "Edit Keybinding: ") + keybindsTabRoot.editingTitle
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: rootObj.s(15)
                                color: ThemeBackend.text
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: rootObj.s(26)
                                height: rootObj.s(26)
                                radius: rootObj.s(13)
                                color: closeEditorMa.containsMouse ? ThemeBackend.surface1 : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(15)
                                    color: ThemeBackend.subtext0
                                }
                                MouseArea {
                                    id: closeEditorMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        keybindsTabRoot.isEditing = false;
                                        keybindsTabRoot.isRecording = false;
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // SECTION 1: KEY COMBINATION BUILDER & RECORDER
                        // -----------------------------------------------------
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: recCol.implicitHeight + rootObj.s(20)
                            radius: rootObj.s(10)
                            color: Qt.alpha(ThemeBackend.surface1, 0.4)
                            border.color: keybindsTabRoot.isRecording ? ThemeBackend.blue : ThemeBackend.surface2
                            border.width: keybindsTabRoot.isRecording ? 2 : 1

                            SequentialAnimation on border.color {
                                running: keybindsTabRoot.isRecording
                                loops: Animation.Infinite
                                ColorAnimation { from: ThemeBackend.blue; to: ThemeBackend.mauve; duration: 600 }
                                ColorAnimation { from: ThemeBackend.mauve; to: ThemeBackend.blue; duration: 600 }
                            }

                            ColumnLayout {
                                id: recCol
                                anchors.fill: parent
                                anchors.margins: rootObj.s(12)
                                spacing: rootObj.s(10)

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: I18n.t("guide.keybinds.section_combo", "Shortcut Combination")
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.DemiBold
                                        font.pixelSize: rootObj.s(12)
                                        color: ThemeBackend.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        visible: keybindsTabRoot.isRecording
                                        text: I18n.t("guide.keybinds.recording_hint", "Recording... Press combination (Esc to cancel)")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.blue
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: rootObj.s(10)

                                    // Big Record Button
                                    Rectangle {
                                        Layout.preferredWidth: rootObj.s(160)
                                        Layout.preferredHeight: rootObj.s(38)
                                        radius: ThemeBackend.borderRadius
                                        color: keybindsTabRoot.isRecording ? ThemeBackend.blue : (recMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1)
                                        border.color: keybindsTabRoot.isRecording ? ThemeBackend.blue : ThemeBackend.surface2
                                        border.width: 1

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: rootObj.s(6)
                                            Text {
                                                text: keybindsTabRoot.isRecording ? "󰑐" : "󰌌"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(15)
                                                color: keybindsTabRoot.isRecording ? ThemeBackend.crust : ThemeBackend.text
                                            }
                                            Text {
                                                text: keybindsTabRoot.isRecording ? I18n.t("guide.keybinds.listening", "Press keys now...") : I18n.t("guide.keybinds.record_btn", "Record Combo")
                                                font.family: ThemeBackend.fontFamily
                                                font.weight: Font.Bold
                                                font.pixelSize: rootObj.s(11)
                                                color: keybindsTabRoot.isRecording ? ThemeBackend.crust : ThemeBackend.text
                                            }
                                        }

                                        MouseArea {
                                            id: recMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                keybindsTabRoot.isRecording = !keybindsTabRoot.isRecording;
                                                if (keybindsTabRoot.isRecording) {
                                                    keyGrabber.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }

                                    // Display of current combination + Conflict Warning
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: rootObj.s(38)
                                        radius: ThemeBackend.borderRadius
                                        color: ThemeBackend.surface0
                                        border.color: conflictNotice.visible ? ThemeBackend.yellow : ThemeBackend.surface1
                                        border.width: conflictNotice.visible ? 1.5 : 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: rootObj.s(10)
                                            anchors.rightMargin: rootObj.s(10)

                                            Text {
                                                text: keybindsTabRoot.editingCombo ? keybindsTabRoot.editingCombo : I18n.t("guide.keybinds.no_combo", "No shortcut set")
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Bold
                                                font.pixelSize: rootObj.s(13)
                                                color: keybindsTabRoot.editingCombo ? ThemeBackend.peach : ThemeBackend.subtext1
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Conflict indicator
                                            property string conflict: keybindsTabRoot.checkConflict(keybindsTabRoot.editingCombo)
                                            RowLayout {
                                                id: conflictNotice
                                                visible: parent.conflict.length > 0
                                                spacing: rootObj.s(4)
                                                Text {
                                                    text: "󰀦"
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: rootObj.s(13)
                                                    color: ThemeBackend.yellow
                                                }
                                                Text {
                                                    text: I18n.t("guide.keybinds.conflict", "Conflict with: ") + parent.parent.conflict
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: rootObj.s(10)
                                                    color: ThemeBackend.yellow
                                                }
                                            }
                                        }
                                    }
                                }

                                // Manual Modifier Selector Pills
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: rootObj.s(6)

                                    Text {
                                        text: I18n.t("guide.keybinds.modifiers", "Modifiers:")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Super Pill
                                    Rectangle {
                                        width: rootObj.s(68); height: rootObj.s(28)
                                        radius: rootObj.s(5)
                                        color: keybindsTabRoot.modSuper ? ThemeBackend.peach : ThemeBackend.surface0
                                        border.color: keybindsTabRoot.modSuper ? ThemeBackend.peach : ThemeBackend.surface2
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "󰘳 Super"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: rootObj.s(10); color: keybindsTabRoot.modSuper ? ThemeBackend.crust : ThemeBackend.text }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { keybindsTabRoot.modSuper = !keybindsTabRoot.modSuper; keybindsTabRoot.updateComboFromState(); } }
                                    }

                                    // Ctrl Pill
                                    Rectangle {
                                        width: rootObj.s(54); height: rootObj.s(28)
                                        radius: rootObj.s(5)
                                        color: keybindsTabRoot.modCtrl ? ThemeBackend.sky : ThemeBackend.surface0
                                        border.color: keybindsTabRoot.modCtrl ? ThemeBackend.sky : ThemeBackend.surface2
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "Ctrl"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: rootObj.s(10); color: keybindsTabRoot.modCtrl ? ThemeBackend.crust : ThemeBackend.text }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { keybindsTabRoot.modCtrl = !keybindsTabRoot.modCtrl; keybindsTabRoot.updateComboFromState(); } }
                                    }

                                    // Alt Pill
                                    Rectangle {
                                        width: rootObj.s(54); height: rootObj.s(28)
                                        radius: rootObj.s(5)
                                        color: keybindsTabRoot.modAlt ? ThemeBackend.sapphire : ThemeBackend.surface0
                                        border.color: keybindsTabRoot.modAlt ? ThemeBackend.sapphire : ThemeBackend.surface2
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "Alt"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: rootObj.s(10); color: keybindsTabRoot.modAlt ? ThemeBackend.crust : ThemeBackend.text }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { keybindsTabRoot.modAlt = !keybindsTabRoot.modAlt; keybindsTabRoot.updateComboFromState(); } }
                                    }

                                    // Shift Pill
                                    Rectangle {
                                        width: rootObj.s(68); height: rootObj.s(28)
                                        radius: rootObj.s(5)
                                        color: keybindsTabRoot.modShift ? ThemeBackend.mauve : ThemeBackend.surface0
                                        border.color: keybindsTabRoot.modShift ? ThemeBackend.mauve : ThemeBackend.surface2
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "󰘶 Shift"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: rootObj.s(10); color: keybindsTabRoot.modShift ? ThemeBackend.crust : ThemeBackend.text }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { keybindsTabRoot.modShift = !keybindsTabRoot.modShift; keybindsTabRoot.updateComboFromState(); } }
                                    }

                                    Item { Layout.preferredWidth: rootObj.s(6) }

                                    Text {
                                        text: I18n.t("guide.keybinds.key", "Key:")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.subtext0
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: rootObj.s(90)
                                        Layout.preferredHeight: rootObj.s(28)
                                        radius: rootObj.s(5)
                                        color: ThemeBackend.surface0
                                        border.color: keyManualInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.surface2
                                        border.width: 1

                                        TextInput {
                                            id: keyManualInput
                                            anchors.fill: parent
                                            anchors.leftMargin: rootObj.s(6)
                                            anchors.rightMargin: rootObj.s(6)
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Bold
                                            font.pixelSize: rootObj.s(11)
                                            color: ThemeBackend.text
                                            text: keybindsTabRoot.keyName
                                            onTextChanged: {
                                                keybindsTabRoot.keyName = text;
                                                keybindsTabRoot.updateComboFromState();
                                            }
                                        }
                                    }
                                }

                                // Popular Keys Quick-Pick Chips
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: rootObj.s(6)

                                    Text {
                                        text: I18n.t("guide.keybinds.popular_keys", "Popular Keys:")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext0
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: rootObj.s(4)

                                        Repeater {
                                            model: ["Return", "Space", "Tab", "Escape", "Q", "W", "D", "F", "Print", "Left", "Right", "Up", "Down"]
                                            delegate: Rectangle {
                                                property bool isCurKey: keybindsTabRoot.keyName.toLowerCase() === modelData.toLowerCase()
                                                height: rootObj.s(22)
                                                width: popKeyText.implicitWidth + rootObj.s(10)
                                                radius: rootObj.s(4)
                                                color: isCurKey ? ThemeBackend.mauve : (popKeyMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface0)
                                                border.color: isCurKey ? ThemeBackend.mauve : ThemeBackend.surface2
                                                border.width: 1

                                                Text {
                                                    id: popKeyText
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: rootObj.s(10)
                                                    font.bold: true
                                                    color: isCurKey ? ThemeBackend.crust : ThemeBackend.subtext0
                                                }
                                                MouseArea {
                                                    id: popKeyMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        keybindsTabRoot.keyName = modelData;
                                                        keybindsTabRoot.updateComboFromState();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // SECTION 2: ACTION & COMMAND
                        // -----------------------------------------------------
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: actCol.implicitHeight + rootObj.s(20)
                            radius: rootObj.s(10)
                            color: Qt.alpha(ThemeBackend.surface1, 0.4)
                            border.color: ThemeBackend.surface2
                            border.width: 1

                            ColumnLayout {
                                id: actCol
                                anchors.fill: parent
                                anchors.margins: rootObj.s(12)
                                spacing: rootObj.s(8)

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: I18n.t("guide.keybinds.section_action", "Action & Command")
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.DemiBold
                                        font.pixelSize: rootObj.s(12)
                                        color: ThemeBackend.text
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: keybindsTabRoot.editingTitle
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(11)
                                        color: ThemeBackend.mauve
                                    }
                                }

                                // Quick presets
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: rootObj.s(6)
                                    Text {
                                        text: I18n.t("guide.keybinds.presets", "Presets:")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                        color: ThemeBackend.subtext0
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: rootObj.s(5)

                                        Repeater {
                                            model: [
                                                { label: "Toggle Guide", act: 'spawn "bash" "-c" "$HOME/.config/niri/bin/qs_manager.sh toggle guide";' },
                                                { label: "Close Window", act: "close-window;" },
                                                { label: "Toggle Floating", act: "toggle-window-floating;" },
                                                { label: "Fullscreen", act: "fullscreen-window;" },
                                                { label: "Overview", act: "toggle-overview;" },
                                                { label: "Terminal", act: 'spawn "foot";' },
                                                { label: "Browser", act: 'spawn "zen-browser";' },
                                                { label: "Files", act: 'spawn "nautilus";' },
                                                { label: "Launcher", act: 'spawn "bash" "-c" "$HOME/.config/niri/bin/qs_manager.sh toggle applauncher";' },
                                                { label: "Clipboard", act: 'spawn "bash" "-c" "$HOME/.config/niri/bin/qs_manager.sh toggle clipboard";' },
                                                { label: "Screenshot", act: 'spawn "bash" "-c" "$HOME/.config/niri/bin/screenshot.sh";' },
                                                { label: "Lock Screen", act: 'spawn "bash" "-c" "$HOME/.config/niri/bin/lock.sh";' }
                                            ]
                                            delegate: Rectangle {
                                                property bool isCurPreset: keybindsTabRoot.editingAction.trim() === modelData.act.trim()
                                                height: rootObj.s(22)
                                                width: pText.implicitWidth + rootObj.s(10)
                                                radius: rootObj.s(4)
                                                color: isCurPreset ? ThemeBackend.blue : (pMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface0)
                                                border.color: isCurPreset ? ThemeBackend.blue : ThemeBackend.surface2
                                                border.width: 1
                                                Text {
                                                    id: pText
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: rootObj.s(10)
                                                    color: isCurPreset ? ThemeBackend.crust : ThemeBackend.subtext0
                                                }
                                                MouseArea {
                                                    id: pMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        keybindsTabRoot.editingAction = modelData.act;
                                                        keybindsTabRoot.editingTitle = modelData.label;
                                                        actionInput.text = modelData.act;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Command input box + Test Button
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: rootObj.s(8)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: rootObj.s(34)
                                        radius: ThemeBackend.borderRadius
                                        color: ThemeBackend.surface0
                                        border.color: actionInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.surface1
                                        border.width: 1

                                        TextInput {
                                            id: actionInput
                                            anchors.fill: parent
                                            anchors.leftMargin: rootObj.s(10)
                                            anchors.rightMargin: rootObj.s(10)
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: rootObj.s(11)
                                            color: ThemeBackend.text
                                            text: keybindsTabRoot.editingAction
                                            selectByMouse: true
                                            onTextChanged: keybindsTabRoot.editingAction = text
                                        }
                                    }

                                    // Inline Test Command Button
                                    ClickButton {
                                        Layout.preferredHeight: rootObj.s(34)
                                        Layout.preferredWidth: rootObj.s(80)
                                        buttonText: I18n.t("guide.keybinds.test_run", "Test")
                                        buttonIcon: "󰐊"
                                        accentColor: ThemeBackend.surface2
                                        textColor: ThemeBackend.text
                                        textFontSize: rootObj.s(10)
                                        iconFontSize: rootObj.s(12)
                                        onClicked: keybindsTabRoot.testExecute(keybindsTabRoot.editingAction)
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // SECTION 3: SAVE & CANCEL BUTTONS
                        // -----------------------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: rootObj.s(10)

                            Item { Layout.fillWidth: true }

                            ClickButton {
                                Layout.preferredHeight: rootObj.s(34)
                                Layout.preferredWidth: rootObj.s(100)
                                buttonText: I18n.t("guide.keybinds.cancel", "Cancel")
                                accentColor: ThemeBackend.surface2
                                textColor: ThemeBackend.text
                                textFontSize: rootObj.s(11)
                                onClicked: {
                                    keybindsTabRoot.isEditing = false;
                                    keybindsTabRoot.isRecording = false;
                                }
                            }

                            ClickButton {
                                property bool canSave: keybindsTabRoot.keyName.length > 0 && keybindsTabRoot.editingAction.length > 0
                                Layout.preferredHeight: rootObj.s(34)
                                Layout.preferredWidth: rootObj.s(130)
                                buttonText: I18n.t("guide.keybinds.save", "Save & Apply")
                                buttonIcon: "󰄬"
                                accentColor: canSave ? ThemeBackend.green : ThemeBackend.surface2
                                textColor: canSave ? ThemeBackend.crust : ThemeBackend.subtext1
                                textFontSize: rootObj.s(11)
                                iconFontSize: rootObj.s(13)
                                onClicked: keybindsTabRoot.saveKeybind()
                            }
                        }
                    }
                }
            }
        }
    }

    // -----------------------------------------------------------------
    // DELETE CONFIRMATION MODAL OVERLAY (Safe UX)
    // -----------------------------------------------------------------
    Rectangle {
        id: deleteConfirmOverlay
        anchors.fill: parent
        visible: keybindsTabRoot.deletingCombo !== ""
        color: Qt.alpha(ThemeBackend.crust, 0.75)
        z: 90

        Keys.onEscapePressed: keybindsTabRoot.cancelDelete()

        MouseArea {
            anchors.fill: parent
            onClicked: keybindsTabRoot.cancelDelete()
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - rootObj.s(40), rootObj.s(440))
            height: confirmCol.implicitHeight + rootObj.s(36)
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.surface0
            border.color: ThemeBackend.surface1
            border.width: 1

            MouseArea { anchors.fill: parent } // block clicks through

            ColumnLayout {
                id: confirmCol
                anchors.fill: parent
                anchors.margins: rootObj.s(18)
                spacing: rootObj.s(12)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: rootObj.s(10)

                    Rectangle {
                        width: rootObj.s(36)
                        height: rootObj.s(36)
                        radius: rootObj.s(18)
                        color: Qt.alpha(ThemeBackend.red, 0.15)
                        border.color: ThemeBackend.red
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰆴"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(16)
                            color: ThemeBackend.red
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(2)

                        Text {
                            text: I18n.t("guide.keybinds.delete_confirm_title", "Delete Shortcut")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: rootObj.s(15)
                            color: ThemeBackend.text
                        }

                        Text {
                            text: keybindsTabRoot.deletingTitle + " (" + keybindsTabRoot.deletingCombo + ")"
                            font.family: "JetBrains Mono"
                            font.pixelSize: rootObj.s(11)
                            font.bold: true
                            color: ThemeBackend.peach
                        }
                    }
                }

                Text {
                    text: I18n.t("guide.keybinds.delete_confirm_msg", "Are you sure you want to remove this shortcut? This will update your Niri configuration immediately.")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                    color: ThemeBackend.subtext0
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: rootObj.s(10)
                    Layout.topMargin: rootObj.s(6)

                    Item { Layout.fillWidth: true }

                    ClickButton {
                        Layout.preferredHeight: rootObj.s(34)
                        Layout.preferredWidth: rootObj.s(100)
                        buttonText: I18n.t("guide.keybinds.cancel", "Cancel")
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        textFontSize: rootObj.s(11)
                        onClicked: keybindsTabRoot.cancelDelete()
                    }

                    ClickButton {
                        Layout.preferredHeight: rootObj.s(34)
                        Layout.preferredWidth: rootObj.s(110)
                        buttonText: I18n.t("guide.keybinds.delete", "Delete")
                        buttonIcon: "󰆴"
                        accentColor: ThemeBackend.red
                        textColor: ThemeBackend.crust
                        textFontSize: rootObj.s(11)
                        iconFontSize: rootObj.s(13)
                        onClicked: keybindsTabRoot.confirmDelete()
                    }
                }
            }
        }
    }

    // -----------------------------------------------------------------
    // FLOATING TOAST NOTIFICATION WITH UNDO (Feedback UX)
    // -----------------------------------------------------------------
    Rectangle {
        id: toastBadge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: rootObj.s(16)
        anchors.horizontalCenter: parent.horizontalCenter
        height: rootObj.s(36)
        width: toastRowLayout.implicitWidth + rootObj.s(24)
        radius: rootObj.s(18)
        color: ThemeBackend.surface0
        border.color: keybindsTabRoot.toastColor
        border.width: 1
        z: 100

        opacity: keybindsTabRoot.toastVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        transform: Translate {
            y: keybindsTabRoot.toastVisible ? 0 : rootObj.s(10)
            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        }

        RowLayout {
            id: toastRowLayout
            anchors.centerIn: parent
            spacing: rootObj.s(8)

            Text {
                text: keybindsTabRoot.toastIcon
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(14)
                color: keybindsTabRoot.toastColor
            }

            Text {
                text: keybindsTabRoot.toastMessage
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(11)
                font.bold: true
                color: ThemeBackend.text
            }

            // Undo Button in Toast
            Rectangle {
                visible: keybindsTabRoot.toastCanUndo
                height: rootObj.s(22)
                width: undoRow.implicitWidth + rootObj.s(10)
                radius: rootObj.s(11)
                color: undoMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1
                border.color: ThemeBackend.peach
                border.width: 1

                RowLayout {
                    id: undoRow
                    anchors.centerIn: parent
                    spacing: rootObj.s(4)
                    Text {
                        text: "󰕌"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        color: ThemeBackend.peach
                    }
                    Text {
                        text: I18n.t("guide.keybinds.undo", "Undo")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(10)
                        font.bold: true
                        color: ThemeBackend.peach
                    }
                }

                MouseArea {
                    id: undoMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: keybindsTabRoot.restoreBackup()
                }
            }
        }
    }
}
