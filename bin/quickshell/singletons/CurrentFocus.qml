pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    property string appClass: ""
    property string appTitle: ""
    readonly property string displayText: appTitle !== "" ? appTitle : appClass
    readonly property bool isFocused: displayText !== ""

    FileView {
        id: focusWatcher
        path: (typeof Caching !== "undefined" && Caching.getRunDir && Caching.getRunDir("focustime")) ? (Caching.getRunDir("focustime") + "/focus_state.json") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = text().trim();
            if (txt !== "") {
                try {
                    let data = JSON.parse(txt);
                    let newCls = data.app_class || "";
                    let newTitle = data.app_title || "";
                    if (root.appClass !== newCls) root.appClass = newCls;
                    if (root.appTitle !== newTitle) root.appTitle = newTitle;
                } catch(e) {}
            } else {
                if (root.appClass !== "") root.appClass = "";
                if (root.appTitle !== "") root.appTitle = "";
            }
        }
    }
}
