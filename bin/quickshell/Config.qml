pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: config

    Caching { id: paths }

    // =========================================================================
    // Core Paths & Environment
    // =========================================================================
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string hyprDir: homeDir + "/.config/niri"
    readonly property string qsScriptsDir: hyprDir + "/bin/quickshell"
    readonly property string cacheDir: paths.cacheDir
    
    readonly property string settingsJsonPath: hyprDir + "/settings.json"
    readonly property string weatherEnvPath: qsScriptsDir + "/calendar/.env"

    // State Tracking
    property bool dataReady: false
    property bool isConfigProtected: true
    property bool overviewOpen: false
    property var rawSettings: ({})
    property var rawEnvs: ({})

    // =========================================================================
    // Generic Utilities (Use these in ANY widget!)
    // =========================================================================

    // Execute a background bash command easily
    function sh(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    // --- JSON Operations ---
    function getSetting(key, fallbackValue) {
        return rawSettings.hasOwnProperty(key) ? rawSettings[key] : fallbackValue;
    }

    function setSetting(key, value) {
        rawSettings[key] = value;
        let safeValue = typeof value === "string" ? `"${value}"` : value;
        if (typeof value === "object") safeValue = JSON.stringify(value).replace(/'/g, "'\\''");

        let cmd = `mkdir -p "$(dirname '${settingsJsonPath}')" && ` +
                  `[ ! -f '${settingsJsonPath}' ] && echo '{}' > '${settingsJsonPath}'; ` +
                  `jq '. + {"${key}": ${safeValue}}' '${settingsJsonPath}' > '${settingsJsonPath}.tmp' && ` +
                  `mv '${settingsJsonPath}.tmp' '${settingsJsonPath}'`;
        sh(cmd);
    }

    function updateJsonBulk(dataObj) {
        let jsonStr = JSON.stringify(dataObj).replace(/'/g, "'\\''");
        let cmd = `mkdir -p "$(dirname '${settingsJsonPath}')" && ` +
                  `[ ! -f '${settingsJsonPath}' ] && echo '{}' > '${settingsJsonPath}'; ` +
                  `jq '. + ${jsonStr}' '${settingsJsonPath}' > '${settingsJsonPath}.tmp' && ` +
                  `mv '${settingsJsonPath}.tmp' '${settingsJsonPath}'`;
        sh(cmd);
        
        for (let key in dataObj) rawSettings[key] = dataObj[key];
    }

    // --- Env Operations ---
    function getEnv(key, fallbackValue) {
        return rawEnvs.hasOwnProperty(key) ? rawEnvs[key] : fallbackValue;
    }

    function updateEnvBulk(filePath, envDict) {
        let cmds = [`mkdir -p "$(dirname '${filePath}')"`, `touch '${filePath}'`];
        for (let key in envDict) {
            rawEnvs[key] = envDict[key];
            let safeVal = envDict[key].toString().replace(/'/g, "'\\''");
            cmds.push(`if grep -q "^${key}=" '${filePath}'; then ` +
                      `sed -i "s|^${key}=.*|${key}='${safeVal}'|" '${filePath}'; ` +
                      `else echo "${key}='${safeVal}'" >> '${filePath}'; fi`);
        }
        sh(cmds.join(" && "));
    }

    // =========================================================================
    // Legacy Specific Properties (Bound to Settings.qml)
    // =========================================================================
    property real uiScale: 1.0
    property bool openGuideAtStartup: false
    property bool topbarHelpIcon: true
    property int workspaceCount: 8
    property int initialWorkspaceCount: 8
    property string wallpaperDir: Quickshell.env("WALLPAPER_DIR") || (homeDir + "/Pictures/Wallpapers")
    property string language: ""
    property string kbOptions: "grp:alt_shift_toggle"

    property string weatherUnit: "metric"
    property string weatherApiKey: ""
    property string weatherCityId: ""

    property var keybindsData: []
    signal keybindsLoaded()

    property var startupData: []
    signal startupLoaded()

    // =========================================================================
    // Control Center & System UI Settings
    // =========================================================================
    property real animSpeedMultiplier: 1.0
    property string themeMode: "auto" // auto, light, dark
    property bool autoPowerMode: false
    property bool autoPowerNotify: true
    property bool autoBatterySaver: true
    property bool beautifyScreenshot: true
    property bool dndMode: false
    property string powerProfile: "balanced"
    property int idleLockTimeout: 10
    property int idleScreenOffTimeout: 5
    property int idleSleepTimeout: 60
    property var enabledModules: ({
        "music": true,
        "battery": true,
        "wifi": true,
        "bluetooth": true,
        "volume": true,
        "tray": true,
        "system": true,
        "updater": true,
        "dnd": true,
        "notes": true,
        "focustime": true
    })

    function toggleDnd() {
        config.dndMode = !config.dndMode;
        if (config.dndMode) {
            sh("dunstctl set-paused true 2>/dev/null; makoctl set-mode do-not-disturb 2>/dev/null; swaync-client -dn 2>/dev/null");
        } else {
            sh("dunstctl set-paused false 2>/dev/null; makoctl set-mode default 2>/dev/null; swaync-client -df 2>/dev/null");
        }
        saveAppSettings();
    }

    function setPowerProfile(profile) {
        config.powerProfile = profile;
        sh("/usr/bin/python3 /usr/bin/powerprofilesctl set " + profile + " 2>/dev/null || true");
        saveAppSettings();
    }

    // =========================================================================
    // Settings Save Functions
    // =========================================================================
    function saveAppSettings() {
        let configObj = {
            "uiScale": config.uiScale,
            "openGuideAtStartup": config.openGuideAtStartup,
            "topbarHelpIcon": config.topbarHelpIcon,
            "wallpaperDir": config.wallpaperDir,
            "language": config.language,
            "kbOptions": config.kbOptions,
            "workspaceCount": config.workspaceCount,
            "animSpeedMultiplier": config.animSpeedMultiplier,
            "themeMode": config.themeMode,
            "enabledModules": config.enabledModules,
            "autoPowerMode": config.autoPowerMode,
            "autoBatterySaver": config.autoBatterySaver,
            "beautifyScreenshot": config.beautifyScreenshot,
            "autoPowerNotify": config.autoPowerNotify,
            "dndMode": config.dndMode,
            "powerProfile": config.powerProfile,
            "idleLockTimeout": config.idleLockTimeout,
            "idleScreenOffTimeout": config.idleScreenOffTimeout,
            "idleSleepTimeout": config.idleSleepTimeout
        };

        config.updateJsonBulk(configObj);
        sh("notify-send 'Quickshell' 'Settings Applied Successfully!'");
        // Idle timeouts are now set statically in bin/swayidle.sh

        if (config.workspaceCount !== config.initialWorkspaceCount) {
            sh(`qs -p "${qsScriptsDir}/TopBar.qml" ipc call topbar queueReload`);
            config.initialWorkspaceCount = config.workspaceCount;
        }
    }

    function applyControlCenterSettings() {
        saveAppSettings();
        sh("niri msg action reload-config");
    }

    function saveWeatherConfig() {
        let envs = {
            "OPENWEATHER_KEY": config.weatherApiKey,
            "OPENWEATHER_CITY_ID": config.weatherCityId,
            "OPENWEATHER_UNIT": config.weatherUnit
        };
        
        config.updateEnvBulk(config.weatherEnvPath, envs);
        sh(`rm -rf "${paths.getCacheDir('weather')}"`);
        sh("notify-send 'Weather' 'API configuration saved successfully!'");
    }

    function saveAllKeybinds(bindsArray) {
        config.keybindsData = bindsArray;
        config.setSetting("keybinds", bindsArray);
        sh("notify-send 'Quickshell' 'Keybinds Saved Successfully!'");
    }

    function saveAllStartup(startupArray) {
        config.startupData = startupArray;
        config.setSetting("startup", startupArray);
        sh("notify-send 'Quickshell' 'Startup entries saved!'");
    }

    // =========================================================================
    // Monitor Management
    // =========================================================================
    property alias monitorsModel: _monitorsModel
    ListModel { id: _monitorsModel }
    property int monActiveEditIndex: 0
    property real monUiScale: 0.10
    property int monOriginalOriginX: 0
    property int monOriginalOriginY: 0

    function monIsOverlapping(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function monIsOverlappingAny(x, y, w, h, skipIdx) {
        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === skipIdx) continue;
            let m = monitorsModel.get(i);
            let isP = m.transform === 1 || m.transform === 3;
            let mW = ((isP ? m.resH : m.resW) / m.sysScale) * config.monUiScale;
            let mH = ((isP ? m.resW : m.resH) / m.sysScale) * config.monUiScale;
            if (config.monIsOverlapping(x, y, w, h, m.uiX, m.uiY, mW, mH)) return true;
        }
        return false;
    }

    function monGetPerimeterSnap(pX, pY, sX, sY, sW, sH, mW, mH, snapT) {
        let edges = [
            { x1: sX - mW, x2: sX + sW, y1: sY - mH, y2: sY - mH },
            { x1: sX - mW, x2: sX + sW, y1: sY + sH, y2: sY + sH },
            { x1: sX - mW, x2: sX - mW, y1: sY - mH, y2: sY + sH },
            { x1: sX + sW, x2: sX + sW, y1: sY - mH, y2: sY + sH }
        ];
        let bestX = pX, bestY = pY, minDist = 999999;
        for (let i = 0; i < 4; i++) {
            let e = edges[i];
            let cx = Math.max(e.x1, Math.min(pX, e.x2));
            let cy = Math.max(e.y1, Math.min(pY, e.y2));
            if (Math.abs(cx - sX) < snapT) cx = sX;
            if (Math.abs(cx - (sX + sW - mW)) < snapT) cx = sX + sW - mW;
            if (Math.abs(cx - (sX + sW/2 - mW/2)) < snapT) cx = sX + sW/2 - mW/2;
            if (Math.abs(cy - sY) < snapT) cy = sY;
            if (Math.abs(cy - (sY + sH - mH)) < snapT) cy = sY + sH - mH;
            if (Math.abs(cy - (sY + sH/2 - mH/2)) < snapT) cy = sY + sH/2 - mH/2;
            let dist = Math.hypot(pX - cx, pY - cy);
            if (dist < minDist) { minDist = dist; bestX = cx; bestY = cy; }
        }
        return { x: bestX, y: bestY };
    }

    function monForceLayoutUpdate() {
        if (monitorsModel.count < 2) return;
        let mIdx = config.monActiveEditIndex;
        let mModel = monitorsModel.get(mIdx);
        let isP = mModel.transform === 1 || mModel.transform === 3;
        let mW = ((isP ? mModel.resH : mModel.resW) / mModel.sysScale) * config.monUiScale;
        let mH = ((isP ? mModel.resW : mModel.resH) / mModel.sysScale) * config.monUiScale;
        let bestX = mModel.uiX, bestY = mModel.uiY, bestDist = 999999;
        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === mIdx) continue;
            let sModel = monitorsModel.get(i);
            let sIsP = sModel.transform === 1 || sModel.transform === 3;
            let sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * config.monUiScale;
            let sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * config.monUiScale;
            let snapped = config.monGetPerimeterSnap(mModel.uiX, mModel.uiY, sModel.uiX, sModel.uiY, sW, sH, mW, mH, 20);
            let dist = Math.hypot(snapped.x - mModel.uiX, snapped.y - mModel.uiY);
            if (dist < bestDist) { bestDist = dist; bestX = snapped.x; bestY = snapped.y; }
        }
        monitorsModel.setProperty(mIdx, "uiX", bestX);
        monitorsModel.setProperty(mIdx, "uiY", bestY);
    }

    function applyMonitors() {
        if (monitorsModel.count === 0) return;
        let rects = [];
        for (let i = 0; i < monitorsModel.count; i++) {
            let m = monitorsModel.get(i);
            let isP = m.transform === 1 || m.transform === 3;
            let physW = Math.round((isP ? m.resH : m.resW) / m.sysScale);
            let physH = Math.round((isP ? m.resW : m.resH) / m.sysScale);
            rects.push({ x: m.uiX / config.monUiScale, y: m.uiY / config.monUiScale, w: physW, h: physH, resW: m.resW, resH: m.resH, name: m.name, rate: m.rate, sysScale: m.sysScale, transform: m.transform });
        }
        function getTightSnap(pX, pY, sX, sY, sW, sH, mW, mH, t) {
            let cx = pX; let cy = pY;
            if (Math.abs(cx - (sX - mW)) < t) cx = sX - mW;
            else if (Math.abs(cx - (sX + sW)) < t) cx = sX + sW;
            else if (Math.abs(cx - sX) < t) cx = sX;
            else if (Math.abs(cx - (sX + sW - mW)) < t) cx = sX + sW - mW;
            if (Math.abs(cy - (sY - mH)) < t) cy = sY - mH;
            else if (Math.abs(cy - (sY + sH)) < t) cy = sY + sH;
            else if (Math.abs(cy - sY) < t) cy = sY;
            else if (Math.abs(cy - (sY + sH - mH)) < t) cy = sY + sH - mH;
            return {x: cx, y: cy};
        }
        for (let i = 1; i < rects.length; i++) {
            let bestX = rects[i].x, bestY = rects[i].y, bestDist = 999999;
            for (let j = 0; j < i; j++) {
                let r0 = rects[j];
                let snapped = getTightSnap(rects[i].x, rects[i].y, r0.x, r0.y, r0.w, r0.h, rects[i].w, rects[i].h, 25);
                let dist = Math.hypot(rects[i].x - snapped.x, rects[i].y - snapped.y);
                if (dist < bestDist) { bestDist = dist; bestX = Math.round(snapped.x); bestY = Math.round(snapped.y); }
            }
            rects[i].x = bestX; rects[i].y = bestY;
        }
        let finalMinX = 999999, finalMinY = 999999;
        for (let i = 0; i < rects.length; i++) {
            if (rects[i].x < finalMinX) finalMinX = rects[i].x;
            if (rects[i].y < finalMinY) finalMinY = rects[i].y;
        }
        let wlrCmds = [], summaryString = "", jsonArr = [];
        for (let i = 0; i < rects.length; i++) {
            let r = rects[i];
            r.x = Math.round(r.x - finalMinX);
            r.y = Math.round(r.y - finalMinY);
            let cmd = "wlr-randr --output " + r.name + " --mode " + r.resW + "x" + r.resH + "@" + r.rate + " --pos " + r.x + "," + r.y + " --scale " + r.sysScale;
            if (r.transform !== 0) {
                let transformStr = "normal";
                if (r.transform === 1) transformStr = "90";
                else if (r.transform === 2) transformStr = "180";
                else if (r.transform === 3) transformStr = "270";
                cmd += " --transform " + transformStr;
            }
            wlrCmds.push(cmd);
            summaryString += r.name + " ";
            jsonArr.push({ name: r.name, resW: r.resW, resH: r.resH, rate: parseInt(r.rate), x: r.x, y: r.y, scale: r.sysScale, transform: r.transform });
        }
        config.setSetting("monitors", jsonArr);
        config.sh(wlrCmds.join(" && ") + " ; awww kill ; sleep 0.2 ; awww-daemon &");
        Quickshell.execDetached(["notify-send", "Display Update", "Applied layout for: " + summaryString.trim()]);
    }

    property alias monDelayedLayoutUpdate: _monDelayedLayoutUpdate
    Timer {
        id: _monDelayedLayoutUpdate
        interval: 10; running: false; repeat: false
        onTriggered: config.monForceLayoutUpdate()
    }

    property alias displayPoller: _displayPoller
    Process {
        id: _displayPoller
        command: ["niri", "msg", "-j", "outputs"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let rawData = JSON.parse(this.text.trim());
                    config.monitorsModel.clear();
                    
                    let data = [];
                    if (Array.isArray(rawData)) {
                        data = rawData;
                    } else if (typeof rawData === "object" && rawData !== null) {
                        for (let name in rawData) {
                            let obj = rawData[name];
                            obj.name = name;
                            data.push(obj);
                        }
                    }

                    let minX = 999999, minY = 999999;
                    for (let i = 0; i < data.length; i++) {
                        let x = data[i].logical ? data[i].logical.x : 0;
                        let y = data[i].logical ? data[i].logical.y : 0;
                        if (x < minX) minX = x;
                        if (y < minY) minY = y;
                    }
                    config.monOriginalOriginX = minX !== 999999 ? minX : 0;
                    config.monOriginalOriginY = minY !== 999999 ? minY : 0;
                    for (let i = 0; i < data.length; i++) {
                        let m = data[i];
                        let name = m.name || "";
                        let logical = m.logical || {};
                        let current_mode = m.current_mode || {};
                        let modes = m.modes || [];
                        
                        let x = logical.x !== undefined ? logical.x : 0;
                        let y = logical.y !== undefined ? logical.y : 0;
                        let scl = logical.scale !== undefined ? logical.scale : 1.0;
                        
                        let resW = current_mode.width !== undefined ? current_mode.width : (m.width || 1920);
                        let resH = current_mode.height !== undefined ? current_mode.height : (m.height || 1080);
                        let rate = current_mode.refresh !== undefined ? Math.round(current_mode.refresh).toString() : "60";
                        
                        let tf = m.transform !== undefined ? m.transform : 0;
                        if (typeof tf === "string") {
                            if (tf === "90") tf = 1;
                            else if (tf === "180") tf = 2;
                            else if (tf === "270") tf = 3;
                            else tf = 0;
                        }
                        
                        let normalizedX = (x - minX) * config.monUiScale;
                        let normalizedY = (y - minY) * config.monUiScale;
                        
                        let availableModesList = [];
                        for (let j = 0; j < modes.length; j++) {
                            let modeStr = modes[j].width + "x" + modes[j].height + "@" + Math.round(modes[j].refresh);
                            availableModesList.push(modeStr);
                        }

                        config.monitorsModel.append({
                            name: name, resW: resW, resH: resH,
                            sysScale: scl, rate: rate,
                            uiX: normalizedX, uiY: normalizedY, transform: tf,
                            availableModes: JSON.stringify(availableModesList)
                        });
                        if (m.is_focused || m.focused) config.monActiveEditIndex = i;
                    }
                    config.monForceLayoutUpdate();
                } catch(e) {}
            }
        }
    }

    // =========================================================================
    // Boot Initialization (Runs once on start)
    // =========================================================================
    Component.onCompleted: {
        settingsReader.running = true;
        envReader.running = true;
    }

    Process {
        id: envReader
        command: ["bash", "-c", `cat "${config.weatherEnvPath}" 2>/dev/null || echo ''`]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text ? this.text.trim().split('\n') : [];
                for (let line of lines) {
                    line = line.trim();
                    let parts = line.split("=");
                    if (parts.length >= 2) {
                        let key = parts[0].trim();
                        let val = parts.slice(1).join("=").replace(/^['"]|['"]$/g, '').trim();
                        config.rawEnvs[key] = val;
                        
                        if (key === "OPENWEATHER_KEY") config.weatherApiKey = val;
                        else if (key === "OPENWEATHER_CITY_ID") config.weatherCityId = val;
                        else if (key === "OPENWEATHER_UNIT") config.weatherUnit = val;
                    }
                }
            }
        }
    }

    Process {
        id: settingsReader
        command: ["bash", "-c", `cat "${config.settingsJsonPath}" 2>/dev/null || echo '{}'`]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                        config.rawSettings = JSON.parse(this.text);
                        
                        // Map explicitly defined properties
                        if (config.rawSettings.uiScale !== undefined) config.uiScale = config.rawSettings.uiScale;
                        if (config.rawSettings.openGuideAtStartup !== undefined) config.openGuideAtStartup = config.rawSettings.openGuideAtStartup;
                        if (config.rawSettings.topbarHelpIcon !== undefined) config.topbarHelpIcon = config.rawSettings.topbarHelpIcon;
                        if (config.rawSettings.wallpaperDir !== undefined) config.wallpaperDir = config.rawSettings.wallpaperDir;
                        if (config.rawSettings.language !== undefined && config.rawSettings.language !== "") config.language = config.rawSettings.language;
                        if (config.rawSettings.kbOptions !== undefined) config.kbOptions = config.rawSettings.kbOptions;
                        if (config.rawSettings.workspaceCount !== undefined) {
                            config.workspaceCount = config.rawSettings.workspaceCount;
                            config.initialWorkspaceCount = config.rawSettings.workspaceCount; 
                        }
                        if (config.rawSettings.animSpeedMultiplier !== undefined) config.animSpeedMultiplier = config.rawSettings.animSpeedMultiplier;
                        if (config.rawSettings.themeMode !== undefined) config.themeMode = config.rawSettings.themeMode;
                        if (config.rawSettings.enabledModules !== undefined) {
                            config.enabledModules = Object.assign({}, config.enabledModules, config.rawSettings.enabledModules);
                        }
                        if (config.rawSettings.autoPowerMode !== undefined) config.autoPowerMode = config.rawSettings.autoPowerMode;
                        if (config.rawSettings.autoBatterySaver !== undefined) config.autoBatterySaver = config.rawSettings.autoBatterySaver;
                        if (config.rawSettings.beautifyScreenshot !== undefined) config.beautifyScreenshot = config.rawSettings.beautifyScreenshot;
                        if (config.rawSettings.autoPowerNotify !== undefined) config.autoPowerNotify = config.rawSettings.autoPowerNotify;
                        if (config.rawSettings.dndMode !== undefined) {
                            config.dndMode = config.rawSettings.dndMode;
                            if (config.dndMode) {
                                sh("dunstctl set-paused true 2>/dev/null; makoctl set-mode do-not-disturb 2>/dev/null; swaync-client -dn 2>/dev/null");
                            }
                        }
                        if (config.rawSettings.powerProfile !== undefined) {
                            config.powerProfile = config.rawSettings.powerProfile;
                            sh("/usr/bin/python3 /usr/bin/powerprofilesctl set " + config.powerProfile + " 2>/dev/null || true");
                        }
                        if (config.rawSettings.idleLockTimeout !== undefined) config.idleLockTimeout = config.rawSettings.idleLockTimeout;
                        if (config.rawSettings.idleScreenOffTimeout !== undefined) config.idleScreenOffTimeout = config.rawSettings.idleScreenOffTimeout;
                        if (config.rawSettings.idleSleepTimeout !== undefined) config.idleSleepTimeout = config.rawSettings.idleSleepTimeout;
                        
                        // Map Keybinds
                        if (config.rawSettings.keybinds !== undefined && Array.isArray(config.rawSettings.keybinds)) {
                            let tempBinds = [];
                            for (let k of config.rawSettings.keybinds) {
                                tempBinds.push({
                                    type: k.type || "bind",
                                    mods: k.mods || "",
                                    key: k.key || "",
                                    dispatcher: k.dispatcher || "exec",
                                    command: k.command || "",
                                    isEditing: false
                                });
                            }
                            config.keybindsData = tempBinds;
                        } else {
                            config.keybindsData = [];
                        }

                        // Map Startups
                        if (config.rawSettings.startup !== undefined && Array.isArray(config.rawSettings.startup)) {
                            let tempStartup = [];
                            for (let s of config.rawSettings.startup) {
                                tempStartup.push({ command: s.command || "" });
                            }
                            config.startupData = tempStartup;
                        } else {
                            config.startupData = [];
                        }
                    } else {
                        config.saveAppSettings();
                        config.keybindsData = [];
                        config.saveAllKeybinds([]);
                        config.startupData = [];
                    }
                } catch (e) {
                    console.log("Error parsing global settings:", e);
                    config.keybindsData = [];
                    config.startupData = [];
                }
                config.keybindsLoaded();
                config.startupLoaded();
                config.dataReady = true;
            }
        }
    }

    Process {
        id: settingsWatcher
        command: ["bash", "-c", "while [ ! -f '" + config.settingsJsonPath + "' ]; do sleep 1; done; exec inotifywait -qq -e modify,close_write '" + config.settingsJsonPath + "'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                settingsReader.running = false;
                settingsReader.running = true;
                settingsWatcher.running = false;
                settingsWatcher.running = true;
            }
        }
    }
}

