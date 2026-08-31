pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home/khxnh"
    readonly property string qsDir: Quickshell.env("QS_DIR") ? Quickshell.env("QS_DIR") : (home + "/.config/niri/bin/quickshell")
    readonly property string lucretiaDir: Quickshell.env("LUCRETIA_DIR") ? Quickshell.env("LUCRETIA_DIR") : (Quickshell.env("SERPANTINUM_DIR") ? Quickshell.env("SERPANTINUM_DIR") : qsDir)
    readonly property string serpantinumDir: lucretiaDir
    readonly property string mainQml: Quickshell.env("MAIN_QML") ? Quickshell.env("MAIN_QML") : (qsDir + "/Shell.qml")
    readonly property string assetsDir: qsDir + "/assets"

    readonly property string xdgRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR")

    readonly property string cacheDir: Quickshell.env("QS_CACHE_DIR") ? Quickshell.env("QS_CACHE_DIR") : (home + "/.cache/lucretia")
    readonly property string stateDir: Quickshell.env("QS_STATE_DIR") ? Quickshell.env("QS_STATE_DIR") : (home + "/.local/state/lucretia")
    readonly property string runDir: Quickshell.env("QS_RUN_DIR") ? Quickshell.env("QS_RUN_DIR") : ((xdgRuntimeDir !== "" ? xdgRuntimeDir : "/tmp") + "/lucretia")
    readonly property string configDir: home + "/.config/niri/bin/quickshell"

    function getConfigDir(widgetName) {
        return qsDir;
    }

    function getCacheDir(widgetName) {
        if (!widgetName || widgetName === "lucretia" || widgetName === "serpantinum" || cacheDir.endsWith("/" + widgetName)) {
            Quickshell.execDetached(["mkdir", "-p", cacheDir]);
            return cacheDir;
        }
        var envPath = Quickshell.env("QS_CACHE_" + widgetName.toUpperCase());
        var finalPath = envPath ? envPath : (cacheDir + "/" + widgetName);
        Quickshell.execDetached(["mkdir", "-p", finalPath]);
        return finalPath;
    }

    function getStateDir(widgetName) {
        if (!widgetName || widgetName === "lucretia" || widgetName === "serpantinum" || stateDir.endsWith("/" + widgetName)) {
            Quickshell.execDetached(["mkdir", "-p", stateDir]);
            return stateDir;
        }
        var envPath = Quickshell.env("QS_STATE_" + widgetName.toUpperCase());
        var finalPath = envPath ? envPath : (stateDir + "/" + widgetName);
        Quickshell.execDetached(["mkdir", "-p", finalPath]);
        return finalPath;
    }

    function getRunDir(widgetName) {
        if (!widgetName || widgetName === "lucretia" || widgetName === "serpantinum" || runDir.endsWith("/" + widgetName)) {
            Quickshell.execDetached(["mkdir", "-p", runDir]);
            return runDir;
        }
        var envPath = Quickshell.env("QS_RUN_" + widgetName.toUpperCase());
        var finalPath = envPath ? envPath : (runDir + "/" + widgetName);
        Quickshell.execDetached(["mkdir", "-p", finalPath]);
        return finalPath;
    }

    function getLogDir(widgetName) {
        if (!widgetName || widgetName === "lucretia" || widgetName === "serpantinum" || logDir.endsWith("/" + widgetName)) {
            Quickshell.execDetached(["mkdir", "-p", logDir]);
            return logDir;
        }
        var envPath = Quickshell.env("QS_LOG_" + widgetName.toUpperCase());
        var finalPath = envPath ? envPath : (logDir + "/" + widgetName);
        Quickshell.execDetached(["mkdir", "-p", finalPath]);
        return finalPath;
    }
}
