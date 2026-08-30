import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../reusables"
import "../WindowRegistry.js" as WindowRegistry

PanelWindow {
    id: launcherWindow

    screen: LauncherController.screen

    WlrLayershell.namespace: "qs-applauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: launcherWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {
        item: (launcherWindow.isVisible || container.animProgress > 0.001) ? maskBoundary : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    function closeLauncher() {
        LauncherController.hide();
    }

    property bool isVisible: LauncherController.isVisible
    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            LauncherController.hide();
            launcherWindow.configRevision++;
        }
    }

    Connections {
        target: (typeof I18n !== "undefined") ? I18n : null
        function onLanguageChanged() {
            launcherWindow.loadApps();
            launcherWindow.executeFilter(searchInput.text);
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            launcherWindow.loadApps();
            launcherWindow.executeFilter(searchInput.text);
        }
        function onCountChanged() {
            launcherWindow.loadApps();
            launcherWindow.executeFilter(searchInput.text);
        }
    }

    Component.onCompleted: {
        loadApps();
        executeFilter("");
    }

    property var defaultLauncherSettings: ({
        "position": "top",
        "width": 600,
        "itemCount": 6,
        "terminalCommand": "kitty -e",
        "smartRanking": true
    })

    property var rawLauncherSettings: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.launcher) {
            return Config.rawSettings.launcher;
        }
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("launcher", defaultLauncherSettings);
        }
        return defaultLauncherSettings;
    }

    property string launcherPosition: (rawLauncherSettings && rawLauncherSettings.position !== undefined) ? rawLauncherSettings.position : "top"
    property real customWidth: (rawLauncherSettings && rawLauncherSettings.width !== undefined && !isNaN(rawLauncherSettings.width) && rawLauncherSettings.width > 0) ? rawLauncherSettings.width : 600
    property int customItemCount: (rawLauncherSettings && rawLauncherSettings.itemCount !== undefined && !isNaN(rawLauncherSettings.itemCount) && rawLauncherSettings.itemCount > 0) ? rawLauncherSettings.itemCount : 6
    property string terminalCommand: (rawLauncherSettings && rawLauncherSettings.terminalCommand !== undefined) ? rawLauncherSettings.terminalCommand : "kitty -e"
    property bool smartRanking: (rawLauncherSettings && rawLauncherSettings.smartRanking !== undefined) ? rawLauncherSettings.smartRanking : true

    onSmartRankingChanged: {
        loadApps();
        executeFilter(searchInput.text);
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }

    property string barPosition: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "top";
        return Config.rawSettings.bar.position || "top";
    }

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }

    property bool isBarSolid: barStyle === "solid" || barStyle === "fill"
    property bool barMatchesLauncher: isBarSolid && (attachEdge === barPosition)

    property string attachEdge: launcherPosition

    onAttachEdgeChanged: {
        LauncherController.hide();
    }

    onBarStyleChanged: {
        LauncherController.hide();
    }

    onBarPositionChanged: {
        LauncherController.hide();
    }

    property bool isSideAttached: attachEdge === "left" || attachEdge === "right"

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real outerCornerRadius: cornerRadius

    property real baseLauncherWidth: s(customWidth)
    property real baseLauncherHeight: s(70) + (customItemCount * s(48))

    visible: isVisible || container.animProgress > 0.001

    property var allApps: []
    property var usageRanks: ({ "focus": {}, "launch": {}, "context": {} })
    property bool isKeyboardNav: false
    property string pendingQuery: ""

    function grabInputFocus() {
        searchInput.forceActiveFocus();
        if (typeof searchInput.forceInputFocus === "function") {
            searchInput.forceInputFocus();
        }
    }

    Process {
        id: rankFetcher
        running: false
        command: Caching.qsDir ? ["python3", Caching.qsDir + "/launcher/app_rank.py", "--rank"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        launcherWindow.usageRanks = JSON.parse(this.text);
                        launcherWindow.loadApps();
                        executeFilter(searchInput.text);
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 120
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusFinalTimer
        interval: 250
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: {
            launcherWindow.isKeyboardNav = false;
        }
    }

    Timer {
        id: filterDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            executeFilter(launcherWindow.pendingQuery);
        }
    }

    onIsVisibleChanged: {
        if (isVisible) {
            searchInput.clear();
            filterDebounceTimer.stop();
            loadApps();
            executeFilter("");
            if (launcherWindow.smartRanking) {
                rankFetcher.running = false;
                rankFetcher.running = true;
            }
            launcherWindow.grabInputFocus();
            focusTimer.restart();
            focusRetryTimer.restart();
            focusFinalTimer.restart();
        } else {
            filterDebounceTimer.stop();
            focusTimer.stop();
            focusRetryTimer.stop();
            focusFinalTimer.stop();
            keyboardNavTimer.stop();
        }
    }

    function evaluateMath(expr) {
        if (!expr) return null;
        let trimmed = expr.trim();
        if (trimmed.length === 0 || trimmed.startsWith(">")) return null;

        let parsed = trimmed
            .replace(/×/g, "*")
            .replace(/÷/g, "/")
            .replace(/\bpi\b/gi, "Math.PI")
            .replace(/\be\b/gi, "Math.E")
            .replace(/\bsqrt\b/gi, "Math.sqrt")
            .replace(/\bsin\b/gi, "Math.sin")
            .replace(/\bcos\b/gi, "Math.cos")
            .replace(/\btan\b/gi, "Math.tan")
            .replace(/\babs\b/gi, "Math.abs")
            .replace(/\blog\b/gi, "Math.log")
            .replace(/\bpow\b/gi, "Math.pow")
            .replace(/\^/g, "**");

        let testStr = parsed.replace(/Math\.(PI|E|sqrt|sin|cos|tan|abs|log|pow)/g, "");
        if (!/^[\d\s\+\-\*\/\%\(\)\.\,]+$/.test(testStr)) {
            return null;
        }

        if (!/[\+\-\*\/\%\^]/.test(trimmed) && !/\b(sqrt|sin|cos|tan|abs|log|pow|pi|e)\b/i.test(trimmed)) {
            return null;
        }

        try {
            let res = Function('"use strict"; return (' + parsed + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return Number(Math.round(res * 1e12) / 1e12).toString();
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    function loadApps() {
        let arr = [];

        if (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values) {
            let entries = DesktopEntries.applications.values;
            for (let i = 0; i < entries.length; i++) {
                let e = entries[i];
                if (e.noDisplay) continue;

                let score = 0;
                if (launcherWindow.smartRanking) {
                    let wmclassLower = (e.startupClass || "").toLowerCase();
                    let baseName = e.id.toLowerCase().replace(".desktop", "");
                    let appNameLower = (e.name || "").toLowerCase();

                    let f_score = usageRanks.focus[wmclassLower] || 0;
                    if (f_score === 0) f_score = usageRanks.focus[baseName] || 0;
                    if (f_score === 0) f_score = usageRanks.focus[appNameLower] || 0;

                    let l_score = usageRanks.launch[e.name] || 0;

                    let c_score = (usageRanks.context && usageRanks.context[wmclassLower]) || 0;
                    if (c_score === 0) c_score = (usageRanks.context && usageRanks.context[baseName]) || 0;
                    if (c_score === 0) c_score = (usageRanks.context && usageRanks.context[appNameLower]) || 0;

                    score = f_score + l_score + (0.5 * c_score);
                }

                arr.push({
                    name: e.name,
                    description: e.comment || "",
                    desktop_id: e.id,
                    icon: e.icon || "",
                    fontIcon: "",
                    score: score,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: ""
                });
            }
        }

        let widgetList = (typeof WindowRegistry !== "undefined" && WindowRegistry.getWidgetLauncherEntries)
            ? WindowRegistry.getWidgetLauncherEntries(typeof I18n !== "undefined" ? I18n : null)
            : [];

        for (let j = 0; j < widgetList.length; j++) {
            let w = widgetList[j];
            let wScore = 0;
            if (launcherWindow.smartRanking) {
                wScore = (usageRanks.launch && (usageRanks.launch[w.id] || usageRanks.launch[w.name] || usageRanks.launch["qs-widget-" + w.id])) || 0;
            }
            arr.push({
                name: w.name,
                description: w.description || "",
                desktop_id: "qs-widget-" + w.id,
                icon: w.icon || "",
                fontIcon: w.fontIcon || "",
                score: wScore,
                isCommand: false,
                command: "",
                isCalc: false,
                calcResult: "",
                isWidget: true,
                widgetTarget: w.id
            });
        }

        arr.sort(function(a, b) {
            if (launcherWindow.smartRanking && a.score !== b.score) {
                return b.score - a.score;
            }
            return a.name.localeCompare(b.name);
        });

        let unique = {};
        let finalArr = [];
        for (let i = 0; i < arr.length; i++) {
            if (!unique[arr[i].name]) {
                unique[arr[i].name] = true;
                finalArr.push(arr[i]);
            }
        }

        launcherWindow.allApps = finalArr;
    }

    ListModel {
        id: appModel
    }

    function filterApps(query) {
        launcherWindow.pendingQuery = query;
        filterDebounceTimer.restart();
    }

    function isSubsequence(sub, str) {
        let i = 0;
        let j = 0;
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j]) {
                i++;
            }
            j++;
        }
        return i === sub.length;
    }

    function executeFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let rawTrimmed = query.trim();
        let q = query.toLowerCase().trim();
        let filtered = [];

        if (rawTrimmed.startsWith(">")) {
            let cmd = rawTrimmed.substring(1).trim();
            if (cmd.length > 0) {
                filtered.push({
                    name: "> " + cmd,
                    description: typeof I18n !== "undefined" ? I18n.t("applauncher.command_run", { cmd: cmd }) : ("Execute command: " + cmd),
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: true,
                    command: cmd,
                    isCalc: false,
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: ""
                });
            } else {
                filtered.push({
                    name: "> ...",
                    description: typeof I18n !== "undefined" ? I18n.t("applauncher.command_hint") : "Type a command to execute",
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: ""
                });
            }
        }

        let mathResult = evaluateMath(rawTrimmed);
        if (mathResult !== null) {
            filtered.push({
                name: rawTrimmed + " = " + mathResult,
                description: typeof I18n !== "undefined" ? I18n.t("applauncher.calc_result") : "Calculation result (Enter to copy)",
                desktop_id: "",
                icon: "",
                fontIcon: "󰃬",
                score: 9000000,
                isCommand: false,
                command: "",
                isCalc: true,
                calcResult: mathResult,
                isWidget: false,
                widgetTarget: ""
            });
        }

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i];
            let nameLower = app.name ? app.name.toLowerCase() : "";
            let descLower = app.description ? app.description.toLowerCase() : "";

            let matchQuality = 0;
            let matches = false;

            if (q.length === 0) {
                matches = true;
            } else if (!rawTrimmed.startsWith(">")) {
                if (nameLower === q) {
                    matchQuality = 100000;
                    matches = true;
                } else if (nameLower.startsWith(q)) {
                    matchQuality = 50000;
                    matches = true;
                } else if (nameLower.includes(q)) {
                    matchQuality = 10000;
                    matches = true;
                } else if (descLower.includes(q)) {
                    matchQuality = 5000;
                    matches = true;
                } else if (isSubsequence(q, nameLower)) {
                    matchQuality = 1000;
                    matches = true;
                }
            }

            if (matches) {
                let appCopy = {
                    name: app.name,
                    description: app.description,
                    desktop_id: app.desktop_id,
                    icon: app.icon,
                    fontIcon: app.fontIcon || "",
                    score: app.score + matchQuality,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    calcResult: "",
                    isWidget: app.isWidget || false,
                    widgetTarget: app.widgetTarget || ""
                };
                filtered.push(appCopy);
            }
        }

        if (q.length > 0) {
            filtered.sort(function(a, b) {
                if (a.score !== b.score) {
                    return b.score - a.score;
                }
                return a.name.localeCompare(b.name);
            });
        }

        appModel.clear();
        for (let i = 0; i < filtered.length; i++) {
            appModel.append(filtered[i]);
        }

        if (appModel.count > 0) {
            appList.currentIndex = 0;
        } else {
            appList.currentIndex = -1;
        }
    }

    function activateIndex(index) {
        if (index < 0 || index >= appModel.count) return;
        let item = appModel.get(index);
        if (!item) return;

        if (item.isCommand) {
            if (item.command && item.command.trim().length > 0) {
                let term = launcherWindow.terminalCommand ? launcherWindow.terminalCommand.trim() : "";
                let fullCmd = term !== "" ? (term + " " + item.command) : item.command;
                Quickshell.execDetached(["bash", "-c", fullCmd]);
            }
            closeLauncher();
            return;
        }

        if (item.isCalc) {
            Quickshell.execDetached(["wl-copy", "--", item.calcResult]);
            closeLauncher();
            return;
        }

        if (item.isWidget) {
            launchWidget(item.name, item.widgetTarget);
            return;
        }

        launchApp(item.name, item.desktop_id);
    }

    function launchWidget(widgetName, widgetTarget) {
        if (Caching.qsDir) {
            Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/qs_manager.sh", "open", widgetTarget]);
        } else {
            Quickshell.execDetached(["qs_manager", "open", widgetTarget]);
        }
        closeLauncher();
    }

    function launchApp(appName, desktopId) {
        let entry = DesktopEntries.byId(desktopId);
        if (entry) {
            entry.execute();
        }
        if (Caching.qsDir) {
            Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", appName]);
        }
        closeLauncher();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: closeLauncher()
    }

    Item {
        id: maskBoundary
        x: container.x - launcherWindow.outerCornerRadius
        y: container.y - launcherWindow.outerCornerRadius
        width: container.width + (launcherWindow.outerCornerRadius * 2)
        height: container.height + (launcherWindow.outerCornerRadius * 2)
    }

    Item {
        id: container

        property real animProgress: launcherWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: launcherWindow.isVisible ? 360 : 220
                easing.type: launcherWindow.isVisible ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.08
            }
        }

        property real dynamicCornerRadius: Math.max(0, Math.min(launcherWindow.outerCornerRadius, (launcherWindow.isSideAttached ? width : height) * 0.5))

        x: {
            if (launcherWindow.attachEdge === "left") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
            }
            if (launcherWindow.attachEdge === "right") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
                return (launcherWindow.width - offset) - width;
            }
            return Math.floor((launcherWindow.width - launcherWindow.baseLauncherWidth) / 2);
        }
        y: {
            if (launcherWindow.attachEdge === "top") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
            }
            if (launcherWindow.attachEdge === "bottom") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
                return (launcherWindow.height - offset) - height;
            }
            return Math.floor((launcherWindow.height - launcherWindow.baseLauncherHeight) / 2);
        }
        width: launcherWindow.isSideAttached
               ? (launcherWindow.baseLauncherWidth * animProgress)
               : launcherWindow.baseLauncherWidth
        height: !launcherWindow.isSideAttached
                ? (launcherWindow.baseLauncherHeight * animProgress)
                : launcherWindow.baseLauncherHeight

        opacity: (launcherWindow.isVisible || animProgress > 0.001) ? 1.0 : 0.0

        Shape {
            visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
            x: -container.dynamicCornerRadius
            y: 0
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
            x: parent.width
            y: 0
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
            x: -container.dynamicCornerRadius
            y: parent.height - container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: container.dynamicCornerRadius
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
            x: parent.width
            y: parent.height - container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: container.dynamicCornerRadius
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
            x: 0
            y: -container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
            x: 0
            y: parent.height
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: container.dynamicCornerRadius
                PathLine { x: 0; y: 0 }
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
            x: parent.width - container.dynamicCornerRadius
            y: -container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: 0
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
            x: parent.width - container.dynamicCornerRadius
            y: parent.height
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: container.dynamicCornerRadius
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: container.dynamicCornerRadius
            color: ThemeBackend.base
            border.width: 0
            border.color: "transparent"
            clip: true

            Rectangle {
                visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: launcherWindow.s(14)
                spacing: launcherWindow.s(10)

                Input {
                    id: searchInput
                    focus: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: launcherWindow.s(36)

                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: launcherWindow.s(12)
                    charSpacing: 1

                    placeholderText: typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder", "Start with > for a command...") : "Start with > for a command..."
                    showClearButton: true

                    onTextEdited: function(newText) {
                        filterApps(newText);
                    }
                    onCleared: filterApps("")

                    Keys.onDownPressed: function(event) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (appList.currentIndex < appModel.count - 1) {
                            appList.currentIndex++;
                        }
                        event.accepted = true;
                    }
                    Keys.onUpPressed: function(event) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (appList.currentIndex > 0) {
                            appList.currentIndex--;
                        }
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: function(event) {
                        activateIndex(appList.currentIndex);
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: function(event) {
                        closeLauncher();
                        event.accepted = true;
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: appList
                        anchors.fill: parent
                        clip: true
                        model: appModel
                        spacing: launcherWindow.s(4)
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        highlightFollowsCurrentItem: false

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }

                        Rectangle {
                            id: morphHighlight
                            parent: appList.contentItem
                            z: 0
                            visible: appList.count > 0 && appList.currentIndex >= 0 && appList.currentItem !== null
                            x: 0
                            width: appList.width
                            height: launcherWindow.s(44)
                            radius: ThemeBackend.borderRadius
                            color: ThemeBackend.mauve

                            property real targetY: (appList.currentIndex >= 0 && appList.currentItem) ? appList.currentItem.y : 0
                            y: targetY

                            Behavior on y {
                                NumberAnimation {
                                    duration: 320
                                    easing.type: Easing.OutQuint
                                }
                            }
                        }

                        delegate: Item {
                            id: delegateRoot
                            width: ListView.view.width
                            height: launcherWindow.s(44)
                            clip: true
                            z: 1

                            property bool isSelected: index === appList.currentIndex

                            scale: ma.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                            Rectangle {
                                anchors.fill: parent
                                radius: ThemeBackend.borderRadius
                                color: ThemeBackend.surface0
                                opacity: ma.containsMouse && !delegateRoot.isSelected ? 0.45 : 0
                                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutSine } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: launcherWindow.s(6)
                                anchors.leftMargin: launcherWindow.s(10) + (delegateRoot.isSelected ? launcherWindow.s(2) : 0)
                                anchors.rightMargin: launcherWindow.s(10)
                                spacing: launcherWindow.s(10)

                                Behavior on anchors.leftMargin {
                                    NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
                                }

                                Item {
                                    id: delegateIconArea
                                    Layout.preferredWidth: launcherWindow.s(32)
                                    Layout.preferredHeight: launcherWindow.s(32)
                                    Layout.alignment: Qt.AlignVCenter

                                    readonly property real boxRadius: launcherWindow.s(8)
                                    readonly property real boxPadding: launcherWindow.s(4)

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.topMargin: launcherWindow.s(1.5)
                                        anchors.bottomMargin: -launcherWindow.s(1.5)
                                        radius: parent.boxRadius
                                        color: Qt.rgba(0, 0, 0, 0.12)
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.boxRadius
                                        color: delegateRoot.isSelected ? Qt.tint(ThemeBackend.surface2, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2)) : ThemeBackend.surface2

                                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    Rectangle {
                                        id: iconContainer
                                        anchors.fill: parent
                                        anchors.margins: parent.boxPadding
                                        radius: Math.max(0, parent.boxRadius - parent.boxPadding)
                                        color: "transparent"
                                        clip: true

                                        Image {
                                            id: delegateIcon
                                            anchors.fill: parent
                                            property bool failedLoad: false

                                            visible: (!model.fontIcon || model.fontIcon === "") && source !== "" && status === Image.Ready && !failedLoad

                                            source: {
                                                if (model.fontIcon && model.fontIcon !== "") return "";
                                                let ic = model.icon || "";
                                                if (!ic) return "";
                                                if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                                return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                                            }

                                            sourceSize: Qt.size(64, 64)
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            smooth: true
                                            mipmap: true

                                            onStatusChanged: {
                                                if (status === Image.Error) {
                                                    failedLoad = true;
                                                }
                                            }
                                        }

                                        Text {
                                            id: delegateFontIcon
                                            anchors.centerIn: parent
                                            visible: !delegateIcon.visible
                                            text: {
                                                if (model.fontIcon && model.fontIcon !== "") return model.fontIcon;
                                                if (model.isCalc) return "󰃬";
                                                if (model.isCommand) return "󰆍";
                                                return "󰵆";
                                            }
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: launcherWindow.s(16)
                                            color: delegateRoot.isSelected ? ThemeBackend.mauve : ThemeBackend.subtext0
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter

                                            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: launcherWindow.s(1)

                                    Text {
                                        id: delegateText
                                        Layout.fillWidth: true
                                        text: model.name
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: launcherWindow.s(12)
                                        font.weight: delegateRoot.isSelected ? Font.Bold : Font.Medium
                                        color: delegateRoot.isSelected ? ThemeBackend.crust : ThemeBackend.text
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter

                                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    Text {
                                        id: delegateDesc
                                        Layout.fillWidth: true
                                        visible: model.description !== undefined && model.description !== null && model.description !== ""
                                        text: model.description || ""
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: launcherWindow.s(10)
                                        font.weight: Font.Normal
                                        color: delegateRoot.isSelected ? ThemeBackend.crust : ThemeBackend.subtext0
                                        opacity: delegateRoot.isSelected ? 0.9 : 0.85
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter

                                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    appList.currentIndex = index;
                                    activateIndex(index);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
