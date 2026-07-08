import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../components" as Components

Item {
    id: window
    focus: true

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    // -------------------------------------------------------------------------
    // COLORS (Expanded Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0 || "#6c7086"
    readonly property color overlay1: _theme.overlay1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color pink: _theme.pink
    readonly property color red: _theme.red
    readonly property color maroon: _theme.maroon
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color green: _theme.green
    readonly property color teal: _theme.teal
    readonly property color sapphire: _theme.sapphire
    readonly property color blue: _theme.blue

    // -------------------------------------------------------------------------
    // STATE & LOGIC
    // -------------------------------------------------------------------------
    property var allApps: []

    // --- SPECIAL MODE STATE (Calculator / Translator / Dictionary) ---
    property string specialMode: ""     // "calc" | "tran" | "df" | ""
    property string specialResult: ""
    property bool   specialLoading: false
    Timer {
        id: specialQueryDebounce
        interval: 400
        repeat: false
        property string pendingQuery: ""
        onTriggered: window._runSpecialQuery(pendingQuery)
    }

    // Debounce app search to avoid spawning a new process on every keystroke.
    // 120ms is fast enough to feel instant but prevents rapid-fire launches.
    Timer {
        id: appSearchDebounce
        interval: 120
        repeat: false
        property string pendingQuery: ""
        onTriggered: window._runAppSearch(pendingQuery)
    }

    ListModel {
        id: appModel
    }

    // --- HISTORY MANAGEMENT ---
    FileView {
        id: historyFile
        path: Quickshell.env("HOME") + "/.cache/applauncher_history.json"
    }

    function getHistory() {
        try {
            let historyText = historyFile.text();
            if (historyText && historyText.trim().length > 0) {
                return JSON.parse(historyText);
            }
        } catch(e) {}
        return {};
    }

    function saveHistory(history) {
        window.currentHistory = history;
        let path = Quickshell.env("HOME") + "/.cache/applauncher_history.json";
        let data = JSON.stringify(history);
        let escaped = data.replace(/\\/g, "\\\\").replace(/'/g, "'\\''");
        Quickshell.execDetached(["bash", "-c",
            "printf '%s' '" + escaped + "' > " + path + ".tmp && mv " + path + ".tmp " + path]);
    }

    // --- SETTINGS MANAGEMENT (Favorites & Hidden) ---
    property var currentSettings: null
    property var currentHistory: ({})

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.cache/applauncher_settings.json"
        onTextChanged: loadSettings()
    }

    function loadSettings() {
        let settingsText = settingsFile.text();
        if (!settingsText) {
            // Default settings if file doesn't exist yet
            window.currentSettings = { favorites: [], hidden: [] };
            return;
        }
        try {
            let raw = settingsText.trim();
            if (raw.length > 0) {
                let s = JSON.parse(raw);
                window.currentSettings = {
                    favorites: s.favorites || [],
                    hidden:    s.hidden    || []
                };
            } else {
                window.currentSettings = { favorites: [], hidden: [] };
            }
        } catch(e) {
            console.log("Error loading applauncher settings:", e);
            window.currentSettings = { favorites: [], hidden: [] };
        }
        
        // Only re-filter if the launcher is currently visible and the search
        // input exists (avoids a null-ref during Component.onCompleted init).
        if (window.visible && searchInput) filterApps(searchInput.text);
    }

    function saveSettings(settings) {
        // Update in-memory state immediately so UI reflects changes right away.
        // Do NOT rely on settingsFile.onTextChanged to propagate this — that
        // signal fires asynchronously and is unreliable after execDetached writes.
        window.currentSettings = settings;
        filterApps(searchInput.text);
        let path = Quickshell.env("HOME") + "/.cache/applauncher_settings.json";
        // Use a temp file + atomic rename to avoid partial writes corrupting the JSON.
        let data = JSON.stringify(settings);
        let escaped = data.replace(/\\/g, "\\\\").replace(/'/g, "'\\''");
        Quickshell.execDetached(["bash", "-c",
            "printf '%s' '" + escaped + "' > " + path + ".tmp && mv " + path + ".tmp " + path]);
    }

    function toggleFavorite(appName) {
        let s = window.currentSettings;
        let favorites = s.favorites.slice();
        let idx = favorites.indexOf(appName);
        if (idx === -1) favorites.push(appName);
        else favorites.splice(idx, 1);
        saveSettings({ favorites: favorites, hidden: s.hidden });
    }

    function toggleHidden(appName) {
        let s = window.currentSettings;
        let hidden = s.hidden.slice();
        let idx = hidden.indexOf(appName);
        if (idx === -1) hidden.push(appName);
        else hidden.splice(idx, 1);
        saveSettings({ favorites: s.favorites, hidden: hidden });
    }

    // --- KEYBOARD NAV TRACKING (For Smart Highlight Morphing) ---
    property bool isKeyboardNav: false
    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: window.isKeyboardNav = false
    }

    // --- NEW C++ INTEGRATED FILTER ---
    function filterApps(query) {
        if (!window.currentSettings) return; // Wait for settings
        
        window.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        appList.currentIndex = -1;
        appList.positionViewAtBeginning();

        if (handleSpecialQuery(query)) {
            appModel.clear();
            return;
        }

        let q = query.trim();
        if (q === "") {
            // Instant query for empty search: no debounce delay when opening!
            appSearchDebounce.stop();
            window._runAppSearch("");
        } else {
            // Debounce: cancel previous pending search and schedule a new one.
            appSearchDebounce.pendingQuery = q;
            appSearchDebounce.restart();
        }
    }

    function _runAppSearch(q) {
        Components.QsDaemonClient.sendRequest("applauncher", "search", {
            query: q === "" ? "--list" : q
        }, function(results) {
            if (results && Array.isArray(results)) {
                window.processSearchResults(results, q);
            }
        });
    }

    function processSearchResults(results, query) {
        let history = window.currentHistory;
        let settings = window.currentSettings;
        let q = query.trim().toLowerCase();
        let showOnlyHidden = q === ":hidden";

        let hiddenSet = new Set(settings.hidden);
        let favoritesSet = new Set(settings.favorites);

        let filtered = [];
        // Results is an array of objects from C++
        results.forEach(app => {
            let isHidden = hiddenSet.has(app.name);
            if (showOnlyHidden) {
                if (isHidden) filtered.push(app);
            } else {
                if (!isHidden) {
                    // Apply boosts
                    let favoriteBoost = favoritesSet.has(app.name) ? 5000 : 0;
                    let historyBoost = (history[app.name] || 0) * 50;
                    app.finalScore = (app.score || 0) + favoriteBoost + historyBoost;
                    filtered.push(app);
                }
            }
        });

        if (q === "") {
            // Sort by history/favorites for empty query
            filtered.sort((a, b) => {
                let isFavA = favoritesSet.has(a.name) ? 1 : 0;
                let isFavB = favoritesSet.has(b.name) ? 1 : 0;
                if (isFavA !== isFavB) return isFavB - isFavA;
                let scoreA = history[a.name] || 0;
                let scoreB = history[b.name] || 0;
                if (scoreA !== scoreB) return scoreB - scoreA;
                return a.name.localeCompare(b.name);
            });
            filtered = filtered.slice(0, 30);
        } else if (!showOnlyHidden) {
            filtered.sort((a, b) => b.finalScore - a.finalScore);
        }

        let finalApps = filtered.map(a => {
            return {
                name: a.name,
                exec: a.exec,
                icon: a.icon,
                isFavorite: favoritesSet.has(a.name),
                isHidden: hiddenSet.has(a.name)
            };
        });

        // Apply diff to appModel (Existing logic)
        syncModel(finalApps);
    }

    function syncModel(finalApps) {
        // Fast-path: if the result set is very different from what's shown
        // (e.g. user cleared a search), a clear+repopulate is cheaper and
        // avoids the O(n²) position-map update bug on large diffs.
        let targetNames = new Set(finalApps.map(a => a.name));
        let overlapCount = 0;
        for (let i = 0; i < appModel.count; i++) {
            if (targetNames.has(appModel.get(i).name)) overlapCount++;
        }
        let overlapRatio = appModel.count > 0 ? overlapCount / appModel.count : 0;
        if (overlapRatio < 0.5 || appModel.count === 0) {
            appModel.clear();
            for (let i = 0; i < finalApps.length; i++) appModel.append(finalApps[i]);
            if (appModel.count > 0) appList.currentIndex = 0;
            return;
        }

        // Incremental diff path — remove items that are no longer needed.
        for (let i = appModel.count - 1; i >= 0; i--) {
            if (!targetNames.has(appModel.get(i).name)) {
                appModel.remove(i);
            }
        }

        // Rebuild position map after removals (cheap, avoids stale entries).
        function rebuildPos() {
            let m = {};
            for (let i = 0; i < appModel.count; i++) m[appModel.get(i).name] = i;
            return m;
        }
        let currentPos = rebuildPos();

        for (let i = 0; i < finalApps.length; i++) {
            let targetApp = finalApps[i];
            if (i < appModel.count) {
                let currentItem = appModel.get(i);
                if (currentItem.name !== targetApp.name) {
                    let foundIdx = currentPos[targetApp.name];
                    if (foundIdx !== undefined && foundIdx > i) {
                        appModel.move(foundIdx, i, 1);
                        // Rebuild map after every move — positions of shifted items
                        // are invalidated and the map must be fully refreshed.
                        currentPos = rebuildPos();
                        appModel.setProperty(i, "isFavorite", targetApp.isFavorite);
                        appModel.setProperty(i, "isHidden", targetApp.isHidden);
                    } else {
                        appModel.insert(i, targetApp);
                        currentPos = rebuildPos();
                    }
                } else {
                    // Item is in the right place — just refresh mutable flags.
                    appModel.setProperty(i, "isFavorite", targetApp.isFavorite);
                    appModel.setProperty(i, "isHidden", targetApp.isHidden);
                }
            } else {
                appModel.append(targetApp);
                currentPos[targetApp.name] = appModel.count - 1;
            }
        }
        if (appModel.count > 0) appList.currentIndex = 0;
    }

    // --- SPECIAL MODE HELPERS ---

    function tryCalculate(expr) {
        let e = expr.trim()
            .replace(/×/g, "*")
            .replace(/÷/g, "/")
            .replace(/\^/g, "**")
            .replace(/,/g, ".");
        // Whitelist: only allow safe math characters
        if (!/^[\d\s\+\-\*\/\(\)\.\%\*]+$/.test(e)) return null;
        // Must contain at least one operator and one digit
        if (!/\d/.test(e) || !/[\+\-\*\/]/.test(e)) return null;
        try {
            let result = Function('"use strict"; return (' + e + ')')();
            if (!isFinite(result)) return null;
            // Format nicely
            let r = parseFloat(result.toPrecision(12));
            return String(r);
        } catch(_) { return null; }
    }

    function getLangCode(lang) {
        if (!lang) return "vi";
        let map = {
            "vi": "vi", "viet": "vi", "vietnamese": "vi",
            "en": "en", "english": "en", "anh": "en",
            "sp": "es", "es": "es", "spanish": "es",
            "fr": "fr", "french": "fr", "phap": "fr",
            "de": "de", "german": "de", "duc": "de",
            "ja": "ja", "jp": "ja", "japanese": "ja",
            "ko": "ko", "kr": "ko", "korean": "ko",
            "zh": "zh", "cn": "zh", "chinese": "zh", "trung": "zh",
            "it": "it", "italian": "it",
            "pt": "pt", "portuguese": "pt",
            "ru": "ru", "russian": "ru", "nga": "ru",
            "ar": "ar", "arabic": "ar",
            "th": "th", "thai": "th",
            "nl": "nl", "dutch": "nl",
            "pl": "pl", "polish": "pl",
            "tr": "tr", "turkish": "tr",
            "sv": "sv", "swedish": "sv",
            "hi": "hi", "hindi": "hi",
            "id": "id", "indonesian": "id",
        };
        return map[lang.toLowerCase().trim()] || lang.toLowerCase().trim();
    }

    function handleSpecialQuery(query) {
        let q = query.trim();

        // 1. Calculator detection
        let calcResult = tryCalculate(q);
        if (calcResult !== null) {
            window.specialMode = "calc";
            window.specialResult = calcResult;
            window.specialLoading = false;
            specialQueryDebounce.stop();
            return true;
        }

        // 2. Translation: tran <text> [to <lang>]
        let tranMatch = q.match(/^tran\s+(.+)$/i);
        if (tranMatch) {
            let remainder = tranMatch[1].trim();
            let toMatch = remainder.match(/^(.+?)\s+to\s+(\S+)$/i);
            let text, lang;
            if (toMatch) {
                text = toMatch[1].trim();
                lang = getLangCode(toMatch[2]);
            } else {
                text = remainder;
                lang = "vi"; // default to Vietnamese
            }
            window.specialMode = "tran";
            window.specialLoading = true;
            window.specialResult = "";
            specialQueryDebounce.pendingQuery = JSON.stringify({ mode: "tran", text: text, lang: lang });
            specialQueryDebounce.restart();
            return true;
        }

        // 3. Dictionary: df <word>
        let dfMatch = q.match(/^df\s+(.+)$/i);
        if (dfMatch) {
            let word = dfMatch[1].trim();
            window.specialMode = "df";
            window.specialLoading = true;
            window.specialResult = "";
            specialQueryDebounce.pendingQuery = JSON.stringify({ mode: "df", text: word });
            specialQueryDebounce.restart();
            return true;
        }

        // 4. Keycast Toggle: key on / key off
        if (q === "key on" || q === "key off") {
            window.specialMode = "keycast";
            window.specialResult = q === "key on" ? "Press Enter to turn keycast ON" : "Press Enter to turn keycast OFF";
            window.specialLoading = false;
            specialQueryDebounce.stop();
            return true;
        }

        // No match
        window.specialMode = "";
        specialQueryDebounce.stop();
        return false;
    }

    function _runSpecialQuery(pendingJson) {
        try {
            let p = JSON.parse(pendingJson);
            window.specialLoading = true;
            window.specialResult = "";
            
            let extraParam = (p.mode === "tran") ? p.lang : "";
            
            Components.QsDaemonClient.sendRequest("applauncher", "tools", {
                mode: p.mode,
                query: p.text,
                extra: extraParam
            }, function(data) {
                if (data && data.result !== undefined) {
                    window.specialResult = data.result;
                } else {
                    window.specialResult = "No result";
                }
                window.specialLoading = false;
            });
        } catch(_) {
            window.specialLoading = false;
            window.specialResult = "Error";
        }
    }

    function launchApp(appName, execStr) {
        // Update history
        let history = getHistory();
        history[appName] = (history[appName] || 0) + 1;
        saveHistory(history);

        // Run via shell instead of direct exec to avoid compositor dispatch quirks.
        Quickshell.execDetached(["bash", "-c", "unset HL_INITIAL_WORKSPACE_TOKEN && " + execStr]);
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
    }

    // --- AGGRESSIVE FOCUS MANAGEMENT ---
    Timer {
        id: focusTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                focusTimer.restart();
                introPhaseAnim.restart();
                // Reload settings + history from disk every time the launcher opens.
                // This is the fix for favorites/hidden not persisting across sessions:
                // FileView.onTextChanged only fires if Qt detects a change, which is
                // unreliable after an external write. Forcing reload ensures we always
                // have the latest data before filterApps runs.
                settingsFile.reload();
                window.currentHistory = getHistory();
                searchInput.text = "";
                filterApps("");
            }
        }
    }

    Component.onCompleted: {
        loadSettings();
        window.currentHistory = getHistory();
    }

    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
        event.accepted = true;
    }



    // --- MAIN INTRO ANIMATION ---
    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 100; easing.type: Easing.OutQuad; running: true
    }

    // -------------------------------------------------------------------------
    // CONTEXT MENU
    // -------------------------------------------------------------------------
    Menu {
        id: appContextMenu
        property string targetAppName: ""
        property bool isFavorite: false
        property bool isHidden: false

        width: window.s(180)

        background: Rectangle {
            implicitWidth: window.s(180)
            color: window.base
            border.color: window.surface1
            radius: window.s(12)
            
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0,0,0,0.3)
                shadowBlur: 0.5
                shadowVerticalOffset: 4
            }
        }

        delegate: MenuItem {
            id: menuItem
            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: window.s(12)
                anchors.rightMargin: window.s(12)
                spacing: window.s(10)
                
                Text {
                    text: menuItem.text === "Mark as Favorite" ? "" : 
                          menuItem.text === "Unmark Favorite" ? "󰓎" :
                          menuItem.text === "Hide App" ? "󰈈" : "󰈉"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: window.s(16)
                    color: menuItem.highlighted ? window.crust : window.mauve
                }

                Text {
                    text: menuItem.text
                    color: menuItem.highlighted ? window.crust : window.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(13)
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                implicitHeight: window.s(40)
                color: menuItem.highlighted ? window.mauve : "transparent"
                radius: window.s(8)
                anchors.margins: window.s(4)
            }
        }

        Action {
            text: appContextMenu.isFavorite ? "Unmark Favorite" : "Mark as Favorite"
            onTriggered: toggleFavorite(appContextMenu.targetAppName)
        }
        Action {
            text: appContextMenu.isHidden ? "Unhide App" : "Hide App"
            onTriggered: toggleHidden(appContextMenu.targetAppName)
        }
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Rectangle {
        id: mainBg
        width: parent.width
        
        // --- DYNAMIC HEIGHT CALCULATION (Bottom-up Shrinking) ---
        property real searchHeight: window.s(65)
        property real separatorHeight: 1
        property real itemHeight: window.s(60)
        property real listSpacing: window.s(4)
        property real maxListHeight: (8 * itemHeight) + (7 * listSpacing)
        property real emptyStateHeight: window.s(180)
        property real specialModeHeight: window.s(220)
        
        property real targetListHeight: {
            if (window.specialMode !== "") return specialModeHeight;
            if (appModel.count === 0) {
                return (searchInput.text && searchInput.text.trim().length > 0) ? emptyStateHeight : 0;
            }
            return Math.min((appModel.count * itemHeight) + ((appModel.count - 1) * listSpacing), maxListHeight);
        }
        property real targetMargins: (window.specialMode !== "" || appModel.count > 0 || (searchInput.text && searchInput.text.trim().length > 0)) ? window.s(20) : 0

        // Smoothly animated properties for elegant container morphing
        property real animatedListHeight: targetListHeight
        property real animatedMargins: targetMargins

        Behavior on animatedListHeight { 
            NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 0.5 } 
        }
        Behavior on animatedMargins { 
            NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 0.5 } 
        }
        
        height: searchHeight + separatorHeight + animatedMargins + animatedListHeight

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        radius: window.s(16)
        color: Qt.rgba(window.base.r, window.base.g, window.base.b, 1.0)
        border.color: window.surface1
        border.width: 1
        clip: true

        transform: Translate { y: (window.introPhase - 1) * window.s(20) }
        opacity: window.introPhase

        OrbitBackground {
            color1: window.mauve
            color2: window.blue
            orbitScale: window.s(1)
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // --- SEARCH BAR ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: mainBg.searchHeight
                color: "transparent"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(15)
                    anchors.leftMargin: window.s(20)
                    anchors.rightMargin: window.s(20)
                    spacing: window.s(15)

                    Text {
                        text: ""
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(18)
                        color: searchInput.activeFocus ? window.mauve : window.subtext0
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        background: Item {} 
                        color: window.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(16)
                        
                        placeholderText: "Search..."
                        placeholderTextColor: window.subtext0 
                        
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true

                        onTextChanged: filterApps(text)

                        Keys.onDownPressed: {
                            window.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (appList.currentIndex < appModel.count - 1) {
                                appList.currentIndex++;
                            }
                            event.accepted = true;
                        }
                        Keys.onUpPressed: {
                            window.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (appList.currentIndex > 0) {
                                appList.currentIndex--;
                            }
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: {
                            if (window.specialMode === "keycast") {
                                let cmd = (window.specialResult.indexOf("ON") !== -1) ? "1" : "0";
                                let runtimeDir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
                                let keycastDir = runtimeDir + "/quickshell/keycast";
                                Quickshell.execDetached(["bash", "-c", "mkdir -p " + keycastDir + " && echo '" + cmd + "' > " + keycastDir + "/enabled"]);
                                Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
                            } else if (window.specialMode !== "" && !window.specialLoading) {
                                let content = window.specialResult;
                                Quickshell.execDetached(["bash", "-c", "printf '%s' '" + content.replace(/'/g, "'\\''") + "' | wl-copy"]);
                                Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
                            } else if (appList.currentIndex >= 0 && appList.currentIndex < appModel.count) {
                                let item = appModel.get(appList.currentIndex);
                                launchApp(item.name, item.exec);
                            }
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: {
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
                            event.accepted = true;
                        }
                    }
                }
            }

            // --- SEPARATOR ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: mainBg.separatorHeight
                color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5)
            }

            // --- RESULT CARD (Calculator / Translation / Dictionary) ---
            Item {
                id: resultCard
                Layout.fillWidth: true
                Layout.preferredHeight: mainBg.animatedListHeight
                visible: window.specialMode !== ""

                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Column {
                    anchors.centerIn: parent
                    spacing: window.s(14)
                    width: parent.width - window.s(48)

                    // Mode badge
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: window.s(6)

                        Text {
                            text: window.specialMode === "calc" ? "󰃫"
                                : window.specialMode === "tran" ? "󱀿"
                                : "󰩫"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(16)
                            color: window.specialMode === "calc" ? window.green
                                 : window.specialMode === "tran" ? window.blue
                                 : window.mauve
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: window.specialMode === "calc" ? "Calculator"
                                : window.specialMode === "tran" ? "Translation"
                                : "Dictionary"
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(11)
                            color: window.subtext0
                            opacity: 0.8
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Separator line
                    Rectangle {
                        width: parent.width * 0.5
                        height: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: window.surface1
                        opacity: 0.6
                    }

                    // Result / Loading text
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: window.specialLoading ? "..." : window.specialResult
                        font.family: window.specialMode === "df" ? "JetBrains Mono" : "JetBrains Mono"
                        font.pixelSize: window.specialMode === "calc" ? window.s(36)
                                      : window.specialMode === "tran" ? window.s(22)
                                      : window.s(13)
                        color: window.specialMode === "calc" ? window.green
                             : window.specialMode === "tran" ? window.text
                             : window.subtext0
                        opacity: window.specialLoading ? 0.4 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        lineHeight: 1.5
                    }
                }
            }

            // --- EMPTY STATE ---
            Item {
                id: emptyState
                Layout.fillWidth: true
                Layout.preferredHeight: mainBg.animatedListHeight
                visible: window.specialMode === "" && appModel.count === 0 && searchInput.text.trim().length > 0
                
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Column {
                    anchors.centerIn: parent
                    spacing: window.s(12)
                    width: parent.width

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰈻"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(48)
                        color: window.mauve
                        opacity: 0.6
                    }
                    
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No results for \"" + searchInput.text + "\""
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(15)
                        color: window.subtext0
                        opacity: 0.8
                    }
                }
            }

            // --- APPLICATION LIST ---
            ListView {
                id: appList
                Layout.fillWidth: true
                visible: appModel.count > 0
                
                Layout.preferredHeight: mainBg.animatedListHeight
                Layout.topMargin: mainBg.animatedMargins / 2
                Layout.bottomMargin: mainBg.animatedMargins / 2
                Layout.leftMargin: window.s(10)
                Layout.rightMargin: window.s(10)
                
                // clip: true is critical — it masks items that are outside the
                // visible list area so they cannot bleed through during transitions.
                clip: true
                model: appModel
                spacing: mainBg.listSpacing
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                highlightFollowsCurrentItem: false

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                // --- LIST ITEM TRANSITIONS ---
                // Key fix: NO z-layer tricks. The ListView's own clip:true handles
                // masking. Items animate only opacity + scale so they never visually
                // "hang" outside the clipped region. The displaced transition slides
                // existing items to their new positions without fighting the add/remove.

                populate: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 80 }
                        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 100 }
                    }
                }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 60 }
                        NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: 80 }
                    }
                }
                
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 50 }
                        NumberAnimation { property: "scale"; to: 0.98; duration: 60 }
                    }
                }
                
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 80; easing.type: Easing.OutQuad }
                }

                ScrollBar.vertical: ScrollBar {
                    id: scrollBar
                    active: true
                    policy: ScrollBar.AsNeeded
                    
                    background: Rectangle {
                        implicitWidth: window.s(12)
                        color: "transparent"
                    }

                    contentItem: Item {
                        implicitWidth: window.s(12)
                        
                        Rectangle {
                            anchors.centerIn: parent
                            height: parent.height
                            width: (scrollBar.hovered || scrollBar.active) ? window.s(8) : window.s(4)
                            radius: width / 2
                            
                            color: (scrollBar.hovered || scrollBar.active) ? window.mauve : window.surface2
                            opacity: (scrollBar.hovered || scrollBar.active) ? 0.9 : 0.4

                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                        }
                    }
                }


                // --- MATTE MORPHING HIGHLIGHT ---
                highlight: Item {
                    z: 0 
                    
                    Rectangle {
                        id: activeHighlight
                        x: 0
                        width: appList.width
                        radius: window.s(8)
                        color: window.mauve

                        property int prevIdx: 0
                        property int curIdx: appList.currentIndex

                        onCurIdxChanged: {
                            if (curIdx === -1) return; 
                            
                            if (curIdx > prevIdx) {
                                bottomAnim.duration = 250; topAnim.duration = 450;
                            } else if (curIdx < prevIdx) {
                                topAnim.duration = 250; bottomAnim.duration = 450;
                            }
                            prevIdx = curIdx;
                        }

                        // Track the current item's ACTUAL coordinates so it sticks mid-flight
                        property real targetTop: appList.currentItem ? appList.currentItem.y : 0
                        property real targetBottom: appList.currentItem ? (appList.currentItem.y + appList.currentItem.height) : 0

                        property real actualTop: targetTop
                        property real actualBottom: targetBottom

                        // Only enable the morphed lagging behavior during keyboard navigation.
                        // During search/diffing, it will instantly track the moving item.
                        Behavior on actualTop { 
                            enabled: window.isKeyboardNav
                            NumberAnimation { id: topAnim; easing.type: Easing.OutExpo } 
                        }
                        Behavior on actualBottom { 
                            enabled: window.isKeyboardNav
                            NumberAnimation { id: bottomAnim; easing.type: Easing.OutExpo } 
                        }

                        y: actualTop
                        height: actualBottom - actualTop
                        
                        // Makes the highlight respect the item's pop-in scale animation
                        scale: appList.currentItem ? appList.currentItem.scale : 1
                        
                        opacity: appList.count > 0 && appList.currentIndex >= 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                }

                delegate: Item {
                    width: ListView.view.width
                    height: mainBg.itemHeight
                    z: 1 
                    
                    transformOrigin: Item.Center 

                    Rectangle {
                        anchors.fill: parent
                        radius: window.s(8)
                        color: "transparent"
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: window.s(8)
                            color: window.surface0
                            opacity: ma.containsMouse && index !== appList.currentIndex ? 0.4 : 0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: window.s(10)
                            anchors.leftMargin: window.s(12)
                            spacing: window.s(15)

                            // --- TINTED ICON MATTE BOX ---
                            Rectangle {
                                Layout.preferredWidth: window.s(40)
                                Layout.preferredHeight: window.s(40)
                                radius: window.s(12)
                                
                                color: index === appList.currentIndex ? window.crust : window.surface0
                                border.width: 0 
                                clip: true
                                
                                property real activeScale: index === appList.currentIndex ? 1.15 : 1
                                scale: activeScale
                                Behavior on activeScale { 
                                    NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.5 } 
                                }
                                Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutExpo } }

                                // Fallback icon (shown when Image is loading or failed)
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰀻"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(22)
                                    color: index === appList.currentIndex ? window.crust : window.mauve
                                    opacity: (appIcon.status !== Image.Ready) ? 0.6 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                Image {
                                    id: appIcon
                                    anchors.centerIn: parent
                                    width: window.s(24)
                                    height: window.s(24)
                                    
                                    // Use a property to ensure model.icon is evaluated only once
                                    // and provides a clean binding for the source.
                                    readonly property string iconPath: model.icon || ""

                                    // cache: true allows Qt to reuse cached icon textures
                                    // for buttery-smooth list view scrolling and rendering.
                                    cache: true
                                    source: iconPath === "" ? "" : 
                                            (iconPath.startsWith("/") ? "file://" + iconPath : "image://icon/" + iconPath)
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: false
                                    smooth: true
                                    mipmap: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                
                                // The Matugen Tint Overlay
                                Rectangle {
                                    anchors.fill: parent
                                    radius: window.s(12) 
                                    
                                    color: window.mauve
                                    opacity: index === appList.currentIndex ? 0.25 : 0.08 
                                    
                                    Behavior on opacity { 
                                        NumberAnimation { duration: 300; easing.type: Easing.OutExpo } 
                                    }
                                }
                            }

                            Text {
                                id: appNameText
                                Layout.fillWidth: true
                                text: model.name
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(14)
                                font.weight: index === appList.currentIndex ? Font.Bold : Font.Medium
                                color: index === appList.currentIndex ? window.crust : window.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                
                                property real textShift: index === appList.currentIndex ? window.s(6) : 0
                                transform: Translate { x: appNameText.textShift }
                                
                                Behavior on textShift { 
                                    NumberAnimation { duration: 500; easing.type: Easing.OutExpo } 
                                }
                                Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutExpo } }
                            }

                            Text {
                                text: ""
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(14)
                                color: index === appList.currentIndex ? window.crust : window.mauve
                                visible: model.isFavorite
                                opacity: visible ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    appContextMenu.targetAppName = model.name;
                                    appContextMenu.isFavorite = model.isFavorite;
                                    appContextMenu.isHidden = model.isHidden;
                                    appContextMenu.popup();
                                } else {
                                    appList.currentIndex = index;
                                    launchApp(model.name, model.exec);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


