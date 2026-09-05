pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: config

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string niriConfigDir: homeDir + "/.config/niri"
    readonly property string lucretiaConfigDir: homeDir + "/.config/lucretia"
    
    readonly property string settingsJsonPath: {
        let envPath = Quickshell.env("QS_SETTINGS");
        if (envPath && envPath.length > 0) return envPath;
        return niriConfigDir + "/settings.json";
    }

    Timer {
        id: fallbackReadyTimer
        interval: 1000
        running: !config.dataReady
        repeat: false
        onTriggered: {
            if (!config.dataReady) {
                config.dataReady = true;
                config.settingsLoaded();
            }
        }
    }

    property bool dataReady: false
    property var rawSettings: ({})

    readonly property real uiScale: {
        let raw = rawSettings || {};
        if (raw.general && raw.general.uiScale !== undefined) return raw.general.uiScale;
        if (raw.uiScale !== undefined) return raw.uiScale;
        return 1.0;
    }

    function setUiScale(val) {
        setSetting("uiScale", val);
    }

    signal settingsLoaded()

    function sh(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    function getSetting(key, fallbackValue) {
        return (rawSettings && rawSettings.hasOwnProperty(key)) ? rawSettings[key] : fallbackValue;
    }

    function setSetting(key, value) {
        let temp = Object.assign({}, rawSettings);
        temp[key] = value;
        rawSettings = temp;

        let safeValue = typeof value === "string" ? `"${value}"` : value;
        if (typeof value === "object") safeValue = JSON.stringify(value).replace(/'/g, "'\\''");

        let syncFlatExtra = "";
        let reloadIdleCmd = "";
        if (key === "idle" && typeof value === "object" && value !== null) {
            try {
                let lockTo = (value.actions && value.actions.lock && value.actions.lock.enabled) ? Math.round((value.actions.lock.timeout || 300) / 60) : 0;
                let dpmsTo = (value.actions && value.actions.dpms && value.actions.dpms.enabled) ? Math.round((value.actions.dpms.timeout || 360) / 60) : 0;
                let sleepTo = (value.actions && value.actions.suspend && value.actions.suspend.enabled) ? Math.round((value.actions.suspend.timeout || 600) / 60) : 0;
                temp["idleLockTimeout"] = lockTo;
                temp["idleScreenOffTimeout"] = dpmsTo;
                temp["idleSleepTimeout"] = sleepTo;
                rawSettings = temp;
                syncFlatExtra = `, "idleLockTimeout": ${lockTo}, "idleScreenOffTimeout": ${dpmsTo}, "idleSleepTimeout": ${sleepTo}`;
            } catch (e) {
            }
            reloadIdleCmd = `bash "${niriConfigDir}/bin/swayidle.sh" >/dev/null 2>&1 & `;
        }

        let cmd = `mkdir -p "$(dirname '${settingsJsonPath}')" && ` +
                  `[ ! -s '${settingsJsonPath}' ] && echo '{}' > '${settingsJsonPath}'; ` +
                  `( flock 200; ` +
                  `jq '. + {"${key}": ${safeValue}${syncFlatExtra}}' '${settingsJsonPath}' > '${settingsJsonPath}.tmp' 2>/dev/null && ` +
                  `jq -e . '${settingsJsonPath}.tmp' > /dev/null 2>&1 && ` +
                  `cp '${settingsJsonPath}.tmp' '${settingsJsonPath}' && sync -d '${settingsJsonPath}' && rm -f '${settingsJsonPath}.tmp'; ` +
                  `${reloadIdleCmd}` +
                  `) 200>'${settingsJsonPath}.lock'`;
        sh(cmd);
    }

    function updateJsonBulk(dataObj) {
        let reloadIdleCmd = "";
        if (dataObj && dataObj.hasOwnProperty("idle")) {
            reloadIdleCmd = `bash "${niriConfigDir}/bin/swayidle.sh" >/dev/null 2>&1 & `;
        }
        let jsonStr = JSON.stringify(dataObj).replace(/'/g, "'\\''");
        let cmd = `mkdir -p "$(dirname '${settingsJsonPath}')" && ` +
                  `[ ! -s '${settingsJsonPath}' ] && echo '{}' > '${settingsJsonPath}'; ` +
                  `( flock 200; ` +
                  `jq '. + ${jsonStr}' '${settingsJsonPath}' > '${settingsJsonPath}.tmp' 2>/dev/null && ` +
                  `jq -e . '${settingsJsonPath}.tmp' > /dev/null 2>&1 && ` +
                  `cp '${settingsJsonPath}.tmp' '${settingsJsonPath}' && sync -d '${settingsJsonPath}' && rm -f '${settingsJsonPath}.tmp'; ` +
                  `${reloadIdleCmd}` +
                  `) 200>'${settingsJsonPath}.lock'`;
        sh(cmd);
        
        let temp = Object.assign({}, rawSettings);
        for (let key in dataObj) {
            temp[key] = dataObj[key];
        }
        rawSettings = temp;
    }

    FileView {
        id: settingsWatcher
        path: config.settingsJsonPath
        watchChanges: true
        onFileChanged: reload()
        
        onLoaded: {
            try {
                let raw = typeof text === "function" ? text() : text;
                if (typeof raw === "string") {
                    let trimmed = raw.trim();
                    if (trimmed.length > 0) {
                        config.rawSettings = JSON.parse(trimmed);
                    }
                }
            } catch (e) {
            }
            config.settingsLoaded();
            config.dataReady = true;
        }
    }

    Component.onCompleted: {
        if (settingsWatcher.path) {
            settingsWatcher.reload();
        }
    }
}
