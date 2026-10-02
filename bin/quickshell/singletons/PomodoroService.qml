pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    property bool isRunning: false
    property int phase: 0 // 0: Focus, 1: Short Break, 2: Long Break
    property real targetEpoch: 0
    property int remainingMs: 25 * 60 * 1000
    property int totalMs: 25 * 60 * 1000

    property int workLimitMinutes: 25
    property int shortBreakMinutes: 5
    property int longBreakMinutes: 15
    property int targetSessions: 4
    property int completedSessions: 0

    property string activeTab: "stats" // "stats" | "pomodoro"

    readonly property real progress: totalMs > 0 ? Math.max(0, Math.min(1.0, 1.0 - (remainingMs / totalMs))) : 0
    readonly property string formattedTime: formatTime(remainingMs)

    readonly property string stateFilePath: (Quickshell.env("HOME") || "/home/khxnh") + "/.local/share/quickshell/pomodoro_state.json"

    Timer {
        id: ticker
        interval: 200
        running: root.isRunning
        repeat: true
        onTriggered: root.updateTick()
    }

    Component.onCompleted: {
        root.loadState();
    }

    function formatTime(ms) {
        let totalSec = Math.max(0, Math.ceil(ms / 1000));
        let m = Math.floor(totalSec / 60);
        let s = totalSec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function resetPhaseTime() {
        if (root.phase === 0) {
            root.totalMs = root.workLimitMinutes * 60 * 1000;
        } else if (root.phase === 1) {
            root.totalMs = root.shortBreakMinutes * 60 * 1000;
        } else {
            root.totalMs = root.longBreakMinutes * 60 * 1000;
        }
        root.remainingMs = root.totalMs;
    }

    function start() {
        if (root.remainingMs <= 0) {
            root.resetPhaseTime();
        }
        root.targetEpoch = Date.now() + root.remainingMs;
        root.isRunning = true;
        root.updateTimerState();
        root.saveState();
    }

    function pause() {
        if (root.isRunning) {
            let now = Date.now();
            root.remainingMs = Math.max(0, root.targetEpoch - now);
        }
        root.targetEpoch = 0;
        root.isRunning = false;
        root.updateTimerState();
        root.saveState();
    }

    function toggle() {
        if (root.isRunning) {
            root.pause();
        } else {
            root.start();
        }
    }

    function reset() {
        root.pause();
        root.resetPhaseTime();
        root.updateTimerState();
        root.saveState();
    }

    function skip() {
        root.pause();
        root.advancePhase(true);
        root.updateTimerState();
        root.saveState();
    }

    function setPhase(newPhase) {
        root.pause();
        root.phase = newPhase;
        root.resetPhaseTime();
        root.updateTimerState();
        root.saveState();
    }

    function setWorkMinutes(m) {
        root.workLimitMinutes = m;
        if (root.phase === 0 && !root.isRunning) {
            root.resetPhaseTime();
        }
        root.saveState();
    }

    function setBreakMinutes(m) {
        root.shortBreakMinutes = m;
        if (root.phase === 1 && !root.isRunning) {
            root.resetPhaseTime();
        }
        root.saveState();
    }

    function setLongBreakMinutes(m) {
        root.longBreakMinutes = m;
        if (root.phase === 2 && !root.isRunning) {
            root.resetPhaseTime();
        }
        root.saveState();
    }

    function advancePhase(skipped) {
        if (root.phase === 0) {
            if (!skipped) {
                root.completedSessions++;
            }
            if (root.completedSessions > 0 && root.completedSessions % root.targetSessions === 0) {
                root.phase = 2; // Long Break
            } else {
                root.phase = 1; // Short Break
            }
        } else {
            root.phase = 0; // Back to Focus
        }
        root.resetPhaseTime();
    }

    function updateTick() {
        let now = Date.now();
        if (now >= root.targetEpoch) {
            root.handleComplete();
        } else {
            root.remainingMs = Math.max(0, root.targetEpoch - now);
            root.updateTimerState();
        }
    }

    function handleComplete() {
        root.isRunning = false;
        root.targetEpoch = 0;
        root.remainingMs = 0;

        let wasFocus = (root.phase === 0);
        if (wasFocus) {
            Quickshell.execDetached(["notify-send", "-a", "Lucretia Pomodoro", "-i", "preferences-system-time", "Focus Complete!", "Great job! Time to take a well-deserved break."]);
            Quickshell.execDetached(["bash", "-c", "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || canberra-gtk-play -i complete 2>/dev/null"]);
        } else {
            Quickshell.execDetached(["notify-send", "-a", "Lucretia Pomodoro", "-i", "preferences-system-time", "Break Over!", "Break time is up. Ready to focus again?"]);
            Quickshell.execDetached(["bash", "-c", "paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || canberra-gtk-play -i alarm-clock-elapsed 2>/dev/null"]);
        }

        root.advancePhase(false);
        root.updateTimerState();
        root.saveState();
    }

    function updateTimerState() {
        if (typeof TimerState !== "undefined") {
            TimerState.isActive = root.isRunning;
            TimerState.timeFormatted = root.formattedTime;
            TimerState.icon = root.phase === 0 ? "󱎫" : "󰒲";
            TimerState.colorType = root.phase === 0 ? "mauve" : "green";
        }
        writeTimerStateFile();
    }

    function writeTimerStateFile() {
        let xdg = Quickshell.env("XDG_RUNTIME_DIR");
        let dir = (xdg !== "" ? xdg : "/tmp") + "/qs/timer";
        let filePath = dir + "/state";
        if (root.isRunning) {
            let payload = JSON.stringify({
                mode: "pomodoro",
                phase: root.phase,
                remaining: root.remainingMs,
                total: root.totalMs,
                running: true
            });
            let escaped = payload.replace(/'/g, "'\\''");
            Quickshell.execDetached(["bash", "-c", "mkdir -p '" + dir + "' && printf '%s' '" + escaped + "' > '" + filePath + "'"]);
        } else {
            Quickshell.execDetached(["bash", "-c", "rm -f '" + filePath + "'"]);
        }
    }

    function saveState() {
        let payload = {
            phase: root.phase,
            workLimitMinutes: root.workLimitMinutes,
            shortBreakMinutes: root.shortBreakMinutes,
            longBreakMinutes: root.longBreakMinutes,
            completedSessions: root.completedSessions,
            targetSessions: root.targetSessions,
            targetEpoch: root.targetEpoch,
            remainingMs: root.remainingMs,
            totalMs: root.totalMs,
            isRunning: root.isRunning
        };
        let str = JSON.stringify(payload);
        let escaped = str.replace(/'/g, "'\\''");
        Quickshell.execDetached(["bash", "-c", "mkdir -p $(dirname '" + root.stateFilePath + "') && printf '%s' '" + escaped + "' > '" + root.stateFilePath + "'"]);
    }

    function loadState() {
        let proc = loadProcessComponent.createObject(root);
        proc.running = true;
    }

    Component {
        id: loadProcessComponent
        Process {
            id: p
            command: ["bash", "-c", "cat '" + root.stateFilePath + "' 2>/dev/null || echo ''"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let txt = this.text.trim();
                    if (txt) {
                        try {
                            let data = JSON.parse(txt);
                            if (data.workLimitMinutes) root.workLimitMinutes = data.workLimitMinutes;
                            if (data.shortBreakMinutes) root.shortBreakMinutes = data.shortBreakMinutes;
                            if (data.longBreakMinutes) root.longBreakMinutes = data.longBreakMinutes;
                            if (data.completedSessions !== undefined) root.completedSessions = data.completedSessions;
                            if (data.targetSessions) root.targetSessions = data.targetSessions;
                            if (data.phase !== undefined) root.phase = data.phase;
                            if (data.totalMs) root.totalMs = data.totalMs;

                            let now = Date.now();
                            if (data.targetEpoch && data.targetEpoch > 0) {
                                if (now >= data.targetEpoch) {
                                    root.handleComplete();
                                } else {
                                    root.targetEpoch = data.targetEpoch;
                                    root.remainingMs = Math.max(0, data.targetEpoch - now);
                                    root.isRunning = true;
                                    root.updateTimerState();
                                }
                            } else if (data.remainingMs !== undefined) {
                                root.remainingMs = data.remainingMs;
                                root.isRunning = false;
                            } else {
                                root.resetPhaseTime();
                            }
                        } catch(e) {
                            root.resetPhaseTime();
                        }
                    } else {
                        root.resetPhaseTime();
                    }
                    p.destroy();
                }
            }
        }
    }
}
