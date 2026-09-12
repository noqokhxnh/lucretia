import QtQuick
import Quickshell
import "../" 

Item {
    id: manager

    property string lastAppliedProfile: ""
    property int lowLoadTicks: 0
    property int highLoadTicks: 0
    property double _lastSwitchTime: 0
    property bool activeSubscriber: false

    function updateSubscription() {
        let shouldSubscribe = Boolean(Config.autoPowerMode);
        if (shouldSubscribe && !activeSubscriber) {
            SysData.subscribe();
            activeSubscriber = true;
        } else if (!shouldSubscribe && activeSubscriber) {
            SysData.unsubscribe();
            activeSubscriber = false;
        }
    }

    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (activeSubscriber) {
            SysData.unsubscribe();
            activeSubscriber = false;
        }
    }

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

            // 1. Peak Load Condition: Sustained high CPU load (>=80% for 10s), prevented if overheating (>=85°C)
            if (cpu >= 80 && temp < 85) {
                manager.highLoadTicks++;
                manager.lowLoadTicks = 0;
                if (manager.highLoadTicks >= 2) { // 10 seconds sustained
                    targetProfile = Config.autoBatterySaver ? "balanced" : "performance";
                } else {
                    targetProfile = manager.lastAppliedProfile !== "" ? manager.lastAppliedProfile : (Config.autoBatterySaver ? "power-saver" : "balanced");
                }
            }
            // 2. Idle Load Condition: Sustained low CPU load
            else if (cpu <= 25) {
                manager.highLoadTicks = 0;
                manager.lowLoadTicks++;
                if (Config.autoBatterySaver) {
                    if (manager.lowLoadTicks >= 2) { // 10 seconds sustained
                        targetProfile = "power-saver";
                    } else {
                        targetProfile = manager.lastAppliedProfile !== "" ? manager.lastAppliedProfile : "power-saver";
                    }
                } else {
                    // On AC: return from performance to balanced
                    targetProfile = "balanced";
                }
            }
            // 3. Normal Load Condition (Moderate CPU usage)
            else {
                manager.highLoadTicks = 0;
                manager.lowLoadTicks = 0;

                if (manager.lastAppliedProfile === "performance") {
                    // Step down to balanced when CPU drops below 55% or temperature is too high
                    if (cpu < 55 || temp >= 85) {
                        targetProfile = "balanced";
                    } else {
                        targetProfile = "performance";
                    }
                } else if (Config.autoBatterySaver) {
                    targetProfile = "power-saver";
                } else {
                    targetProfile = "balanced";
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
            manager.updateSubscription();
        }
        function onSettingsLoaded() {
            manager.updateSubscription();
            if (!Config.autoPowerMode) {
                manager.lastAppliedProfile = "";
                manager.lowLoadTicks = 0;
                manager.highLoadTicks = 0;
            }
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
