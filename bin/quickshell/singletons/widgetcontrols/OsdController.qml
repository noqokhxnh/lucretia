pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../"
import "../../"

Item {
    id: controller

    property bool isVisible: false
    property string kind: "volume"
    property int briVal: 0
    property string stateVal: "off"
    property var screen: null
    property bool isHovered: false
    property bool isFullscreen: false

    readonly property real sysVolume: Audio.defaultSink && Audio.defaultSink.audio ? Audio.getVolume(Audio.defaultSink, Audio.defaultSink.audio.volume) : 0
    readonly property bool sysMuted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false

    readonly property real sysMicVolume: Audio.defaultSource && Audio.defaultSource.audio ? Audio.getVolume(Audio.defaultSource, Audio.defaultSource.audio.volume) : 0
    readonly property bool sysMicMuted: Audio.defaultSource && Audio.defaultSource.audio ? Audio.defaultSource.audio.muted : false

    readonly property bool wifiRadioEnabled: Networking.wifiEnabled
    readonly property bool btRadioEnabled: Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
    readonly property bool sysAirplane: !wifiRadioEnabled && !btRadioEnabled

    property int sysBrightness: 0

    property real lastVolume: -1
    property bool lastMuted: false
    property real lastMicVolume: -1
    property bool lastMicMuted: false
    property bool lastAirplane: false
    property int lastCapsLock: -1
    property int lastNumLock: -1
    property int lastBrightness: -1
    property bool kbInitialized: false
    property bool isInitialized: false

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (!controller.isHovered) {
                controller.isVisible = false;
            }
        }
    }

    Timer {
        id: initTimer
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            controller.lastVolume = controller.sysVolume;
            controller.lastMuted = controller.sysMuted;
            controller.lastMicVolume = controller.sysMicVolume;
            controller.lastMicMuted = controller.sysMicMuted;
            controller.lastAirplane = controller.sysAirplane;
            controller.lastBrightness = controller.sysBrightness;
            controller.isInitialized = true;
        }
    }

    onSysVolumeChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastVolume !== controller.sysVolume) {
            controller.lastVolume = controller.sysVolume;
            controller.show("volume");
        }
    }

    onSysMutedChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastMuted !== controller.sysMuted) {
            controller.lastMuted = controller.sysMuted;
            controller.show("volume");
        }
    }

    onSysMicVolumeChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastMicVolume !== controller.sysMicVolume) {
            controller.lastMicVolume = controller.sysMicVolume;
            controller.show("mic");
        }
    }

    onSysMicMutedChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastMicMuted !== controller.sysMicMuted) {
            controller.lastMicMuted = controller.sysMicMuted;
            controller.show("mic");
        }
    }

    onSysBrightnessChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastBrightness !== controller.sysBrightness) {
            controller.lastBrightness = controller.sysBrightness;
            controller.show("brightness");
        }
    }

    onSysAirplaneChanged: {
        if (!controller.isInitialized) return;
        if (controller.lastAirplane !== controller.sysAirplane) {
            controller.lastAirplane = controller.sysAirplane;
            controller.show("airplane", controller.sysAirplane ? "on" : "off");
        }
    }

    Process {
        id: kbWatcher
        running: true
        command: ["bash", Caching.lucretiaDir + "/scripts/kb_locks.sh", "watch"]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;

                let parts = line.split(/\s+/);
                if (parts.length >= 2) {
                    let k = parts[0];
                    let stateStr = parts[1];
                    let stateNum = (stateStr === "1" || stateStr === "on") ? 1 : 0;
                    if (k === "capslock") {
                        controller.lastCapsLock = stateNum;
                        controller.show("capslock", stateNum === 1 ? "on" : "off");
                    } else if (k === "numlock") {
                        controller.lastNumLock = stateNum;
                        controller.show("numlock", stateNum === 1 ? "on" : "off");
                    }
                }
            }
        }
    }

    Process {
        id: kbFetcher
        running: true
        command: ["bash", Caching.lucretiaDir + "/scripts/kb_locks.sh", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim().split(/\s+/);
                if (out.length >= 2) {
                    let caps = parseInt(out[0]);
                    let num = parseInt(out[1]);
                    if (!isNaN(caps)) controller.lastCapsLock = caps;
                    if (!isNaN(num)) controller.lastNumLock = num;
                    controller.kbInitialized = true;
                }
            }
        }
    }

    Process {
        id: briWatcher
        running: true
        command: ["sh", "-c", "inotifywait -m -e modify /sys/class/backlight/*/brightness 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                briFetchDebounce.restart();
            }
        }
    }

    Timer {
        id: briFetchDebounce
        interval: 50
        repeat: false
        onTriggered: {
            briFetcher.running = false;
            briFetcher.running = true;
        }
    }

    Process {
        id: briFetcher
        running: true
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "") {
                    let val = parseInt(out);
                    if (!isNaN(val)) {
                        controller.sysBrightness = val;
                        controller.briVal = val;
                    }
                }
            }
        }
    }

    function show(k, v, scr) {
        controller.kind = k || "volume";
        if (controller.kind === "brightness" && v !== undefined) {
            controller.briVal = parseInt(v) || 0;
        } else if (v !== undefined) {
            controller.stateVal = v.toString();
        }
        if (scr !== undefined && scr !== null) {
            controller.screen = scr;
        }
        controller.isVisible = true;
        hideTimer.restart();
    }

    function display(k, v, scr) {
        show(k, v, scr);
    }

    function hide() {
        hideTimer.stop();
        controller.isVisible = false;
    }

    function requestHide() {
        if (!controller.isHovered) {
            hideTimer.restart();
        }
    }

    function cancelHide() {
        hideTimer.stop();
    }

    function restartTimer() {
        if (controller.isVisible) {
            hideTimer.restart();
        }
    }

    function toggle(k, v, scr) {
        if (controller.isVisible && controller.kind === k) {
            hide();
        } else {
            show(k, v, scr);
        }
    }
}
