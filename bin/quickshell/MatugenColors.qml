import QtQuick
import Quickshell
import "singletons"

Item {
    id: root

    // Direct reactive bindings to the central ThemeBackend singleton
    property color base: ThemeBackend.base
    property color mantle: ThemeBackend.mantle
    property color crust: ThemeBackend.crust
    property color text: ThemeBackend.text
    property color subtext0: ThemeBackend.subtext0
    property color subtext1: ThemeBackend.subtext1
    property color surface0: ThemeBackend.surface0
    property color surface1: ThemeBackend.surface1
    property color surface2: ThemeBackend.surface2
    property color overlay0: ThemeBackend.overlay0
    property color overlay1: ThemeBackend.overlay1
    property color overlay2: ThemeBackend.overlay2
    property color blue: ThemeBackend.blue
    property color sapphire: ThemeBackend.sapphire
    property color peach: ThemeBackend.peach
    property color green: ThemeBackend.green
    property color red: ThemeBackend.red
    property color mauve: ThemeBackend.mauve
    property color pink: ThemeBackend.pink
    property color yellow: ThemeBackend.yellow
    property color maroon: ThemeBackend.maroon
    property color teal: ThemeBackend.teal
    property color primary: ThemeBackend.blue
    property color on_primary: ThemeBackend.crust
}

