import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Rectangle {
    id: visWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetX: 0
    property bool showLayout: !barWindow || barWindow.isStartupReady
    property int barCount: 16
    property bool isVisVisible: moduleActive && showLayout
    property bool isSubscribed: false
    readonly property bool shouldSubscribe: isVisVisible && MprisController.isPlaying

    onShouldSubscribeChanged: updateSubscription()

    function updateSubscription() {
        if (shouldSubscribe && !isSubscribed) {
            isSubscribed = true;
            Cava.registerConsumer();
        } else if (!shouldSubscribe && isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    Connections {
        target: barWindow ? barWindow : null
        function onIsStartupReadyChanged() {
            if (barWindow && barWindow.isStartupReady) {
                visWidgetRoot.showLayout = true;
            }
        }
    }

    Component.onCompleted: {
        if (!barWindow || barWindow.isStartupReady) {
            visWidgetRoot.showLayout = true;
        }
        updateSubscription();
    }

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            Cava.unregisterConsumer();
        }
    }

    property var barLevels: {
        let source = Cava.barLevels;
        let count = barCount;
        let out = [];

        if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return out;
        }

        for (let i = 0; i < count; i++) {
            let norm = count > 1 ? (i / (count - 1)) : 0;
            let srcIdx = Math.min(source.length - 1, Math.floor(Math.pow(norm, 1.4) * (source.length - 1)));
            let val = source[srcIdx] || 0.0;

            if (val < 0.04) {
                val = 0.0;
            } else {
                val = Math.pow((val - 0.04) / 0.96, 1.25);
            }
            out.push(val);
        }
        return out;
    }

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    y: barWindow ? barWindow.baseOffsetY : 0
    height: barWindow ? barWindow.barHeight : 30
    radius: ThemeBackend.borderRadius
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    border.width: (isGrouped || isSolid) ? 0 : 1
    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    clip: true

    property real targetWidth: (moduleActive && innerLayout.implicitWidth > 0) ? (innerLayout.implicitWidth + (barWindow ? barWindow.s(24) : 24)) : 0
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    opacity: (moduleActive && showLayout) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: visWidgetRoot.moduleActive && barWindow && !visWidgetRoot.showLayout
        interval: 100
        onTriggered: {
            if (barWindow && barWindow.isStartupReady) {
                visWidgetRoot.showLayout = true;
            }
        }
    }

    Row {
        id: innerLayout
        anchors.centerIn: parent
        spacing: barWindow ? barWindow.s(4) : 4

        Repeater {
            model: visWidgetRoot.barCount
            delegate: Rectangle {
                width: barWindow ? barWindow.s(5) : 5
                property real level: (visWidgetRoot.barLevels && index < visWidgetRoot.barLevels.length) ? visWidgetRoot.barLevels[index] : 0.0
                property real minH: barWindow ? barWindow.s(4) : 4
                property real maxH: visWidgetRoot.height * 0.65
                height: Math.max(minH, level * maxH)
                radius: width * 0.5
                color: ThemeBackend.mauve
                opacity: 0.45 + (level * 0.55)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: 55
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 55 }
                }
            }
        }
    }
}
