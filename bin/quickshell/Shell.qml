//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "watchers" as Watchers
import "overview" as OverviewModule


ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    Caching { id: paths }
    
    Process {
        id: zombieCleanup
        command: ["bash", "-c", "pkill -f 'inotifywait.*quickshell'; pkill -f 'watchers/.*_wait.sh'; pkill -f 'dbus-monitor.*org.bluez'; pkill -f 'nmcli monitor'; pkill -f 'udevadm monitor'; pkill -f 'pactl subscribe'; pkill -f 'socat.*socket2.sock'; pkill -x qs_daemon; rm -f \"${XDG_RUNTIME_DIR:-/tmp}/quickshell/qs_\"*\".lock\"; rm -rf ~/.cache/quickshell/crashes/*"]
        running: true
        onExited: {
            qsDaemon.running = true
            wsDaemon.running = true
            mainLoader.active = true
        }
    }

    Process {
        id: wsDaemon
        command: ["bash", "-c", "~/.config/niri/bin/workspaces.sh"]
        running: false
    }

    Process {
        id: qsDaemon
        command: [Quickshell.env("HOME") + "/.config/niri/bin/quickshell/qs_daemon"]
        running: false
        onExited: (exitCode) => {
            console.log("qs_daemon exited with code: " + exitCode + ". Restarting...")
            running = false
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: qsDaemon.running = true
    }

    Loader {
        id: mainLoader
        active: false
        sourceComponent: Component {
            Item {
                Watchers.AutoPowerManager {}
                Main {}
                TopBar {}
                Floating {}
                Keycast {}
                OverviewModule.Overview {}
            }
        }
    }
}

