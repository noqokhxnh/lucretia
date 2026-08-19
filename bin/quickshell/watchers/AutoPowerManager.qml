import QtQuick
import Quickshell
import "../" 

Item {
    id: manager

    property string lastAppliedProfile: ""
    property int lowLoadTicks: 0
    property double _lastSwitchTime: 0

    Timer {
        id: monitorTimer
        interval: 5000
        repeat: true
        running: Config.autoPowerMode
        triggeredOnStart: true

        onTriggered: {
            let cpu = SysData.cpu;
            let temp = SysData.temp;
            let targetProfile = "";

            // Debounce: skip evaluation if CPU/temp is still changing rapidly
            // (quiet period after the last profile switch)
            let now = Date.now();
            if (now - manager._lastSwitchTime < 30000) return;

            // 1. Peak Load Condition (Transition to balanced or performance based on saver setting)
            if (cpu >= 75 || temp >= 75) {
                targetProfile = Config.autoBatterySaver ? "balanced" : "performance";
                manager.lowLoadTicks = 0;
            }
            // 2. Idle Load Condition (Sustained low load required for power-saver)
            else if (cpu <= 25 && temp <= 50) {
                manager.lowLoadTicks++;
                if (manager.lowLoadTicks >= 2) { // 10 seconds sustained
                    targetProfile = "power-saver";
                } else {
                    targetProfile = manager.lastAppliedProfile !== "" ? manager.lastAppliedProfile : "power-saver";
                }
            }
            // 3. Normal / Transition Conditions
            else {
                manager.lowLoadTicks = 0;

                if (manager.lastAppliedProfile === "performance") {
                    // Hysteresis: only drop down to balanced if it cools down enough
                    if (cpu < 45 && temp < 60) {
                        targetProfile = "balanced";
                    } else {
                        targetProfile = "performance";
                    }
                } else if (manager.lastAppliedProfile === "balanced") {
                    // From balanced: go to power-saver if cool enough
                    if (cpu < 25 && temp < 50) {
                        targetProfile = "power-saver";
                    } else {
                        targetProfile = "balanced";
                    }
                } else {
                    // Default: power-saver (tiết kiệm nhiệt)
                    targetProfile = "power-saver";
                }
            }

            // If profile changed, execute powerprofilesctl and send notification
            if (targetProfile !== "" && targetProfile !== manager.lastAppliedProfile) {
                manager._lastSwitchTime = Date.now();
                manager.lastAppliedProfile = targetProfile;
                console.log("[AutoPowerManager] CPU: " + cpu + "%, Temp: " + temp + "°C -> Switching to " + targetProfile);
                Config.powerProfile = targetProfile;
                Quickshell.execDetached(["/usr/bin/python3", "/usr/bin/powerprofilesctl", "set", targetProfile]);
                
                if (targetProfile === "balanced" || !Config.autoPowerNotify) {
                    // Automatically dismiss any active power manager notification when returning to Balanced or notifications disabled
                    Quickshell.execDetached([
                        "dbus-send", 
                        "--session", 
                        "--type=method_call", 
                        "--dest=org.freedesktop.Notifications", 
                        "/org/freedesktop/Notifications", 
                        "org.freedesktop.Notifications.CloseNotification", 
                        "uint32:99102"
                    ]);
                }
                
                if (targetProfile !== "balanced" && Config.autoPowerNotify) {
                    // Send/replace the notification for Performance or Power Saver using a unique ID (99102)
                    let label = targetProfile === "power-saver" ? "Power Saver" : "Performance";
                    Quickshell.execDetached(["notify-send", "-r", "99102", "-t", "2000", " " + label, "CPU: " + cpu + "% | Temp: " + temp + "°C"]);
                }
            }
        }
    }

    Connections {
        target: Config
        function onAutoPowerModeChanged() {
            if (!Config.autoPowerMode) {
                manager.lastAppliedProfile = "";
                manager.lowLoadTicks = 0;
            }
        }
        function onAutoPowerNotifyChanged() {
            if (!Config.autoPowerNotify) {
                Quickshell.execDetached([
                    "dbus-send", 
                    "--session", 
                    "--type=method_call", 
                    "--dest=org.freedesktop.Notifications", 
                    "/org/freedesktop/Notifications", 
                    "org.freedesktop.Notifications.CloseNotification", 
                    "uint32:99102"
                ]);
            }
        }
    }
}
