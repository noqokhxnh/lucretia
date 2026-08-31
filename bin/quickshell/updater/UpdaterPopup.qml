import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    // WAYLAND ANTI-DEADLOCK: Guarantee the initial frame is never 0x0.
    implicitWidth: window.s(650)
    implicitHeight: window.s(550)

    property bool _init: false
    property string updaterBin: Quickshell.env("HOME") + "/.config/niri/bin/quickshell/updater/updater_backend"

    function s(val) { 
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val; 
    }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette + Added Blob Colors)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle || _theme.base
    readonly property color crust: _theme.crust
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color green: _theme.green
    
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color blue: _theme.blue || "#89b4fa"

    // -------------------------------------------------------------------------
    // STATE & POLLING
    // -------------------------------------------------------------------------
    property string localVersion: "..."
    property string remoteVersion: "..."
    
    property var pendingCommits: []
    property int typeIndex: 0
    readonly property bool isLoading: localVerProcess.running || remoteVerProcess.running || commitFetchProcess.running

    ListModel { id: commitModel }

    function refreshData() {
        if (window.isLoading) return;
        window.remoteVersion = "...";
        commitModel.clear();
        localVerProcess.running = true;
        remoteVerProcess.running = true;
        commitFetchProcess.running = true;
    }

    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
        event.accepted = true;
    }

    // =========================================================================
    // ASYNC BOOT MANAGER
    // Ensures UI maps perfectly in the compositor before firing heavy scripts
    // =========================================================================
    Timer {
        id: bootSequence
        interval: 250 // Give compositor a quarter-second to map the window
        running: true
        onTriggered: {
            window._init = true;
            localVerProcess.running = true;
            remoteVerProcess.running = true;
            commitFetchProcess.running = true;
        }
    }

    // --- 0. GIT PROTECTION CHECK ---
    property bool isGitRepo: false
    Process {
        id: gitCheckProcess
        running: true
        command: ["bash", "-c", "[ -d $HOME/.config/niri/.git ] && echo 'true' || echo 'false'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim() : "false";
                window.isGitRepo = (out === "true");
            }
        }
    }

    // --- 1. LOCAL VERSION FETCH ---
    Process {
        id: localVerProcess
        running: false
        command: ["bash", "-c", "source ~/.local/state/lucretia-version 2>/dev/null && [ -n \"$LOCAL_VERSION\" ] && echo $LOCAL_VERSION || echo '0.0.0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim() : "";
                if (out !== "") window.localVersion = out;
            }
        }
    }

    // --- 2. REMOTE VERSION FETCH ---
    Process {
        id: remoteVerProcess
        running: false
        command: [window.updaterBin, "--version"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim() : "";
                if (out !== "") window.remoteVersion = out;
            }
        }
    }

    // --- 3. COMMIT LOG FETCH ---
    Process {
        id: commitFetchProcess
        running: false
        command: [window.updaterBin, "--commits"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim() : "";
                if (out !== "") {
                    let blocks = out.split("---SPLIT---");
                    let validLines = [];
                    for (let i = 0; i < blocks.length; i++) {
                        let blockTrimmed = blocks[i].trim();
                        if (blockTrimmed === "") continue;
                        let lines = blockTrimmed.split(/\r\n|\n/);
                        for (let j = 0; j < lines.length; j++) {
                            let trimmed = lines[j].trim();
                            if (trimmed.length > 0) validLines.push(trimmed);
                        }
                    }
                    commitModel.clear();
                    if (validLines.length > 0) {
                        window.pendingCommits = validLines;
                        window.typeIndex = 0;
                        commitBoxTimer.start();
                    } else {
                        commitModel.append({ "lineText": "No changelog available." });
                    }
                } else {
                    commitModel.clear();
                    commitModel.append({ "lineText": "No changelog available." });
                }
            }
        }
    }

    Timer {
        id: commitBoxTimer
        interval: 100
        repeat: true
        onTriggered: {
            if (window.typeIndex < window.pendingCommits.length) {
                commitModel.append({ "lineText": window.pendingCommits[window.typeIndex] });
                window.typeIndex++;
            } else {
                stop();
            }
        }
    }

    // =========================================================================
    // UI LAYOUT
    // =========================================================================
    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: window.s(16)
        color: window.base
        border.color: window.surface1
        border.width: 1
        clip: true

        OrbitBackground {
            color1: window.mauve
            color2: window.blue
            orbitScale: window.s(1)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(25)
            spacing: window.s(20)

            // --- ANIMATED CHOREOGRAPHED VERSIONS ---
            Item {
                id: versionContainer
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(60)

                // Header Action Bar (Refresh Button + Protection Badge)
                RowLayout {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    spacing: window.s(8)

                    // Refresh Button
                    Rectangle {
                        width: window.s(28)
                        height: window.s(24)
                        radius: height / 2
                        color: refreshMa.containsMouse ? window.surface1 : window.surface0
                        border.color: window.surface2
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(13)
                            color: window.text

                            NumberAnimation on rotation {
                                running: window.isLoading
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 1000
                            }
                        }

                        MouseArea {
                            id: refreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: window.isLoading ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: window.refreshData()
                        }
                    }

                    // Git Protection Badge
                    Rectangle {
                        visible: window.isGitRepo || Config.isConfigProtected
                        width: window.s(130)
                        height: window.s(24)
                        radius: height / 2
                        color: window.mauve
                        opacity: 0.15
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: window.s(6)
                            Text { text: window.isGitRepo ? "󰊢" : "󰒳"; font.family: "Iosevka Nerd Font"; color: window.mauve; font.pixelSize: window.s(14) }
                            Text { text: window.isGitRepo ? "GIT PROTECTED" : "CONFIG LOCKED"; font.family: "JetBrains Mono"; font.weight: Font.Black; color: window.mauve; font.pixelSize: window.s(10) }
                        }
                    }
                }

                Text { 
                    id: oldVer
                    text: window.localVersion
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(22)
                    color: window.subtext0 
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 0 
                }

                Text {
                    id: arrowText
                    text: "󰁔"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: window.s(18)
                    color: window.mauve
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: window.s(-25)
                    opacity: 0
                }
                
                Text { 
                    id: newVer
                    text: window.remoteVersion
                    font.family: "JetBrains Mono"
                    font.weight: Font.Black
                    font.pixelSize: window.s(36) 
                    color: window.green 
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: window.s(70)
                    opacity: 0
                    scale: 0.8 
                }

                MultiEffect {
                    id: newVerEffect
                    source: newVer
                    anchors.fill: newVer
                    shadowEnabled: true
                    shadowColor: window.green
                    shadowBlur: 0.0
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    opacity: newVer.opacity
                }

                SequentialAnimation {
                    id: versionAnim

                    PauseAnimation { duration: 150 }

                    ParallelAnimation {
                        NumberAnimation { target: oldVer; property: "anchors.horizontalCenterOffset"; to: window.s(-110); duration: 1000; easing.type: Easing.OutExpo }
                        NumberAnimation { target: oldVer; property: "opacity"; to: 0.6; duration: 800; easing.type: Easing.OutSine }

                        SequentialAnimation {
                            PauseAnimation { duration: 300 } 
                            ParallelAnimation {
                                NumberAnimation { target: arrowText; property: "opacity"; to: 0.8; duration: 600; easing.type: Easing.OutSine }
                                NumberAnimation { target: newVer; property: "opacity"; to: 1; duration: 800; easing.type: Easing.OutSine }
                                NumberAnimation { target: newVer; property: "anchors.horizontalCenterOffset"; to: window.s(65); duration: 1000; easing.type: Easing.OutExpo }
                                NumberAnimation { target: newVer; property: "scale"; to: 1.0; duration: 1000; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                            }
                            ScriptAction { script: glowAnim.start() }
                        }
                    }
                }

                SequentialAnimation {
                    id: glowAnim
                    loops: Animation.Infinite
                    NumberAnimation { target: newVerEffect; property: "shadowBlur"; to: 0.8; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { target: newVerEffect; property: "shadowBlur"; to: 0.2; duration: 1500; easing.type: Easing.InOutSine }
                }

                Connections {
                    target: window
                    function onRemoteVersionChanged() {
                        if (window.remoteVersion !== "..." && window.remoteVersion !== "") {
                            versionAnim.start();
                        }
                    }
                }
            }

            // --- CLEAN COMMIT LIST ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Loading / Empty indicator overlay
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: window.isLoading && commitModel.count === 0
                    spacing: window.s(10)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰑐"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(32)
                        color: window.mauve

                        NumberAnimation on rotation {
                            running: window.isLoading
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 1000
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Checking for updates..."
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(13)
                        color: window.subtext0
                    }
                }

                ListView {
                    id: changelogList
                    anchors.fill: parent
                    clip: true
                    model: commitModel
                    spacing: window.s(6)
                    visible: !(window.isLoading && commitModel.count === 0)

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
                                
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                    }

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutExpo }
                            NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 450; easing.type: Easing.OutBack }
                            NumberAnimation { property: "y"; from: y + window.s(15); duration: 450; easing.type: Easing.OutExpo }
                        }
                    }

                    delegate: Rectangle {
                        width: changelogList.width - window.s(12) 
                        height: Math.max(window.s(36), contentLayout.implicitHeight + window.s(14))
                        color: window.surface0 
                        radius: window.s(10)

                        // Subtle Matugen Tint Overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: window.mauve
                            opacity: 0.04
                        }

                        function parseCommit(txt) {
                            if (!txt) return { tag: "", color: window.subtext0, msg: "" };
                            let m = txt.match(/^(feat|fix|docs|style|refactor|perf|test|chore|build|ci)(\([^\)]+\))?:\s*(.*)/i);
                            if (m) {
                                let type = m[1].toLowerCase();
                                let scope = m[2] || "";
                                let col = window.subtext0;
                                if (type === "feat") col = window.green;
                                else if (type === "fix") col = window.mauve;
                                else if (type === "refactor" || type === "perf") col = window.blue;
                                return { tag: type.toUpperCase() + scope, color: col, msg: m[3] };
                            }
                            return { tag: "", color: window.subtext0, msg: txt };
                        }

                        property var commitData: parseCommit(model.lineText)

                        RowLayout {
                            id: contentLayout
                            anchors.fill: parent
                            anchors.margins: window.s(6)
                            anchors.leftMargin: window.s(12)
                            anchors.rightMargin: window.s(12)
                            spacing: window.s(10)

                            Rectangle {
                                visible: commitData.tag !== ""
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: tagText.implicitWidth + window.s(12)
                                implicitHeight: window.s(20)
                                radius: window.s(4)
                                color: commitData.color
                                opacity: 0.2

                                Text {
                                    id: tagText
                                    anchors.centerIn: parent
                                    text: commitData.tag
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(10)
                                    color: commitData.color
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: commitData.tag !== "" ? commitData.msg : model.lineText
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(12)
                                color: window.text
                                wrapMode: Text.WordWrap
                                lineHeight: 1.3
                            }
                        }
                    }
                }
            }

            // --- HOLD TO UPDATE BUTTON ---
            Rectangle {
                id: updateBtn
                Layout.alignment: Qt.AlignHCenter 
                Layout.preferredWidth: window.s(240) 
                Layout.preferredHeight: window.s(54)
                radius: window.s(12)
                color: window.surface0
                border.color: btnMa.containsMouse ? window.green : window.surface2
                border.width: btnMa.containsMouse ? window.s(2) : 1
                clip: true
                
                scale: btnMa.pressed ? 0.98 : (btnMa.containsMouse ? 1.01 : 1.0)
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                property real fillLevel: 0.0
                property bool triggered: false

                Canvas {
                    id: waveCanvas
                    anchors.fill: parent
                    
                    property real wavePhase: 0.0
                    NumberAnimation on wavePhase {
                        running: updateBtn.fillLevel > 0.0 && updateBtn.fillLevel < 1.0
                        loops: Animation.Infinite
                        from: 0; to: Math.PI * 2
                        duration: 1000
                    }
                    
                    onWavePhaseChanged: requestPaint()
                    Connections { target: updateBtn; function onFillLevelChanged() { waveCanvas.requestPaint() } }
                    
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (updateBtn.fillLevel <= 0.001) return;

                        var currentW = width * updateBtn.fillLevel;
                        var r = window.s(12);

                        ctx.save();
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        
                        if (updateBtn.fillLevel < 0.99) {
                            var waveAmp = window.s(8) * Math.sin(updateBtn.fillLevel * Math.PI); 
                            var cp1x = currentW + Math.sin(wavePhase) * waveAmp;
                            var cp2x = currentW + Math.cos(wavePhase + Math.PI) * waveAmp;

                            ctx.lineTo(currentW, 0);
                            ctx.bezierCurveTo(cp2x, height * 0.33, cp1x, height * 0.66, currentW, height);
                            ctx.lineTo(0, height);
                        } else {
                            ctx.lineTo(width, 0);
                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                        }
                        ctx.closePath();
                        ctx.clip(); 

                        ctx.beginPath();
                        ctx.roundedRect(0, 0, width, height, r, r);
                        var grad = ctx.createLinearGradient(0, 0, width, 0);
                        grad.addColorStop(0, Qt.darker(window.green, 1.1).toString());
                        grad.addColorStop(1, window.green.toString());
                        ctx.fillStyle = grad;
                        ctx.fill();

                        ctx.restore();
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: window.s(10)
                    
                    Text { 
                        text: "󰚰"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(18)
                        color: updateBtn.fillLevel > 0.5 ? window.crust : window.green 
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    Text { 
                        text: updateBtn.fillLevel > 0 ? "HOLDING... " + Math.floor(updateBtn.fillLevel * 100) + "%" : "UPDATE"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Black
                        font.pixelSize: window.s(14)
                        color: updateBtn.fillLevel > 0.5 ? window.crust : window.green 
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: btnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: updateBtn.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                    
                    onPressed: {
                        if (!updateBtn.triggered) {
                            drainAnim.stop();
                            fillAnim.stop();
                            fillAnim.from = updateBtn.fillLevel;
                            fillAnim.to = 1.0;
                            fillAnim.duration = Math.max(50, 1200 * (1.0 - updateBtn.fillLevel));
                            fillAnim.start();
                        }
                    }
                    
                    onReleased: {
                        if (!updateBtn.triggered && updateBtn.fillLevel < 1.0) {
                            fillAnim.stop();
                            drainAnim.stop();
                            drainAnim.from = updateBtn.fillLevel;
                            drainAnim.to = 0.0;
                            drainAnim.duration = Math.max(50, 800 * updateBtn.fillLevel);
                            drainAnim.start();
                        }
                    }

                    onCanceled: {
                        if (!updateBtn.triggered && updateBtn.fillLevel < 1.0) {
                            fillAnim.stop();
                            drainAnim.stop();
                            drainAnim.from = updateBtn.fillLevel;
                            drainAnim.to = 0.0;
                            drainAnim.duration = Math.max(50, 800 * updateBtn.fillLevel);
                            drainAnim.start();
                        }
                    }
                }

                NumberAnimation {
                    id: fillAnim
                    target: updateBtn
                    property: "fillLevel"
                    easing.type: Easing.InSine
                    onFinished: {
                        if (updateBtn.fillLevel >= 0.99 && !updateBtn.triggered) {
                            updateBtn.triggered = true;
                            updateBtn.fillLevel = 1.0;
                            let scriptPath = Quickshell.env("HOME") + "/.config/niri/bin/updater.sh";
                            let cmd = "if command -v foot >/dev/null 2>&1; then foot --hold bash -c '" + scriptPath + "'; " +
                                      "elif command -v kitty >/dev/null 2>&1; then kitty --hold bash -c '" + scriptPath + "'; " +
                                      "elif command -v ghostty >/dev/null 2>&1; then ghostty -e bash -c '" + scriptPath + "; echo; read -n 1 -s -r -p \"Press any key to close...\"'; " +
                                      "elif command -v alacritty >/dev/null 2>&1; then alacritty --hold -e bash -c '" + scriptPath + "'; " +
                                      "elif command -v wezterm >/dev/null 2>&1; then wezterm start -- bash -c '" + scriptPath + "; echo; read -n 1 -s -r -p \"Press any key to close...\"'; " +
                                      "elif command -v xterm >/dev/null 2>&1; then xterm -hold -e bash -c '" + scriptPath + "'; " +
                                      "else bash '" + scriptPath + "'; fi";
                            Quickshell.execDetached(["bash", "-c", cmd]);
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"]);
                        }
                    }
                }

                NumberAnimation {
                    id: drainAnim
                    target: updateBtn
                    property: "fillLevel"
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
