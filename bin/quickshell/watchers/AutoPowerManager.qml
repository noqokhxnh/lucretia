import QtQuick
import Quickshell
import "../" 

Item {
    id: manager

    property string lastAppliedProfile: ""
    property int lowLoadTicks: 0

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

            // 1. Peak Load Condition (Instant transition to performance)
            if (cpu >= 80 || temp >= 75) {
                targetProfile = "performance";
                manager.lowLoadTicks = 0; 
            }
            // 2. Idle Load Condition (Sustained low load required for power-saver)
            else if (cpu <= 15 && temp <= 55) {
                manager.lowLoadTicks++;
                if (manager.lowLoadTicks >= 3) { // 15 seconds sustained
                    targetProfile = "power-saver";
                } else {
                    targetProfile = manager.lastAppliedProfile !== "" ? manager.lastAppliedProfile : "balanced";
                }
            }
            // 3. Normal / Transition Conditions
            else {
                manager.lowLoadTicks = 0; 
                
                if (manager.lastAppliedProfile === "performance") {
                    // Hysteresis: only drop down to balanced if it cools down enough
                    if (cpu < 65 && temp < 68) {
                        targetProfile = "balanced";
                    } else {
                        targetProfile = "performance"; 
                    }
                } else if (manager.lastAppliedProfile === "power-saver") {
                    // Wake up: instantly go to balanced if CPU/temp rise slightly
                    if (cpu > 30 || temp > 60) {
                        targetProfile = "balanced";
                    } else {
                        targetProfile = "power-saver"; 
                    }
                } else {
                    targetProfile = "balanced";
                }
            }

            // If profile changed, execute powerprofilesctl and send notification
            if (targetProfile !== "" && targetProfile !== manager.lastAppliedProfile) {
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
                    Quickshell.execDetached(["notify-send", "-r", "99102", " " + label, "CPU: " + cpu + "% | Temp: " + temp + "°C"]);
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
