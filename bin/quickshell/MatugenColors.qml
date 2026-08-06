import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Explicitly typed as 'color' for strict QML binding
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"
    property color primary: "#89b4fa"
    property color on_primary: "#181825"

    property string rawJson: ""
    readonly property string _colorsFile: Quickshell.env("HOME") + "/.config/niri/bin/quickshell/qs_colors.json"

    function _extractHex(val) {
        if (!val) return null;
        if (typeof val === "string") return val;
        if (typeof val === "object" && val.color) return val.color;
        return null;
    }

    function _applyColors(txt) {
        if (!txt || txt.trim() === "" || txt === root.rawJson) return;
        try {
            let c = JSON.parse(txt);
            let setHex = function(propName, rawVal) {
                let hex = _extractHex(rawVal);
                if (hex) root[propName] = hex;
            };

            setHex("base", c.base);
            setHex("mantle", c.mantle);
            setHex("crust", c.crust);
            setHex("text", c.text);
            setHex("subtext0", c.subtext0);
            setHex("subtext1", c.subtext1);
            setHex("surface0", c.surface0);
            setHex("surface1", c.surface1);
            setHex("surface2", c.surface2);
            setHex("overlay0", c.overlay0);
            setHex("overlay1", c.overlay1);
            setHex("overlay2", c.overlay2);
            setHex("blue", c.blue);
            setHex("sapphire", c.sapphire);
            setHex("peach", c.peach);
            setHex("green", c.green);
            setHex("red", c.red);
            setHex("mauve", c.mauve);
            setHex("pink", c.pink);
            setHex("yellow", c.yellow);
            setHex("maroon", c.maroon);
            setHex("teal", c.teal);
            setHex("primary", c.primary);
            setHex("on_primary", c.on_primary);

            root.rawJson = txt;
        } catch(e) {}
    }

    FileView {
        id: colorsFileView
        path: root._colorsFile
        // FileView only watches the file when this is true (default: false),
        // and text() returns the cached content — without this, colors would
        // only refresh after a shell restart.
        watchChanges: true
        onFileChanged: colorsFileView.reload()
        onTextChanged: root._applyColors(colorsFileView.text())
    }

    Component.onCompleted: {
        root._applyColors(colorsFileView.text());
    }

    // Safety net for missed watch events (e.g. atomic rename): slow re-read
    // instead of polling every second in every instance.
    Timer {
        id: pollTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: colorsFileView.reload()
    }
}
