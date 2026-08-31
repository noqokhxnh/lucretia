pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: controller

    property bool isVisible: false
    property var screen: null

    function getScreen(scr) {
        if (scr === undefined || scr === null) return null;
        if (typeof scr === "object") return scr;
        if (typeof Quickshell !== "undefined" && Quickshell.screens) {
            if (typeof scr === "number") {
                if (scr >= 0 && scr < Quickshell.screens.length) {
                    return Quickshell.screens[scr];
                }
            }
            if (typeof scr === "string") {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === scr) {
                        return Quickshell.screens[i];
                    }
                }
            }
        }
        return scr;
    }

    function show(scr) {
        let target = getScreen(scr);
        if (target !== null && target !== undefined) {
            controller.screen = target;
        } else if (scr !== undefined && scr !== null) {
            controller.screen = scr;
        }
        controller.isVisible = true;
    }

    function hide() {
        controller.isVisible = false;
    }

    function toggle(scr) {
        let target = getScreen(scr);
        let resolved = target !== null ? target : scr;

        if (controller.isVisible) {
            if (resolved !== undefined && resolved !== null && controller.screen !== resolved) {
                controller.screen = resolved;
            } else {
                hide();
            }
        } else {
            show(resolved);
        }
    }
}
