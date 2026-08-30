import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"
import "../reusables"
import "../singletons"

Item {
    id: window
    focus: true

    readonly property real sf: Scaler.baseScale

    function s(val) {
        return Math.round(val * window.sf);
    }

    property real targetMasterHeight: Math.round(510 * window.sf)
    property real targetMasterWidth: Math.round(1360 * window.sf)

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    Shortcut {
        sequence: "Left"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

    readonly property color base: ThemeBackend.base
    readonly property color mantle: ThemeBackend.mantle
    readonly property color crust: ThemeBackend.crust
    readonly property color text: ThemeBackend.text
    readonly property color subtext1: ThemeBackend.subtext1
    readonly property color subtext0: ThemeBackend.subtext0
    readonly property color overlay2: ThemeBackend.overlay2
    readonly property color overlay1: ThemeBackend.overlay1
    readonly property color overlay0: ThemeBackend.overlay0
    readonly property color surface2: ThemeBackend.surface2
    readonly property color surface1: ThemeBackend.surface1
    readonly property color surface0: ThemeBackend.surface0

    readonly property color mauve: ThemeBackend.mauve
    readonly property color pink: ThemeBackend.pink
    readonly property color blue: ThemeBackend.blue
    readonly property color sapphire: ThemeBackend.sapphire
    readonly property color peach: ThemeBackend.peach
    readonly property color yellow: ThemeBackend.yellow
    readonly property color teal: ThemeBackend.teal
    readonly property color green: ThemeBackend.green
    readonly property color red: ThemeBackend.red

    readonly property string scriptsDir: Caching.qsDir + "/calendar"

    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.peach;
        if (h >= 12 && h < 17) return window.sapphire;
        if (h >= 17 && h < 21) return window.mauve;
        return window.blue;
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.yellow;
        if (h >= 12 && h < 17) return window.teal;
        if (h >= 17 && h < 21) return window.pink;
        return window.mauve;
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(window.text, 0.35))

    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    function resetAndPlayIntro() {
        startupComplete = false;
        introMain = 0;
        introAmbient = 0;
        introClock = 0;
        introCalendar = 0;
        introWeather = 0;
        introAnim.restart();
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            window.currentTime = new Date();
            updateCalendarGrid();
            weatherPoller.running = false;
            weatherPoller.running = true;
            resetAndPlayIntro();
        } else {
            introAnim.stop();
            exitAnim.stop();
            startupComplete = false;
            introMain = 0;
            introAmbient = 0;
            introClock = 0;
            introCalendar = 0;
            introWeather = 0;
        }
    }

    SequentialAnimation {
        id: introAnim
        running: false

        PauseAnimation { duration: 20 }

        ParallelAnimation {
            NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }

            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: 1000; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: 250 }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: 350 }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 400 }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: window; property: "introMain"; to: 0; duration: 400; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introAmbient"; to: 0; duration: 250; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introClock"; to: 0; duration: 300; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introCalendar"; to: 0; duration: 350; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introWeather"; to: 0; duration: 350; easing.type: Easing.InQuart }
    }

    property real globalOrbitOffset: 0
    NumberAnimation on globalOrbitOffset {
        from: 0; to: -540; duration: 90000; loops: Animation.Infinite; running: window.visible
    }

    property real globalOscPhase: 0
    NumberAnimation on globalOscPhase {
        from: 0; to: Math.PI * 2; duration: 9000; loops: Animation.Infinite; running: window.visible
    }

    property var currentTime: new Date()
    property real currentEpoch: currentTime.getTime() / 1000

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    Timer {
        interval: 1000; running: window.visible; repeat: true
        onTriggered: {
            window.currentTime = new Date();
            window.secondPulse = 1.06;
            pulseReset.start();

            if (window.currentTime.getHours() === 0 && window.currentTime.getMinutes() === 0 && window.currentTime.getSeconds() === 0) {
                updateCalendarGrid();
            }
        }
    }

    property var weatherData: null
    property int weatherView: 0
    property color activeWeatherHex: {
        if (!window.weatherData) return window.mauve;
        if (window.weatherView === 0 && window.weatherData.current_hex) return window.weatherData.current_hex;
        if (window.weatherData.forecast && window.weatherData.forecast[window.weatherView]) return window.weatherData.forecast[window.weatherView].hex;
        return window.mauve;
    }

    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1

    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    property real targetTemp: {
        if (!window.weatherData) return 0;
        if (window.targetWeatherView === 0 && window.weatherData.current_temp !== undefined) {
            return Number(window.weatherData.current_temp);
        }
        if (window.weatherData.forecast && window.weatherData.forecast[window.targetWeatherView]) {
            return Number(window.weatherData.forecast[window.targetWeatherView].max);
        }
        return 0;
    }

    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        if (window.targetTemp > window.displayedTemp) return window.red;
        if (window.targetTemp < window.displayedTemp) return window.blue;
        return window.text;
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: Math.round(-40 * window.sf) * weatherAnimDirection; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: 300; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                window.weatherView = window.targetWeatherView;
                window.weatherContentOffset = Math.round(40 * window.sf) * weatherAnimDirection;
                window.transitionSpin = -180 * weatherAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || !window.weatherData) return;
        if (idx === window.targetWeatherView) return;

        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
        }

        window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;

        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;

        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let h = parseInt(timeStr.split(":")[0]);
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    Process {
        id: weatherPoller
        command: ["bash", Caching.serpantinumDir + "/scripts/weather.sh", "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { window.weatherData = JSON.parse(txt); } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 150000
        running: window.visible; repeat: true
        onTriggered: {
            weatherPoller.running = false;
            weatherPoller.running = true;
        }
    }

    property real centerOffset: 0
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: Math.round(-20 * window.sf) * calendarAnimDirection; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = Math.round(20 * window.sf) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 350; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 350; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        window.targetMonthName = Qt.formatDateTime(d, "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            weatherPoller.running = true;
            resetAndPlayIntro();
        }
    }

    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: window.base
            border.color: window.surface0
            border.width: 1
            clip: true

            Rectangle {
                width: parent.width * 0.5; height: width; radius: width / 2
                x: parent.width * 0.75 - width / 2
                y: parent.height * 0.3 - height / 2
                opacity: 0.012 * window.introAmbient
                color: window.activeWeatherHex
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: Math.round(350 * window.sf); to: Math.round(-350 * window.sf); duration: 30000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: Math.round(-350 * window.sf); to: Math.round(350 * window.sf); duration: 30000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: 0; to: Math.round(200 * window.sf); duration: 15000; easing.type: Easing.OutSine }
                        NumberAnimation { from: Math.round(200 * window.sf); to: Math.round(-200 * window.sf); duration: 30000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: Math.round(-200 * window.sf); to: 0; duration: 15000; easing.type: Easing.InSine }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.6; height: width; radius: width / 2
                x: parent.width * 0.25 - width / 2
                y: parent.height * 0.7 - height / 2
                opacity: 0.01 * window.introAmbient
                color: window.timeColor
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: 0; to: Math.round(-300 * window.sf); duration: 18750; easing.type: Easing.OutSine }
                        NumberAnimation { from: Math.round(-300 * window.sf); to: Math.round(300 * window.sf); duration: 37500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: Math.round(300 * window.sf); to: 0; duration: 18750; easing.type: Easing.InSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: Math.round(-250 * window.sf); to: Math.round(250 * window.sf); duration: 37500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: Math.round(250 * window.sf); to: Math.round(-250 * window.sf); duration: 37500; easing.type: Easing.InOutSine }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.45; height: width; radius: width / 2
                x: parent.width * 0.5 - width / 2
                y: parent.height * 0.5 - height / 2
                opacity: 0.007 * window.introAmbient
                color: window.timeAccent
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: Math.round(400 * window.sf); to: Math.round(-400 * window.sf); duration: 25000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: Math.round(-400 * window.sf); to: Math.round(400 * window.sf); duration: 25000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: 0; to: Math.round(-350 * window.sf); duration: 12500; easing.type: Easing.OutSine }
                        NumberAnimation { from: Math.round(-350 * window.sf); to: Math.round(350 * window.sf); duration: 25000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: Math.round(350 * window.sf); to: 0; duration: 12500; easing.type: Easing.InSine }
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.centerOffset
                z: 0
                opacity: window.introAmbient * window.weatherContentOpacity

                Text {
                    id: parallaxIcon
                    anchors.centerIn: parent
                    text: {
                        if (!window.weatherData) return "";
                        if (window.weatherView === 0 && window.weatherData.current_icon) return window.weatherData.current_icon;
                        if (window.weatherData.forecast && window.weatherData.forecast[window.weatherView]) return window.weatherData.forecast[window.weatherView].icon;
                        return "";
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.round(560 * window.sf)
                    color: window.activeWeatherHex
                    Behavior on color { ColorAnimation { duration: 1500 } }

                    opacity: 0.015
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { from: 0.015; to: 0.022; duration: 5625; easing.type: Easing.OutSine }
                        NumberAnimation { from: 0.022; to: 0.01; duration: 11250; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.01; to: 0.015; duration: 5625; easing.type: Easing.InSine }
                    }

                    transform: [
                        Translate {
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                running: window.visible
                                NumberAnimation { to: Math.round(-20 * window.sf); duration: 6000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                            }
                        },
                        Translate { x: window.weatherContentOffset * 2 }
                    ]
                }
            }

            Item {
                id: centralHub
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.centerOffset
                width: Math.round(1 * window.sf)
                height: Math.round(1 * window.sf)
                z: 5

                opacity: introClock
                scale: 0.85 + (0.15 * introClock)

                transform: [
                    Translate { y: Math.round(25 * window.sf) * (1.0 - introClock) },
                    Translate {
                        SequentialAnimation on y {
                            loops: Animation.Infinite
                            running: window.visible
                            NumberAnimation { to: Math.round(-15 * window.sf); duration: 4000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 4000; easing.type: Easing.InOutSine }
                        }
                    },
                    Rotation {
                        axis { x: 1; y: 0; z: 0 }
                        SequentialAnimation on angle {
                            loops: Animation.Infinite; running: window.visible
                            NumberAnimation { to: 3.5; duration: 4200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -3.5; duration: 4200; easing.type: Easing.InOutSine }
                        }
                    },
                    Rotation {
                        axis { x: 0; y: 1; z: 0 }
                        SequentialAnimation on angle {
                            loops: Animation.Infinite; running: window.visible
                            NumberAnimation { to: 2.5; duration: 5100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -2.5; duration: 5100; easing.type: Easing.InOutSine }
                        }
                    },
                    Rotation {
                        axis { x: 0; y: 0; z: 1 }
                        SequentialAnimation on angle {
                            loops: Animation.Infinite; running: window.visible
                            NumberAnimation { to: 1.5; duration: 5800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -1.5; duration: 5800; easing.type: Easing.InOutSine }
                        }
                    }
                ]

                Canvas {
                    id: orbitCanvas
                    z: -10
                    x: Math.round(-380 * window.sf)
                    y: Math.round(-190 * window.sf)
                    width: Math.round(760 * window.sf)
                    height: Math.round(380 * window.sf)
                    opacity: 0.35

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: window.visible
                        NumberAnimation { to: 1.035; duration: 3500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 3500; easing.type: Easing.InOutSine }
                    }

                    onWidthChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.beginPath();
                        var currentRx = Math.round(290 * window.sf);
                        var currentRy = Math.round(130 * window.sf);
                        for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                            var xx = width / 2 + Math.cos(i) * currentRx;
                            var yy = height / 2 + Math.sin(i) * currentRy;
                            if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                        }
                        ctx.strokeStyle = Qt.alpha(window.textAccent, 0.45);
                        ctx.lineWidth = Math.max(1, Math.round(2 * window.sf));
                        ctx.lineCap = "round";
                        ctx.setLineDash([Math.round(4 * window.sf), Math.round(12 * window.sf)]);
                        ctx.stroke();
                    }
                    Behavior on opacity { NumberAnimation { duration: 1500 } }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    z: 0
                    scale: 0.95 + (0.05 * window.secondPulse)

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Math.round(2 * window.sf)
                        Text {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: Math.round(84 * window.sf)
                            color: window.text
                            style: Text.Outline
                            styleColor: Qt.alpha(window.crust, 0.4)
                        }
                        Text {
                            text: Qt.formatTime(window.currentTime, ":ss")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(32 * window.sf)
                            color: window.textAccent
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: Math.round(15 * window.sf)
                            opacity: window.secondPulse > 1.02 ? 1.0 : 0.6
                            style: Text.Outline
                            styleColor: Qt.alpha(window.crust, 0.4)
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(window.currentTime, "dddd, MMMM dd")
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: Math.round(16 * window.sf)
                        color: window.subtext0
                        opacity: 0.9
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: window.weatherContentOpacity
                    scale: window.transitionScale
                    transform: Translate { x: window.weatherContentOffset * 1.5 }

                    Repeater {
                        id: hourRepeater
                        model: window.weatherData && window.weatherData.forecast[window.weatherView] && window.weatherData.forecast[window.weatherView].hourly ? window.weatherData.forecast[window.weatherView].hourly.slice(0, 8) : []

                        delegate: Item {
                            property int mCount: hourRepeater.count
                            property bool isToday: window.weatherView === 0
                            property bool isHighlighted: isToday && index === window.activeHourIndex

                            property real rx: Math.round(290 * window.sf) * orbitCanvas.scale
                            property real ry: Math.round(130 * window.sf) * orbitCanvas.scale

                            property int relIdx: isToday ? (index - window.activeHourIndex) : index
                            property real targetAngleDeg: isToday ? (65 + (relIdx * 30)) : (index * (360 / Math.max(1, mCount)))
                            property real orbitOffset: isToday ? 0 : window.globalOrbitOffset
                            property real osc: isToday ? (Math.sin(window.globalOscPhase + index) * 5) : 0
                            property real rad: (targetAngleDeg + orbitOffset + osc + window.transitionSpin) * (Math.PI / 180)

                            x: Math.cos(rad) * rx - width / 2
                            y: Math.sin(rad) * ry - height / 2
                            z: Math.sin(rad) * Math.round(100 * window.sf)

                            scale: isHighlighted ? 1.35 : (isToday ? (0.95 + 0.20 * Math.sin(rad)) : (0.90 + 0.25 * Math.sin(rad)))
                            opacity: isHighlighted ? 1.0 : (isToday ? (0.7 + 0.3 * ((Math.sin(rad) + 1) / 2)) : (0.65 + 0.35 * ((Math.sin(rad) + 1) / 2)))

                            width: Math.round(56 * window.sf)
                            height: Math.round(95 * window.sf)

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(28 * window.sf)
                                color: isHighlighted ? window.textAccent : (hrMa.containsMouse ? Qt.tint(window.surface1, Qt.alpha(window.textAccent, 0.15)) : Qt.tint(window.surface0, Qt.alpha(window.textAccent, 0.04)))
                                border.color: isHighlighted ? Qt.lighter(window.textAccent, 1.1) : (hrMa.containsMouse ? Qt.alpha(window.textAccent, 0.45) : Qt.alpha(window.surface1, 0.6))
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(4 * window.sf)

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData ? modelData.time : ""
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Bold
                                        font.pixelSize: Math.round(12 * window.sf)
                                        color: isHighlighted ? window.base : (hrMa.containsMouse ? window.text : window.overlay1)
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData ? (modelData.icon || (window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : "")) : ""
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: Math.round(18 * window.sf)
                                        color: isHighlighted ? window.base : (modelData ? (modelData.hex || window.text) : window.text)

                                        transform: Translate { y: hrMa.containsMouse ? Math.round(-3 * window.sf) : 0 }
                                        Behavior on transform { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData ? (modelData.temp + "°") : ""
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: Math.round(14 * window.sf)
                                        color: isHighlighted ? window.base : window.text
                                    }
                                }
                            }
                            MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            Rectangle {
                id: calendarRect
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Math.round(40 * window.sf)
                width: Math.round(320 * window.sf)
                height: Math.round(420 * window.sf)
                color: Qt.alpha(window.surface0, 0.2)
                radius: ThemeBackend.borderRadius
                border.color: Qt.alpha(window.surface1, 0.4)
                border.width: 1
                z: 10

                opacity: introCalendar
                transform: Translate { x: Math.round(-40 * window.sf) * (1.0 - introCalendar) }

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(25 * window.sf)
                    spacing: Math.round(15 * window.sf)

                    RowLayout {
                        Layout.fillWidth: true

                        IconButton {
                            Layout.preferredWidth: Math.round(32 * window.sf)
                            Layout.preferredHeight: Math.round(32 * window.sf)
                            size: Math.round(32 * window.sf)
                            cornerRadius: Math.round(8 * window.sf)
                            buttonIcon: "󰃭"
                            iconFontSize: Math.round(16 * window.sf)
                            accentColor: window.surface0
                            textColor: window.text
                            opacity: window.targetMonthOffset !== 0 ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            onClicked: { if (window.targetMonthOffset !== 0) window.setMonthOffset(0) }
                        }

                        IconButton {
                            Layout.preferredWidth: Math.round(32 * window.sf)
                            Layout.preferredHeight: Math.round(32 * window.sf)
                            size: Math.round(32 * window.sf)
                            cornerRadius: Math.round(8 * window.sf)
                            buttonIcon: ""
                            iconFontSize: Math.round(16 * window.sf)
                            accentColor: window.surface0
                            textColor: window.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: Math.round(16 * window.sf)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: Math.round(8 * window.sf)
                            color: window.text
                            horizontalAlignment: Text.AlignHCenter

                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }
                        }

                        IconButton {
                            Layout.preferredWidth: Math.round(32 * window.sf)
                            Layout.preferredHeight: Math.round(32 * window.sf)
                            size: Math.round(32 * window.sf)
                            cornerRadius: Math.round(8 * window.sf)
                            buttonIcon: ""
                            iconFontSize: Math.round(16 * window.sf)
                            accentColor: window.surface0
                            textColor: window.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset + 1)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: [I18n.t("calendar.days.mo"), I18n.t("calendar.days.tu"), I18n.t("calendar.days.we"), I18n.t("calendar.days.th"), I18n.t("calendar.days.fr"), I18n.t("calendar.days.sa"), I18n.t("calendar.days.su")]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: Math.round(14 * window.sf)
                                color: window.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: Math.round(4 * window.sf)
                        columnSpacing: Math.round(4 * window.sf)

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            ClickButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                enabled: false
                                buttonText: dayNum
                                textFontSize: Math.round(13 * window.sf)
                                cornerRadius: Math.round(8 * window.sf)
                                horizontalPadding: 0
                                accentColor: isToday ? window.textAccent : "transparent"
                                textColor: isToday ? window.base : (isCurrentMonth ? window.text : window.surface0)
                            }
                        }
                    }
                }
            }

            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Math.round(40 * window.sf)
                width: Math.round(320 * window.sf)
                height: Math.round(420 * window.sf)
                z: 10

                opacity: introWeather
                transform: Translate { x: Math.round(40 * window.sf) * (1.0 - introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Math.round(16 * window.sf)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: Math.round(20 * window.sf)

                        IconButton {
                            Layout.preferredWidth: Math.round(32 * window.sf)
                            Layout.preferredHeight: Math.round(32 * window.sf)
                            size: Math.round(32 * window.sf)
                            cornerRadius: Math.round(8 * window.sf)
                            buttonIcon: ""
                            iconFontSize: Math.round(12 * window.sf)
                            accentColor: window.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : window.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].day_full.toUpperCase() : I18n.t("calendar.loading")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: Math.round(16 * window.sf)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: Math.round(8 * window.sf)
                            color: window.text
                        }

                        IconButton {
                            Layout.preferredWidth: Math.round(32 * window.sf)
                            Layout.preferredHeight: Math.round(32 * window.sf)
                            size: Math.round(32 * window.sf)
                            cornerRadius: Math.round(8 * window.sf)
                            buttonIcon: ""
                            iconFontSize: Math.round(12 * window.sf)
                            accentColor: window.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : window.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView + 1)
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: Math.round(window.displayedTemp) + "°C"
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: Math.round(80 * window.sf)
                            color: window.tempGlowColor
                            style: Text.Outline
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(window.crust, 0.4)

                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on styleColor { ColorAnimation { duration: 300 } }
                        }

                        Text {
                            Layout.alignment: Qt.AlignRight
                            Layout.maximumWidth: Math.round(320 * window.sf)
                            horizontalAlignment: Text.AlignRight
                            text: (typeof Location !== "undefined" && Location.city && Location.city !== "") ? Location.city : (window.weatherData && window.weatherData.city ? window.weatherData.city : "")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(15 * window.sf)
                            color: window.text
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        Text {
                            Layout.alignment: Qt.AlignRight
                            Layout.maximumWidth: Math.round(320 * window.sf)
                            Layout.topMargin: Math.round(6 * window.sf)
                            horizontalAlignment: Text.AlignRight
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].desc : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: Math.round(14 * window.sf)
                            wrapMode: Text.WordWrap
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: 1000 } }

                            opacity: window.weatherContentOpacity
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                        Layout.rightMargin: Math.round(-15 * window.sf)
                        Layout.bottomMargin: Math.round(-15 * window.sf)
                        columns: 2
                        rowSpacing: Math.round(8 * window.sf)
                        columnSpacing: Math.round(8 * window.sf)

                        Repeater {
                            model: 4

                            ClickButton {
                                Layout.preferredHeight: Math.round(44 * window.sf)
                                Layout.preferredWidth: Math.round(100 * window.sf)
                                cornerRadius: Math.round(8 * window.sf)

                                property var forecast: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? window.weatherData.forecast[window.targetWeatherView] : null

                                buttonIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                buttonText: forecast ? (
                                    index === 0 ? forecast.wind + "m/s" :
                                    index === 1 ? forecast.humidity + "%" :
                                    index === 2 ? forecast.pop + "%" :
                                    forecast.feels_like + "°"
                                ) : ""
                                subText: index === 0 ? I18n.t("calendar.weather.wind") : index === 1 ? I18n.t("calendar.weather.humid") : index === 2 ? I18n.t("calendar.weather.rain") : I18n.t("calendar.weather.feels")

                                iconFontSize: Math.round(15 * window.sf)
                                textFontSize: Math.round(12 * window.sf)

                                accentColor: window.surface0
                                textColor: isHoveredOrHighlighted ? window.textAccent : window.overlay0
                            }
                        }
                    }
                }
            }
        }
    }
}
