import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../reusables"
import "../../"

Rectangle {
    id: sideInfoWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    readonly property bool isRightBar: barWindow ? (barWindow.barPosition === "right") : false

    property bool isRecording: false
    property int recSeconds: 0
    property real recStartEpoch: 0
    property string recTimeFormatted: String(Math.floor(recSeconds / 60)).padStart(2, "0") + ":" + String(recSeconds % 60).padStart(2, "0")
    readonly property string recCacheDir: Caching.cacheDir ? Caching.getCacheDir("recording") : ""

    readonly property bool isTimerActive: TimerState.isActive
    readonly property string timerTimeFormatted: TimerState.timeFormatted
    readonly property string timerIcon: TimerState.icon
    readonly property color timerColor: TimerState.colorType === "green" ? ((typeof ThemeBackend !== "undefined" && ThemeBackend.green !== undefined) ? ThemeBackend.green : Qt.rgba(166/255, 227/255, 161/255, 1.0)) : ThemeBackend.mauve

    readonly property bool hasActiveContent: isRecording || isTimerActive

    function checkRecording() {
        if (!sideInfoWidgetRoot.moduleActive || sideInfoWidgetRoot.recCacheDir === "") return;
        recCheckProc.running = false;
        recCheckProc.running = true;
    }

    onIsRecordingChanged: {
        if (!isRecording) {
            recSeconds = 0;
            recStartEpoch = 0;
        }
    }

    onRecCacheDirChanged: {
        if (recCacheDir !== "") {
            sideInfoWidgetRoot.checkRecording();
        }
    }

    Process {
        id: recCheckProc
        command: sideInfoWidgetRoot.recCacheDir ? [
            "bash", "-c",
            "d='" + sideInfoWidgetRoot.recCacheDir + "'; if [ -f \"$d/rec_pid\" ] && [ -f \"$d/rec_start_epoch\" ]; then p=$(cat \"$d/rec_pid\" 2>/dev/null); if [ -n \"$p\" ] && kill -0 \"$p\" 2>/dev/null; then cat \"$d/rec_start_epoch\" 2>/dev/null; else echo 'NONE'; fi; else echo 'NONE'; fi"
        ] : []
        stdout: StdioCollector {
            id: recCheckOut
            onStreamFinished: {
                let txt = recCheckOut.text.trim();
                let epoch = parseInt(txt);
                if (!isNaN(epoch) && epoch > 0) {
                    sideInfoWidgetRoot.recStartEpoch = epoch;
                    sideInfoWidgetRoot.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - epoch));
                    sideInfoWidgetRoot.isRecording = true;
                } else {
                    sideInfoWidgetRoot.isRecording = false;
                }
            }
        }
    }

    Process {
        id: recWatcher
        running: sideInfoWidgetRoot.moduleActive && sideInfoWidgetRoot.recCacheDir !== ""
        command: sideInfoWidgetRoot.recCacheDir ? [
            "bash", "-c",
            "mkdir -p '" + sideInfoWidgetRoot.recCacheDir + "' && inotifywait -m -e create,delete,modify,moved_to,moved_from '" + sideInfoWidgetRoot.recCacheDir + "' 2>/dev/null"
        ] : []
        stdout: SplitParser {
            onRead: data => {
                sideInfoWidgetRoot.checkRecording();
            }
        }
        onExited: {
            if (sideInfoWidgetRoot.moduleActive && sideInfoWidgetRoot.recCacheDir !== "") {
                recWatcherRestartTimer.restart();
            }
        }
        Component.onDestruction: running = false
    }

    Timer {
        id: recWatcherRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            recWatcher.running = false;
            recWatcher.running = true;
        }
    }

    Timer {
        id: recElapsedTimer
        interval: 1000
        running: sideInfoWidgetRoot.moduleActive && sideInfoWidgetRoot.isRecording
        repeat: true
        onTriggered: {
            sideInfoWidgetRoot.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - sideInfoWidgetRoot.recStartEpoch));
            if (sideInfoWidgetRoot.recSeconds % 5 === 0) {
                sideInfoWidgetRoot.checkRecording();
            }
        }
    }

    property int animDuration: 600
    property real targetY: 0
    y: targetY

    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging
        NumberAnimation { duration: sideInfoWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }

    property alias recCol: recCol
    property alias timerCol: timerCol

    property real verticalPadding: barWindow ? barWindow.s(10) : 10
    property real innerSpacing: barWindow ? barWindow.s(8) : 8

    property real recHeight: isRecording ? recCol.implicitHeight : 0
    property real timerHeight: isTimerActive ? timerCol.implicitHeight : 0
    property real activeSpacing: (isRecording && isTimerActive) ? innerSpacing : 0

    property real baseHeight: hasActiveContent ? (recHeight + timerHeight + activeSpacing + (verticalPadding * 2)) : 0
    property real baseWidth: barWindow ? barWindow.barHeight : 40

    property real targetWidth: moduleActive ? baseWidth : 0
    property real targetHeight: moduleActive ? baseHeight : 0

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    property bool isHovered: bgMouse.containsMouse
    property bool showLayout: false

    property real targetX: isRightBar ? (parent ? (parent.width - targetWidth) : 0) : 0
    x: targetX

    Behavior on x {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideInfoWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }

    width: targetWidth
    height: targetHeight

    readonly property bool isBarOpaque: (barWindow && barWindow.barOpacity !== undefined) ? (barWindow.barOpacity >= 1.0) : true
    readonly property bool paintOwnBackground: (!isGrouped && !isSolid)
    readonly property bool paintBaseBackground: (!isGrouped && !isSolid) || isBarOpaque

    color: "transparent"
    border.width: 0
    clip: true
    visible: (height > 0 || opacity > 0) && (!barWindow || !barWindow.positionChanging)
    opacity: (showLayout && moduleActive && hasActiveContent && (!barWindow || !barWindow.positionChanging)) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0

    Rectangle {
        id: bgRect
        z: -1
        width: parent.width
        height: parent.height
        radius: ThemeBackend.borderRadius
        color: sideInfoWidgetRoot.isHovered ? ThemeBackend.surface0 : ThemeBackend.base
        property bool showBorder: (!sideInfoWidgetRoot.isGrouped && !sideInfoWidgetRoot.isSolid)
        border.width: showBorder ? 1 : 0
        border.color: showBorder ? (sideInfoWidgetRoot.isHovered ? ThemeBackend.surface1 : ThemeBackend.surface0) : "transparent"
        visible: sideInfoWidgetRoot.paintOwnBackground && width > 0

        Behavior on color { enabled: barWindow ? !barWindow.positionChanging : true; ColorAnimation { duration: 250 } }
    }

    Behavior on width {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideInfoWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on height {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideInfoWidgetRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
    }

    transform: Translate {
        x: sideInfoWidgetRoot.showLayout ? 0 : (barWindow ? (sideInfoWidgetRoot.isRightBar ? barWindow.s(20) : barWindow.s(-20)) : (sideInfoWidgetRoot.isRightBar ? 20 : -20))
        Behavior on x {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    Timer {
        running: barWindow && barWindow.isStartupReady
        interval: 120
        onTriggered: sideInfoWidgetRoot.showLayout = true
    }

    Item {
        id: topArea
        width: barWindow ? barWindow.barHeight : 40
        height: parent.height
        x: sideInfoWidgetRoot.isRightBar ? (parent.width - width) : 0

        Column {
            id: centerActiveCol
            anchors.centerIn: parent
            spacing: sideInfoWidgetRoot.innerSpacing

            Column {
                id: recCol
                spacing: barWindow ? barWindow.s(4) : 4
                visible: isRecording
                opacity: isRecording ? 1.0 : 0.0
                anchors.horizontalCenter: parent.horizontalCenter
                Behavior on opacity {
                    enabled: barWindow ? !barWindow.positionChanging : true
                    NumberAnimation { duration: 300 }
                }

                Rectangle {
                    id: recDot
                    width: barWindow ? barWindow.s(10) : 10
                    height: barWindow ? barWindow.s(10) : 10
                    radius: barWindow ? barWindow.s(5) : 5
                    color: ThemeBackend.red
                    anchors.horizontalCenter: parent.horizontalCenter

                    SequentialAnimation on opacity {
                        running: isRecording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    id: recText
                    text: recTimeFormatted
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: barWindow ? barWindow.s(11) : 11
                    font.weight: Font.Bold
                    color: ThemeBackend.red
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Column {
                id: timerCol
                spacing: barWindow ? barWindow.s(4) : 4
                visible: isTimerActive
                opacity: isTimerActive ? 1.0 : 0.0
                anchors.horizontalCenter: parent.horizontalCenter
                Behavior on opacity {
                    enabled: barWindow ? !barWindow.positionChanging : true
                    NumberAnimation { duration: 300 }
                }

                Text {
                    text: timerIcon
                    font.family: "Font Awesome 6 Free Solid"
                    font.pixelSize: barWindow ? barWindow.s(12) : 12
                    color: sideInfoWidgetRoot.timerColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Text {
                    id: timerText
                    text: timerTimeFormatted
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: barWindow ? barWindow.s(11) : 11
                    font.weight: Font.Bold
                    color: sideInfoWidgetRoot.timerColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }
        }
    }

    Component.onCompleted: {
        sideInfoWidgetRoot.checkRecording();
    }
}
