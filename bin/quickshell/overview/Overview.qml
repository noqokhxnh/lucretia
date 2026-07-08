import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// Overview creates one PanelWindow per screen via LazyLoader/Variants pattern
// Root must be Item since it's instantiated inside Shell.qml's Item
Item {
    id: overviewRoot

    property var workspacesData: []
    property var windowsData: []

    // Niri workspaces refresh
    Process {
        id: niriWorkspacesProcess
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { overviewRoot.workspacesData = JSON.parse(this.text.trim()) } catch(e) {}
            }
        }
    }

    Process {
        id: niriWindowsProcess
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { overviewRoot.windowsData = JSON.parse(this.text.trim()) } catch(e) {}
            }
        }
    }

    Connections {
        target: Config
        function onOverviewOpenChanged() {
            if (Config.overviewOpen) {
                niriWorkspacesProcess.running = true
                niriWindowsProcess.running = true
            }
        }
    }

    // Create one panel window per screen
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                screen: modelData

                visible: Config.overviewOpen

                WlrLayershell.namespace: "quickshell:overview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                color: "transparent"

                anchors {
                    top: true; bottom: true; left: true; right: true
                }

                MatugenColors { id: mocha }



                // Background
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.4)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Config.overviewOpen = false
                    }
                }

                Item {
                    id: container
                    anchors.fill: parent
                    focus: Config.overviewOpen

                    opacity: Config.overviewOpen ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            Config.overviewOpen = false
                            event.accepted = true
                        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                            Config.overviewOpen = false
                            Config.sh("niri msg action focus-workspace " + (event.key - Qt.Key_0))
                            event.accepted = true
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 40
                        spacing: 20

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Workspaces"
                            font.family: "Outfit"
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            color: mocha.text
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 80
                            orientation: ListView.Horizontal
                            spacing: 24
                            model: overviewRoot.workspacesData

                            delegate: Rectangle {
                                required property var modelData
                                property int wsId: modelData.id || 0
                                property bool wsActive: modelData.is_active || modelData.active || false

                                width: win.screen.width * 0.38
                                height: parent.height - 20
                                radius: 16
                                color: wsActive
                                       ? Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.75)
                                       : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.3)
                                border.width: wsActive ? 2 : 1
                                border.color: wsActive ? mocha.mauve : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1)

                                Text {
                                    id: wsLabel
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 16
                                    text: "Workspace " + wsId
                                    font.family: "Outfit"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: wsActive ? mocha.mauve : mocha.subtext0
                                }

                                ListView {
                                    anchors { top: wsLabel.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 12 }
                                    orientation: ListView.Horizontal
                                    spacing: 10
                                    model: {
                                        let res = []
                                        let ws = wsId
                                        let wins = overviewRoot.windowsData || []
                                        for (let i = 0; i < wins.length; i++) {
                                            if (wins[i].workspace_id === ws) res.push(wins[i])
                                        }
                                        return res
                                    }

                                    delegate: Item {
                                        required property var modelData
                                        width: 180
                                        height: parent.height - 8

                                        OverviewWindow {
                                            anchors.fill: parent
                                            wsScale: 1.0
                                            screenX: 0
                                            screenY: 0
                                            title: modelData.title || ""
                                            appId: modelData.app_id || ""
                                            isFocused: modelData.is_focused || false
                                            toplevel: {
                                                let t = modelData.title
                                                let toplevels = ToplevelManager.toplevels
                                                if (!toplevels) return null
                                                for (let j = 0; j < toplevels.count; j++) {
                                                    let tl = toplevels.get(j)
                                                    if (tl && tl.title === t) return tl
                                                }
                                                return null
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    onClicked: {
                                        Config.overviewOpen = false
                                        Config.sh("niri msg action focus-workspace " + wsId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
