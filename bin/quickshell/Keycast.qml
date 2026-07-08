import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-keycast"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"

            // Pinned at the bottom-right corner of the screen
            anchors {
                bottom: true
                right: true
            }

            margins {
                bottom: s(75)
                right: s(75)
            }

            // --- Responsive Scaling ---
            Scaler {
                id: scaler
                currentWidth: window.screen.width
            }

            function s(val) { 
                return scaler.s(val); 
            }

            // Dynamic sizing based on row items
            implicitWidth: s(500)
            implicitHeight: layoutRow.height + s(20)

            visible: isEnabled && keysModel.count > 0

            // --- State Logic ---
            property bool isEnabled: false
            property int nextId: 0
            property int maxBubbles: 3

            Caching { id: paths }

            // State file poller
            Process {
                id: statePoller
                command: ["bash", "-c", "cat " + paths.getRunDir("keycast") + "/enabled 2>/dev/null || echo '0'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        let enabled = (txt === "1");
                        if (window.isEnabled !== enabled) {
                            window.isEnabled = enabled;
                            if (!enabled) {
                                keysModel.clear();
                            }
                        }
                    }
                }
            }

            // State file watcher
            Process {
                id: stateWatcher
                command: ["bash", "-c", "mkdir -p " + paths.getRunDir("keycast") + " && touch " + paths.getRunDir("keycast") + "/enabled && exec inotifywait -qq -e modify,close_write " + paths.getRunDir("keycast") + "/enabled"]
                running: true
                onExited: {
                    statePoller.running = false;
                    statePoller.running = true;
                    running = false;
                    running = true;
                }
            }

            // --- Compiled C++ Sniffer Process ---
            Process {
                id: keycastBackend
                command: [paths.home + "/.config/niri/bin/keycast_backend"]
                running: window.isEnabled
                
                stdout: SplitParser {
                    onRead: (data) => {
                        try {
                            let parsed = JSON.parse(data.trim());
                            if (parsed.key !== undefined) {
                                window.addKey(parsed.key, parsed.is_modifier || false);
                            }
                        } catch (e) {
                            // Suppress errors for garbage lines
                        }
                    }
                }
            }

            ListModel {
                id: keysModel
            }

            // --- Key Event Router & Grouping Logic ---
            function addKey(key, isModifier) {
                if (key === "Backspace") {
                    if (keysModel.count > 0) {
                        let lastIdx = keysModel.count - 1;
                        let lastItem = keysModel.get(lastIdx);
                        if (lastItem.isMod) {
                            // If last was a modifier combo, delete the whole bubble
                            keysModel.remove(lastIdx);
                        } else {
                            // If last was normal text, delete character-by-character
                            let txt = lastItem.keyText;
                            if (txt === "Space" || txt.length <= 1) {
                                keysModel.remove(lastIdx);
                            } else {
                                keysModel.setProperty(lastIdx, "keyText", txt.substring(0, txt.length - 1));
                            }
                        }
                    }
                } else if (key === "Space") {
                    // Grouping Space: append literal space " " if typing consecutive letters
                    if (keysModel.count > 0) {
                        let lastIdx = keysModel.count - 1;
                        let lastItem = keysModel.get(lastIdx);
                        let isLastText = !lastItem.isMod && !isSpecialKey(lastItem.keyText);
                        if (isLastText && lastItem.keyText !== "") {
                            keysModel.setProperty(lastIdx, "keyText", lastItem.keyText + " ");
                            return;
                        }
                    }
                    // Otherwise, start a standalone Space key bubble
                    appendNewBubble("Space", false);
                } else {
                    if (isModifier) {
                        // Modifier shortcuts always get their own separate bubble
                        appendNewBubble(key, true);
                    } else {
                        // Normal text key: check if we can group it with the last bubble
                        if (keysModel.count > 0) {
                            let lastIdx = keysModel.count - 1;
                            let lastItem = keysModel.get(lastIdx);
                            let lastText = lastItem.keyText;
                            
                            let isLastNormal = !lastItem.isMod && !isSpecialKey(lastText);
                            if (isLastNormal) {
                                // Append letter to the existing grouped text bubble
                                keysModel.setProperty(lastIdx, "keyText", lastText + key);
                                return;
                            }
                        }
                        
                        // Otherwise, start a new bubble
                        appendNewBubble(key, false);
                    }
                }
            }

            function appendNewBubble(key, isModifier) {
                // Limit queue to preserve screen estate
                if (keysModel.count >= maxBubbles) {
                    keysModel.remove(0);
                }
                keysModel.append({
                    "itemId": nextId++,
                    "keyText": key,
                    "isMod": isModifier
                });
            }

            // Checks if a key label represents a standalone non-typable action key
            function isSpecialKey(txt) {
                return txt === "Space" || txt === "Backspace" || txt === "Enter" || txt === "KPEnter" || 
                       txt === "Esc" || txt === "Tab" || txt === "Up" || txt === "Down" || 
                       txt === "Left" || txt === "Right" || txt === "⌫" || txt === "↩" || 
                       txt === "⎋" || txt === "⇥" || txt === "⇡" || txt === "⇣" || 
                       txt === "⇠" || txt === "⇢";
            }

            // Map special key labels to authentic macOS KeyCastr glyphs defensively
            function getDisplayKeyText(txt, isModifier) {
                if (txt === "Space") return "␣";
                if (txt === "Backspace") return "⌫";
                if (txt === "Enter" || txt === "KPEnter") return "↩";
                if (txt === "Esc") return "⎋";
                if (txt === "Tab") return "⇥";
                if (txt === "Up") return "⇡";
                if (txt === "Down") return "⇣";
                if (txt === "Left") return "⇠";
                if (txt === "Right") return "⇢";
                
                if (isModifier) {
                    // Translate key labels to macOS modifier symbols and strip '+' signs
                    let formatted = txt
                        .replace(/Super/g, "⌘")
                        .replace(/LCtrl/g, "⌃")
                        .replace(/RCtrl/g, "⌃")
                        .replace(/Ctrl/g, "⌃")
                        .replace(/LShift/g, "⇧")
                        .replace(/RShift/g, "⇧")
                        .replace(/Shift/g, "⇧")
                        .replace(/LAlt/g, "⌥")
                        .replace(/RAlt/g, "⌥")
                        .replace(/Alt/g, "⌥")
                        .replace(/\+/g, ""); // Strip plus signs
                    return formatted;
                }
                return txt;
            }

            // --- MAC OS KEYCASTR FLOATING ROW ---
            ListView {
                id: layoutRow
                orientation: ListView.Vertical
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: s(8)
                width: parent.width
                height: contentHeight
                interactive: false

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                // Springy populate & add animations
                populate: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "scale"; from: 0.75; to: 1.0; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 100 }
                    }
                }
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "scale"; from: 0.75; to: 1.0; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 100 }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "scale"; to: 0.75; duration: 90 }
                        NumberAnimation { property: "opacity"; to: 0.0; duration: 90 }
                    }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 150; easing.type: Easing.OutQuad }
                }

                model: keysModel
                delegate: Item {
                    id: delegateRoot
                    width: parent.width
                    height: s(44)

                    required property int itemId
                    required property string keyText
                    required property bool isMod

                    // Dynamic trail opacity: older keys fade out, newer keys are bright
                    opacity: {
                        let idx = index;
                        let total = layoutRow.count;
                        if (total <= 1) return 1.0;
                        // Linear fade from 0.35 (oldest) to 1.0 (newest)
                        return 0.35 + (0.65 * (idx / (total - 1)));
                    }
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    // Reset fade timer if text changes
                    onKeyTextChanged: {
                        itemFadeTimer.restart();
                    }

                    // Keycap Container
                    Rectangle {
                        id: keycap
                        anchors.right: parent.right
                        width: (keyText === "Space") ? s(55) : Math.max(s(44), keyLabel.implicitWidth + s(24))
                        height: parent.height
                        radius: s(8)
                        opacity: 1.0
                        
                        // Matte macOS dark charcoal-black keycap
                        color: Qt.rgba(0.08, 0.08, 0.08, 0.88)
                        
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)

                        // Subtle top highlight for physical keycap look
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.08)
                            radius: s(8)
                        }

                        // Authentic high-contrast macOS bezel shadow
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.45)
                            shadowBlur: 0.7
                            shadowVerticalOffset: s(3)
                            shadowHorizontalOffset: 0
                        }

                        Text {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: getDisplayKeyText(keyText, isMod)
                            
                            // Helvetica / SF Pro style clean bold typography
                            font.family: "JetBrains Mono"
                            font.pixelSize: s(16)
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }

                        // Individual bubble fade out
                        Timer {
                            id: itemFadeTimer
                            interval: 2000
                            running: true
                            repeat: false
                            onTriggered: fadeOutAnim.start()
                        }

                        NumberAnimation {
                            id: fadeOutAnim
                            target: keycap
                            property: "opacity"
                            to: 0.0
                            duration: 250
                            onFinished: {
                                for (let i = 0; i < keysModel.count; i++) {
                                    if (keysModel.get(i).itemId === itemId) {
                                        keysModel.remove(i);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
