import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideKbRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property string kbLayout: "US"
    property real targetY: 0
    property bool showLayout: false
    property alias kbPill: kbBtn
    property bool isNiri: false
    property bool isSway: false

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        sideKbRoot.isNiri = de.indexOf("niri") !== -1;
        sideKbRoot.isSway = de.indexOf("sway") !== -1;
    }

    onModuleActiveChanged: {
        if (!moduleActive) {
            kbPoller.running = false;
            kbWaiter.running = false;
        } else {
            kbPoller.running = false;
            kbPoller.running = true;
        }
    }

    Process {
        id: kbPoller
        running: sideKbRoot.moduleActive
        command: [
            "bash",
            "-c",
            sideKbRoot.isNiri
                ? "layout=$(niri msg -j keyboard-layouts 2>/dev/null | jq -r '.names[.current_idx] // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                : (sideKbRoot.isSway
                    ? "layout=$(swaymsg -t get_inputs 2>/dev/null | jq -r '[.[] | select(.type == \"keyboard\" and .xkb_active_layout_name != null)] | .[0].xkb_active_layout_name // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                    : "layout=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // .keyboards[0].active_keymap // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'")
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && kbLayout !== txt) kbLayout = txt;
                kbWaiter.running = false;
                if (sideKbRoot.moduleActive) kbWaiter.running = true;
                if (barWindow) barWindow.fastPollerLoaded = true;
            }
        }
    }

    Process {
        id: kbWaiter
        command: [
            "bash",
            Caching.qsDir + "/watchers/kb_wait.sh",
            sideKbRoot.isNiri ? "niri" : (sideKbRoot.isSway ? "sway" : "hyprland")
        ]
        onExited: {
            kbPoller.running = false;
            if (sideKbRoot.moduleActive) kbPoller.running = true;
        }
    }

    y: targetY
    width: barWindow ? barWindow.barHeight : 40
    height: barWindow ? barWindow.barHeight : 40

    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    radius: ThemeBackend.borderRadius
    border.width: (isGrouped || isSolid) ? 0 : 1
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: sideKbRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: sideKbRoot.showLayout = true
    }

    ClickButton {
        id: kbBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(30) : 30
        height: barWindow ? barWindow.s(30) : 30
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        horizontalPadding: 0
        buttonText: kbLayout
        textFontSize: barWindow ? barWindow.s(12) : 12
        accentColor: ThemeBackend.surface0
        textColor: ThemeBackend.text

        onClicked: {
            if (sideKbRoot.isNiri) {
                Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
            } else if (sideKbRoot.isSway) {
                Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
            } else {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
            }
        }
    }
}
