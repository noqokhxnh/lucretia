//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "watchers" as Watchers
import "polkit" as Polkit
// import "overview" as OverviewModule (removed)

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }
        function onReloadFailed(errorString) {
            Quickshell.inhibitReloadPopup();
        }
    }

    Caching {
        id: paths
    }

    property int restartCount: 0
    property real lastRestartTime: 0

    Process {
        id: zombieCleanup
        command: ["bash", "-c", "killall -9 qs_daemon 2>/dev/null || true; pkill -f 'watchers/.*\\.sh' 2>/dev/null || true; QS_RUN=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell\"; mkdir -p \"$QS_RUN\"; rm -f \"$QS_RUN/qs_daemon.sock\" \"$QS_RUN\"/qs_*.lock /tmp/quickshell_qs_daemon.sock; rm -rf ~/.cache/quickshell/crashes/*"]
        running: true
        onExited: {
            qsDaemon.running = true;
            wsDaemon.running = true;
            mainLoader.active = true;
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
        onExited: exitCode => {
            let now = Date.now();
            if (now - lastRestartTime < 5000) {
                restartCount++;
            } else {
                restartCount = 0;
            }
            lastRestartTime = now;

            let delay = Math.min(1000 * Math.pow(2, restartCount), 30000);
            console.log("qs_daemon exited with code: " + exitCode + ". Restarting in " + (delay / 1000) + "s...");

            restartTimer.interval = delay;
            running = false;
            restartTimer.start();
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
                Polkit.Polkit {}
            }
        }
    }
}
