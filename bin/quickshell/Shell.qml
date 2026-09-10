//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "watchers" as Watchers
import "."

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



    property int restartCount: 0
    property real lastRestartTime: 0

    Process {
        id: zombieCleanup
        command: ["bash", "-c", "killall -9 qs_daemon 2>/dev/null || true; pkill -f 'watchers/.*\\.sh' 2>/dev/null || true; QS_RUN=\"${XDG_RUNTIME_DIR:-/tmp}/lucretia\"; mkdir -p \"$QS_RUN\"; rm -f \"$QS_RUN/qs_daemon.sock\" \"$QS_RUN\"/qs_*.lock /tmp/quickshell_qs_daemon.sock"]
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
                Bar {}
                PopoutManager {}
                Keycast {}

                // --- Lazy-Loaded Overlays ---

                // 1. ScreenshotOverlay
                property bool screenshotActive: false
                property var pendingScreenshotArgs: null

                IpcHandler {
                    target: "screenshotOverlay"

                    function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
                        if (screenshotLoader.item && screenshotLoader.item.isActive) {
                            if (img && img !== "") Quickshell.execDetached(["bash", "-c", "rm -f " + img]);
                            screenshotLoader.item.deactivate();
                        } else {
                            activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
                        }
                    }

                    function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
                        if (screenshotLoader.item) {
                            screenshotLoader.item.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
                        } else {
                            pendingScreenshotArgs = [img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon];
                            screenshotActive = true;
                        }
                    }

                    function deactivate(): void {
                        if (screenshotLoader.item) {
                            screenshotLoader.item.deactivate();
                        }
                    }
                }

                Loader {
                    id: screenshotLoader
                    active: screenshotActive
                    sourceComponent: ScreenshotOverlay {
                        onIsActiveChanged: {
                            if (!isActive) {
                                screenshotUnloadTimer.restart();
                            }
                        }
                        Component.onCompleted: {
                            if (pendingScreenshotArgs) {
                                let a = pendingScreenshotArgs;
                                pendingScreenshotArgs = null;
                                activate(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
                            }
                        }
                    }
                }

                Timer {
                    id: screenshotUnloadTimer
                    interval: 1000
                    repeat: false
                    onTriggered: {
                        if (!screenshotLoader.item || !screenshotLoader.item.isActive) {
                            screenshotActive = false;
                        }
                    }
                }

                // 2. Lock Screen
                property bool lockActive: false
                property bool pendingLock: false

                IpcHandler {
                    target: "lock"
                    function activate(): void {
                        if (lockLoader.item) {
                            lockLoader.item.lock();
                        } else {
                            pendingLock = true;
                            lockActive = true;
                        }
                    }
                    function deactivate(): void {
                        if (lockLoader.item) {
                            lockLoader.item.completeUnlock();
                        }
                    }
                }

                Loader {
                    id: lockLoader
                    active: lockActive
                    sourceComponent: Lock {
                        onUnlocked: {
                            lockUnloadTimer.restart();
                        }
                        Component.onCompleted: {
                            if (pendingLock) {
                                pendingLock = false;
                                lock();
                            }
                        }
                    }
                }

                Timer {
                    id: lockUnloadTimer
                    interval: 1000
                    repeat: false
                    onTriggered: {
                        if (lockLoader.item && !lockLoader.item.isLocked) {
                            lockActive = false;
                        }
                    }
                }

                // 3. App Launcher
                property bool launcherLoaded: false

                Connections {
                    target: LauncherController
                    function onIsVisibleChanged() {
                        if (LauncherController.isVisible) {
                            launcherUnloadTimer.stop();
                            launcherLoaded = true;
                        } else {
                            launcherUnloadTimer.restart();
                        }
                    }
                }

                Timer {
                    id: launcherUnloadTimer
                    interval: 300000
                    repeat: false
                    onTriggered: {
                        if (!LauncherController.isVisible) {
                            launcherLoaded = false;
                        }
                    }
                }

                Loader {
                    id: launcherLoader
                    active: launcherLoaded
                    sourceComponent: Launcher {}
                }

                // 4. Clipboard History
                property bool clipboardLoaded: false

                Connections {
                    target: ClipboardController
                    function onIsVisibleChanged() {
                        if (ClipboardController.isVisible) {
                            clipboardUnloadTimer.stop();
                            clipboardLoaded = true;
                        } else {
                            clipboardUnloadTimer.restart();
                        }
                    }
                }

                Timer {
                    id: clipboardUnloadTimer
                    interval: 300000
                    repeat: false
                    onTriggered: {
                        if (!ClipboardController.isVisible) {
                            clipboardLoaded = false;
                        }
                    }
                }

                Loader {
                    id: clipboardLoader
                    active: clipboardLoaded
                    sourceComponent: Clipboard {}
                }

                // 5. Polkit Agent
                Loader {
                    active: PolkitService.isActive
                    sourceComponent: Polkit {}
                }

                Variants {
                    model: Quickshell.screens
                    delegate: WidgetLoader {
                        required property var modelData
                        screen: modelData
                        monitorName: modelData.name
                    }
                }

                Loader {
                    active: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.general && Config.rawSettings.general.quickactions !== undefined) ? Config.rawSettings.general.quickactions : true
                    sourceComponent: Floating {}
                }
            }
        }
    }
}
