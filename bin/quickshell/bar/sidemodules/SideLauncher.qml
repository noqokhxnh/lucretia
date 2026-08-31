import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Item {
    id: sideLauncherRoot
    anchors.fill: parent
    focus: true

    property var rootWidget
    property var barWindow: rootWidget ? rootWidget.barWindow : null

    function s(val) {
        return barWindow ? barWindow.s(val) : val;
    }

    property real searchHeight: sideLauncherRoot.s(32)
    property real itemHeight: sideLauncherRoot.s(40)
    property real listSpacing: sideLauncherRoot.s(4)
    property real maxListHeight: (6 * itemHeight) + (5 * listSpacing)

    property real requiredHeight: searchHeight + sideLauncherRoot.s(18) + maxListHeight
    readonly property real maxPossibleHeight: searchHeight + sideLauncherRoot.s(18) + maxListHeight

    property var allApps: []
    property var usageRanks: ({ "focus": {}, "launch": {}, "context": {} })

    Process {
        id: rankFetcher
        running: true
        command: Caching.qsDir ? ["python3", Caching.qsDir + "/bar/sidemodules/pill/app_rank.py", "--rank"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        sideLauncherRoot.usageRanks = JSON.parse(this.text);
                        sideLauncherRoot.loadApps();
                        executeFilter(searchInput.text);
                    }
                } catch(e) {}
            }
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
        let entries = DesktopEntries.applications.values;
        let arr = [];

        for (let i = 0; i < entries.length; i++) {
            let e = entries[i];
            if (e.noDisplay) continue;

            let score = 0;
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

            arr.push({
                name: e.name,
                description: e.comment || "",
                desktop_id: e.id,
                icon: e.icon,
                fontIcon: "",
                score: score,
                isCommand: false,
                command: "",
                isCalc: false,
                calcResult: "",
                entry: e
            });
        }

        arr.sort(function(a, b) {
            if (a.score !== b.score) {
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

        sideLauncherRoot.allApps = finalArr;
    }

    ListModel {
        id: appModel
    }

    property bool isKeyboardNav: false
    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: {
            sideLauncherRoot.isKeyboardNav = false;
        }
    }

    property string pendingQuery: ""
    Timer {
        id: filterDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            executeFilter(sideLauncherRoot.pendingQuery);
        }
    }

    function filterApps(query) {
        sideLauncherRoot.pendingQuery = query;
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
        sideLauncherRoot.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let rawTrimmed = query.trim();
        let q = query.toLowerCase().trim();
        let filtered = [];

        if (rawTrimmed.startsWith(">")) {
            let cmd = rawTrimmed.substring(1).trim();
            if (cmd.length > 0) {
                filtered.push({
                    name: "> " + cmd,
                    description: "Execute command: " + cmd,
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: true,
                    command: cmd,
                    isCalc: false,
                    calcResult: "",
                    entry: null
                });
            } else {
                filtered.push({
                    name: "> ...",
                    description: "Type a command to execute",
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    calcResult: "",
                    entry: null
                });
            }
        }

        let mathResult = evaluateMath(rawTrimmed);
        if (mathResult !== null) {
            filtered.push({
                name: rawTrimmed + " = " + mathResult,
                description: "Calculation result (Enter to copy)",
                desktop_id: "",
                icon: "",
                fontIcon: "󰃬",
                score: 9000000,
                isCommand: false,
                command: "",
                isCalc: true,
                calcResult: mathResult,
                entry: null
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
                    entry: app.entry
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
                Quickshell.execDetached(["sh", "-c", item.command]);
            }
            if (rootWidget) {
                rootWidget.showLauncher = false;
            }
            return;
        }

        if (item.isCalc) {
            Quickshell.execDetached(["wl-copy", "--", item.calcResult]);
            if (rootWidget) {
                rootWidget.showLauncher = false;
            }
            return;
        }

        launchApp(item.name, item.desktop_id);
    }

    function launchApp(appName, desktopId) {
        let entry = DesktopEntries.byId(desktopId);
        if (entry) {
            entry.execute();
        }
        if (Caching.qsDir) {
            Quickshell.execDetached(["python3", Caching.qsDir + "/bar/sidemodules/pill/app_rank.py", "--log-launch", "--name", appName]);
        }
        if (rootWidget) {
            rootWidget.showLauncher = false;
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            searchInput.forceInputFocus();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 150
        running: false
        repeat: false
        onTriggered: {
            if (!searchInput.hasFocus) {
                searchInput.forceInputFocus();
            }
        }
    }

    onVisibleChanged: {
        if (visible && rootWidget && rootWidget.showLauncher) {
            focusTimer.restart();
            focusRetryTimer.restart();
        }
    }

    Connections {
        target: rootWidget
        function onShowLauncherChanged() {
            if (rootWidget && rootWidget.showLauncher) {
                searchInput.clear();
                filterDebounceTimer.stop();
                rankFetcher.running = false;
                rankFetcher.running = true;
                focusTimer.restart();
                focusRetryTimer.restart();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: sideLauncherRoot.s(8)
        spacing: sideLauncherRoot.s(6)

        Input {
            id: searchInput
            Layout.fillWidth: true
            Layout.preferredHeight: sideLauncherRoot.searchHeight

            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: sideLauncherRoot.s(11)
            charSpacing: 1

            placeholderText: typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder", "Start with > for a command...") : "Start with > for a command..."
            leadingIcon: "󰍉"
            showClearButton: true

            onTextEdited: function(newText) {
                filterApps(newText);
            }
            onCleared: filterApps("")

            Keys.onDownPressed: function(event) {
                sideLauncherRoot.isKeyboardNav = true;
                keyboardNavTimer.restart();
                if (appList.currentIndex < appModel.count - 1) {
                    appList.currentIndex++;
                }
                event.accepted = true;
            }
            Keys.onUpPressed: function(event) {
                sideLauncherRoot.isKeyboardNav = true;
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
                if (rootWidget) rootWidget.showLauncher = false;
                event.accepted = true;
            }
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appModel
            spacing: sideLauncherRoot.listSpacing
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds

            highlightFollowsCurrentItem: true
            highlightMoveDuration: 180
            highlightResizeDuration: 180

            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    positionViewAtIndex(currentIndex, ListView.Contain);
                }
            }

            highlight: Rectangle {
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.mauve
                opacity: appList.count > 0 && appList.currentIndex >= 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            delegate: Item {
                width: ListView.view.width
                height: sideLauncherRoot.itemHeight
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: ThemeBackend.surface0
                        opacity: ma.containsMouse && index !== appList.currentIndex ? 0.4 : 0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutSine } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: sideLauncherRoot.s(6)
                        anchors.leftMargin: sideLauncherRoot.s(8)
                        spacing: sideLauncherRoot.s(8)

                        Item {
                            id: delegateIconArea
                            Layout.preferredWidth: sideLauncherRoot.s(24)
                            Layout.preferredHeight: sideLauncherRoot.s(24)
                            Layout.alignment: Qt.AlignVCenter

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

                                sourceSize: Qt.size(48, 48)
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
                                font.pixelSize: sideLauncherRoot.s(16)
                                color: index === appList.currentIndex ? ThemeBackend.crust : ThemeBackend.mauve
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter

                                Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: model.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: sideLauncherRoot.s(11)
                                font.weight: Font.Bold
                                color: index === appList.currentIndex ? ThemeBackend.crust : ThemeBackend.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: model.description !== undefined && model.description !== null && model.description !== ""
                                text: model.description || ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: sideLauncherRoot.s(9)
                                font.weight: Font.Normal
                                color: index === appList.currentIndex ? ThemeBackend.crust : ThemeBackend.subtext0
                                opacity: 0.85
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
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
