import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Io
import "../"
import "../components" as Components

Item {
    id: window
    focus: true

    property int layoutWidth: 860
    property int layoutHeight: 760

    // Used by Main.qml to dynamically resize the master window
    property int targetMasterWidth: 860
    property int targetMasterHeight: 760

    readonly property string photoDir: Quickshell.env("HOME") + "/Pictures/PhotoBooth"

    MatugenColors { id: _theme }

    readonly property color bg:       _theme.base
    readonly property color fg:       _theme.text
    readonly property color surf0:    _theme.surface0
    readonly property color surf1:    _theme.surface1
    readonly property color surf2:    _theme.surface2
    readonly property color mantle:   _theme.mantle
    readonly property color crust:    _theme.crust
    readonly property color mauve:    _theme.mauve

    readonly property color macRed:    "#ff5f56"
    readonly property color macYellow: "#ffbd2e"
    readonly property color macGreen:  "#27c93f"

    // --- State ---
    property string captureMode:    "single"   // "single" | "burst" | "video"
    property bool   isRecording:    false
    property bool   isMirrored:     true
    property int    countdown:      0
    property bool   isCountingDown: false
    property bool   flashActive:    false
    property bool   isSessionActive: false
    property bool   isMinimized:    false

    property int  burstCount: 0
    property int  burstProgress: 0
    property var  burstFiles: []
    property bool _burstInProgress: false

    // Intro animation
    property real introPhase: 1
    NumberAnimation on introPhase {
        id: introAnim
        from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic
    }

    // --- Clip Roll ---
    ListModel { id: clipRollModel }

    function initializeSession() {
        introAnim.restart()

        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + window.photoDir + "'"])

        if (!window.isSessionActive) {
            console.log("Starting new Photo Booth session")
            Components.QsDaemonClient.sendRequest("photobooth", "setup", {}, null)
            Components.QsDaemonClient.sendRequest("photobooth", "start_session", {}, null)
            clipRollModel.clear()
            window.isSessionActive = true
        } else {
            console.log("Restoring Photo Booth session from minimize")
            loadSession()
        }
        window.isMinimized = false
    }

    Component.onCompleted: {
        if (window.visible) {
            initializeSession()
        }
    }

    onVisibleChanged: {
        if (visible) {
            initializeSession()
        }
    }

    Connections {
        target: masterWindow
        function onCurrentActiveChanged() {
            if (masterWindow.currentActive !== "photobooth") {
                if (!window.isMinimized) {
                    console.log("Closing Photo Booth session")
                    window.isSessionActive = false
                }
            }
        }
    }

    function addCaptureToRoll(path) {
        let filename = path.substring(path.lastIndexOf('/') + 1)
        clipRollModel.insert(0, { name: filename, path: "file://" + path })
        Components.QsDaemonClient.sendRequest("photobooth", "add_to_session", { path: path }, null)
    }

    function loadSession() {
        Components.QsDaemonClient.sendRequest("photobooth", "get_session", {}, function(data) {
            if (data) {
                clipRollModel.clear()
                for (let item of data) {
                    clipRollModel.append(item)
                }
            }
        })
    }

    // --- Timers ---
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (window.countdown > 1) {
                window.countdown--
            } else {
                window.countdown = 0
                window.isCountingDown = false
                stop()
                doCapture()
            }
        }
    }

    Timer {
        id: flashTimer
        interval: 200
        onTriggered: window.flashActive = false
    }

    Timer {
        id: burstTimer
        interval: 900
        repeat: true
        onTriggered: {
            window.burstProgress = window.burstCount + 1
            window.flashActive = true
            flashTimer.restart()
            let fname = "burst_" + window.burstCount + "_" + Date.now() + ".jpg"
            let fpath = window.photoDir + "/" + fname
            window.burstFiles.push(fpath)
            imageCapture.captureToFile(fpath)
            window.burstCount++
            if (window.burstCount >= 4) {
                stop()
                stitchBurst()
            }
        }
    }

    // --- Functions ---
    function startCountdown() {
        if (window.captureMode === "video") {
            if (window.isRecording) {
                window.isRecording = false
                recorder.stop()
                let path = recorder.outputLocation.toString().replace("file://", "")
                let fname = path.substring(path.lastIndexOf('/') + 1)
                addCaptureToRoll(path)
            } else {
                window.isRecording = true
                let fname = "video_" + Date.now() + ".mp4"
                recorder.outputLocation = "file://" + window.photoDir + "/" + fname
                recorder.record()
            }
            return
        }
        if (window.isCountingDown) return
        window.countdown = 3
        window.isCountingDown = true
        countdownTimer.restart()
    }

    function doCapture() {
        if (window.captureMode === "single") {
            singleShot()
        } else if (window.captureMode === "burst") {
            window.burstCount = 0
            window.burstFiles = []
            window._burstInProgress = true
            burstTimer.restart()
        }
    }

    function singleShot() {
        window.flashActive = true
        flashTimer.restart()
        let path = window.photoDir + "/photo_" + Date.now() + ".jpg"
        imageCapture.captureToFile(path)
        // addCaptureToRoll is called by imageCapture.onFileSaved when file is ready
    }

    function stitchBurst() {
        let fname = "burst_" + Date.now() + ".jpg"
        let out = window.photoDir + "/" + fname

        let inFiles = window.burstFiles.slice()
        window._burstInProgress = false

        Components.QsDaemonClient.sendRequest("photobooth", "burst", { inputs: inFiles, output: out }, function(res) {
            clipRollModel.insert(0, { name: fname, path: "file://" + out })
            window.burstFiles = []
        })
    }

    function openFolder() {
        Quickshell.execDetached(["bash", "-c", "unset HL_INITIAL_WORKSPACE_TOKEN && exec nautilus " + window.photoDir])
    }

    // --- Camera ---
    CaptureSession {
        id: captureSession
        camera: Camera {
            id: camera
            active: window.visible && window.isSessionActive
        }
        imageCapture: ImageCapture {
            id: imageCapture
            onFileSaved: (id, path) => {
                // Only auto-add for single shot; burst handles UI via stitchBurst callback
                if (!window._burstInProgress) {
                    addCaptureToRoll(path)
                }
            }
        }
        recorder: MediaRecorder { id: recorder }
        videoOutput: cameraOutput
    }

    // =========================================================
    // UI ROOT
    // =========================================================
    Item {
        id: uiRoot
        anchors.fill: parent
        anchors.margins: 8

        transform: Scale {
            origin.x: uiRoot.width / 2
            origin.y: uiRoot.height / 2
            xScale: 0.92 + window.introPhase * 0.08
            yScale: 0.92 + window.introPhase * 0.08
        }
        opacity: window.introPhase

        // Outer drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: 30
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.6)
            border.width: 1
            z: -1
        }

        // Main card
        Rectangle {
            id: card
            anchors.fill: parent
            radius: 28
            color: window.mantle
            clip: true

            // Camera preview — fills the entire card
            Rectangle {
                id: previewArea
                anchors.fill: parent
                anchors.bottomMargin: filmStrip.height
                color: "#000000"
                clip: true

                VideoOutput {
                    id: cameraOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                    transform: Rotation {
                        origin.x: cameraOutput.width / 2
                        origin.y: cameraOutput.height / 2
                        axis: Qt.vector3d(0, 1, 0)
                        angle: window.isMirrored ? 180 : 0
                    }
                }

                // --- Overlays on top of camera preview ---

                // Countdown
                Text {
                    anchors.centerIn: parent
                    text: window.countdown
                    font.family: "Inter"
                    font.pixelSize: 130
                    font.weight: Font.Bold
                    color: "white"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                    visible: window.isCountingDown && window.countdown > 0
                }

                // Burst progress
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 80
                    text: "Shot " + window.burstProgress + " / 4"
                    font.family: "Inter"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "white"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                    visible: window.captureMode === "burst" && window.burstCount > 0 && window.burstCount < 4
                }

                // Flash
                Rectangle {
                    anchors.fill: parent
                    color: "white"
                    opacity: window.flashActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }

                // REC badge
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 8
                    visible: window.isRecording

                    Rectangle {
                        width: 10; height: 10; radius: 5; color: "#ff3b30"
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0.2; duration: 500 }
                            NumberAnimation { from: 0.2; to: 1; duration: 500 }
                        }
                    }
                    Text {
                        text: "REC"
                        color: "#ff3b30"
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // --- macOS-style capture button (bottom center, overlapping preview/filmstrip) ---
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -30
                    width: 84; height: 84
                    z: 10

                    // Outer ring (drop shadow)
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                        border.width: 3
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(0, 0, 0, 0.25)
                            border.width: 1
                        }
                    }

                    // Inner button
                    Rectangle {
                        anchors.centerIn: parent
                        width: 66; height: 66
                        radius: width / 2

                        // Gradient-like effect with layered rectangles
                        color: "#ff3b30"
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(0, 0, 0, 0.15)
                            border.width: 1
                        }
                        // Shine (top half highlight)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * 0.55
                            radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.18)
                            clip: true
                        }

                        // Inner highlight ring
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.25)
                            border.width: 1
                        }

                        // Icon or stop (for video recording)
                        Rectangle {
                            anchors.centerIn: parent
                            width: window.isRecording ? 22 : 0
                            height: window.isRecording ? 22 : 0
                            radius: 4
                            color: "white"
                            Behavior on width  { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !window.isRecording
                            text: window.captureMode === "video" ? "󰕧" : (window.captureMode === "burst" ? "󰄄" : "󰄀")
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 22
                            color: "white"
                            opacity: 0.9
                        }

                        // Pressed state
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "white"
                            opacity: captureMa.pressed ? 0.25 : 0
                        }
                    }

                    MouseArea {
                        id: captureMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: startCountdown()
                    }
                }
            }

            // --- Floating traffic lights (top-left) ---
            Row {
                id: trafficLights
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.leftMargin: 14
                spacing: 8
                z: 10

                Rectangle {
                    width: 13; height: 13; radius: 7
                    color: window.macRed
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Qt.rgba(0,0,0,0.6)
                        opacity: redMa.containsMouse ? 1 : 0
                    }
                    MouseArea {
                        id: redMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            window.isSessionActive = false
                            window.isMinimized = false
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"])
                        }
                    }
                }
                Rectangle {
                    width: 13; height: 13; radius: 7
                    color: window.macYellow
                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Qt.rgba(0,0,0,0.6)
                        opacity: yellowMa.containsMouse ? 1 : 0
                    }
                    MouseArea {
                        id: yellowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            window.isMinimized = true
                            masterWindow.isVisible = false
                        }
                    }
                }
                Rectangle {
                    width: 13; height: 13; radius: 7
                    color: window.macGreen
                    Text {
                        anchors.centerIn: parent
                        text: "⤢"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: Qt.rgba(0,0,0,0.6)
                        opacity: greenMa.containsMouse ? 1 : 0
                    }
                    MouseArea {
                        id: greenMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            masterWindow.disableMorph = false
                            let screen = Quickshell.screens[0]
                            let defaultW = 860, defaultH = 760
                            let zoomW = Math.min(1000, screen.width - 80)
                            let zoomH = Math.min(900, screen.height - 80)
                            if (masterWindow.animW > defaultW + 20) {
                                masterWindow.animW = defaultW
                                masterWindow.animH = defaultH
                                masterWindow.animX = (screen.width - defaultW) / 2
                                masterWindow.animY = (screen.height - defaultH) / 2
                            } else {
                                masterWindow.animW = zoomW
                                masterWindow.animH = zoomH
                                masterWindow.animX = (screen.width - zoomW) / 2
                                masterWindow.animY = (screen.height - zoomH) / 2
                            }
                        }
                    }
                }
            }

            // --- Floating mode selector (top-right) ---
            Row {
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                spacing: 4
                z: 10

                Repeater {
                    model: [
                        { icon: "󰄀", key: "single", tip: "Photo" },
                        { icon: "󰄄", key: "burst",  tip: "Burst" },
                        { icon: "󰕧", key: "video",  tip: "Video" }
                    ]

                    Item {
                        width: 32; height: 26
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: window.captureMode === modelData.key ? Qt.rgba(1,1,1,0.2) : Qt.rgba(0,0,0,0.25)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 15
                                color: window.captureMode === modelData.key ? "white" : Qt.rgba(1,1,1,0.55)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: window.captureMode = modelData.key
                        }
                    }
                }
            }

            // --- Film strip at bottom ---
            Rectangle {
                id: filmStrip
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 100
                color: Qt.rgba(0, 0, 0, 0.55)
                z: 5

                // Empty state
                Item {
                    anchors.fill: parent
                    visible: clipRollModel.count === 0
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: 0.3
                        Text {
                            text: "󰄀"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 18
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "No Photos Yet"
                            font.family: "Inter"
                            font.pixelSize: 12
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                ListView {
                    id: filmListView
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    orientation: ListView.Horizontal
                    spacing: 8
                    model: clipRollModel
                    visible: clipRollModel.count > 0
                    clip: true

                    delegate: Item {
                        width: 80
                        height: filmListView.height - 20

                        Rectangle {
                            id: thumb
                            anchors.fill: parent
                            radius: 6
                            color: "#222"
                            clip: true

                            // macOS-style white stroke on latest
                            border.color: index === 0 ? "white" : "transparent"
                            border.width: index === 0 ? 2 : 0

                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            Image {
                                anchors.fill: parent
                                source: model.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 0.3)
                                visible: thumbMa.containsMouse
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰁍"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 16
                                    color: "white"
                                    opacity: 0.8
                                }
                            }

                            MouseArea {
                                id: thumbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    let p = model.path.replace("file://", "")
                                    Quickshell.execDetached(["bash", "-c", "unset HL_INITIAL_WORKSPACE_TOKEN && exec xdg-open '" + p.replace(/'/g, "'\\''") + "'"])
                                }
                            }
                        }
                    }
                }

                // Bottom-right utility buttons (inside film strip)
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    z: 6
                    visible: clipRollModel.count > 0

                    // Open folder
                    Item {
                        width: 28; height: 28
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: folderMa.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.3)
                            Text {
                                anchors.centerIn: parent
                                text: "󰉋"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 14
                                color: folderMa.containsMouse ? "white" : Qt.rgba(1,1,1,0.6)
                            }
                        }
                        MouseArea {
                            id: folderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: openFolder()
                        }
                    }
                }
            }

            // --- Drag/resize overlay ---
            MouseArea {
                anchors.fill: parent
                property real lastGlobalX: 0
                property real lastGlobalY: 0
                property string resizeSideX: "right"
                property string resizeSideY: "bottom"
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onPressed: (mouse) => {
                    let globalPos = mapToItem(null, mouse.x, mouse.y)
                    lastGlobalX = globalPos.x
                    lastGlobalY = globalPos.y
                    resizeSideX = (mouse.x < width / 2) ? "left" : "right"
                    resizeSideY = (mouse.y < height / 2) ? "top" : "bottom"
                    masterWindow.disableMorph = true
                }

                onReleased: {
                    masterWindow.disableMorph = false
                }

                onPositionChanged: (mouse) => {
                    let globalPos = mapToItem(null, mouse.x, mouse.y)
                    let dx = globalPos.x - lastGlobalX
                    let dy = globalPos.y - lastGlobalY

                    if (mouse.buttons & Qt.LeftButton) {
                        masterWindow.animX += dx
                        masterWindow.animY += dy
                    } else if (mouse.buttons & Qt.RightButton) {
                        let targetW = masterWindow.animW
                        if (resizeSideX === "left") {
                            targetW = Math.max(600, masterWindow.animW - dx)
                            masterWindow.animX += (masterWindow.animW - targetW)
                        } else {
                            targetW = Math.max(600, masterWindow.animW + dx)
                        }
                        masterWindow.animW = targetW

                        let targetH = masterWindow.animH
                        if (resizeSideY === "top") {
                            targetH = Math.max(500, masterWindow.animH - dy)
                            masterWindow.animY += (masterWindow.animH - targetH)
                        } else {
                            targetH = Math.max(500, masterWindow.animH + dy)
                        }
                        masterWindow.animH = targetH
                    }

                    lastGlobalX = globalPos.x
                    lastGlobalY = globalPos.y
                }

                cursorShape: {
                    if (pressedButtons & Qt.RightButton) {
                        if (resizeSideX === "left") {
                            return (resizeSideY === "top") ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                        } else {
                            return (resizeSideY === "top") ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                        }
                    }
                    if (pressedButtons & Qt.LeftButton) return Qt.SizeAllCursor
                    return Qt.ArrowCursor
                }
            }
        } // card
    } // uiRoot

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/bin/qs_manager.sh", "close"])
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            startCountdown()
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            window.isMirrored = !window.isMirrored
            event.accepted = true
        }
    }
}
