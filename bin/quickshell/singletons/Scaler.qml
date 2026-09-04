pragma Singleton
import QtQuick
import QtQuick.Window
import Quickshell
import "../"

Item {
    id: root
    visible: false

    property string screenName: Screen.name
    property real currentWidth: 1920.0
    property real currentHeight: 1080.0

    readonly property var rawConfig: (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings : ({})

    property real uiScale: {
        let raw = rawConfig || {};
        let sName = screenName || (Screen ? Screen.name : "");
        if (sName !== "" && raw.display && raw.display.monitors && raw.display.monitors[sName] && raw.display.monitors[sName].scale !== undefined) {
            return raw.display.monitors[sName].scale;
        }
        if (raw.general && raw.general.uiScale !== undefined) {
            return raw.general.uiScale;
        }
        if (raw.uiScale !== undefined) {
            return raw.uiScale;
        }
        return 1.0;
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            let raw = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings : {};
            let sName = root.screenName || (Screen ? Screen.name : "");
            let sVal = 1.0;
            if (sName !== "" && raw.display && raw.display.monitors && raw.display.monitors[sName] && raw.display.monitors[sName].scale !== undefined) {
                sVal = raw.display.monitors[sName].scale;
            } else if (raw.general && raw.general.uiScale !== undefined) {
                sVal = raw.general.uiScale;
            } else if (raw.uiScale !== undefined) {
                sVal = raw.uiScale;
            }
            if (root.uiScale !== sVal) {
                root.uiScale = sVal;
            }
        }
    }

    property real baseScale: uiScale

    function s(val) {
        return Math.round(val * baseScale);
    }
}
