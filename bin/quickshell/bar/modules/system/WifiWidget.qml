import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Networking
import "../../../reusables"
import "../../../"

Rectangle {
    id: wifiWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isDesktop: false
    property string ethStatus: "Ethernet"
    property string wifiStatus: "Off"
    property string wifiIcon: "󰤮"
    property string wifiSsid: ""
    property bool isWifiOn: Networking.wifiEnabled
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property real targetX: 0
    property bool showLayout: false
    property alias wifiPill: wifiPill

    property var ethDevice: null
    property var wifiDevice: null

    onModuleActiveChanged: {
        if (!moduleActive) {
            chassisDetector.running = false;
        } else {
            chassisDetector.running = true;
            updateNetworkData();
        }
    }

    Item {
        visible: false
        Connections {
            target: Networking
            ignoreUnknownSignals: true
            function onWifiEnabledChanged() { updateNetworkData(); }
        }
        Repeater {
            id: netDeviceRepeater
            model: Networking.devices
            Item {
                property var device: modelData
                Component.onCompleted: {
                    if (device.type === DeviceType.Wired) {
                        wifiWidgetRoot.ethDevice = device;
                    } else if (device.type === DeviceType.Wifi) {
                        wifiWidgetRoot.wifiDevice = device;
                    }
                    wifiWidgetRoot.updateNetworkData();
                }
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onStateChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onConnectedChanged() { wifiWidgetRoot.updateNetworkData(); }
                }
                Connections {
                    target: (device && device.type === DeviceType.Wired) ? device : null
                    ignoreUnknownSignals: true
                    function onHasLinkChanged() { wifiWidgetRoot.updateNetworkData(); }
                }
            }
        }
        Repeater {
            id: wifiNetworkRepeater
            model: wifiWidgetRoot.wifiDevice ? wifiWidgetRoot.wifiDevice.networks : null
            Item {
                property var network: modelData
                Connections {
                    target: network || null
                    ignoreUnknownSignals: true
                    function onSignalStrengthChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onStateChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onConnectedChanged() { wifiWidgetRoot.updateNetworkData(); }
                }
            }
        }
    }

    function updateNetworkData() {
        let isWifiEnabled = Networking.wifiEnabled;
        wifiStatus = isWifiEnabled ? "Enabled" : "Off";

        if (ethDevice) {
            if (ethDevice.connected) {
                ethStatus = "Connected";
            } else if (ethDevice.hasLink) {
                ethStatus = "Disconnected";
            } else {
                ethStatus = "Ethernet";
            }
        } else {
            ethStatus = "Ethernet";
        }

        if (!isWifiEnabled) {
            wifiSsid = "";
            wifiIcon = "󰤮";
            return;
        }

        let connectedNet = null;
        if (wifiDevice && wifiDevice.networks) {
            for (let i = 0; i < wifiNetworkRepeater.count; i++) {
                let item = wifiNetworkRepeater.itemAt(i);
                if (item && item.network && item.network.connected) {
                    connectedNet = item.network;
                    break;
                }
            }
        }

        if (connectedNet) {
            wifiSsid = connectedNet.name || connectedNet.ssid || "";
            let sig = connectedNet.signalStrength !== undefined ? Math.round(connectedNet.signalStrength * (connectedNet.signalStrength <= 1 ? 100 : 1)) : 100;
            if (sig >= 80) wifiIcon = "󰤨";
            else if (sig >= 60) wifiIcon = "󰤥";
            else if (sig >= 40) wifiIcon = "󰤢";
            else if (sig >= 20) wifiIcon = "󰤟";
            else wifiIcon = "󰤯";
        } else {
            wifiSsid = "";
            wifiIcon = "󰤯";
        }
    }

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }
    y: barWindow.baseOffsetY
    height: barWindow.barHeight
    radius: ThemeBackend.borderRadius
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    border.width: (isGrouped || isSolid) ? 0 : 1
    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    clip: true

    property real targetWidth: (moduleActive && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + barWindow.s(10)) : 0
    width: targetWidth

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: wifiWidgetRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: wifiWidgetRoot.showLayout = true
    }

    transform: Translate {
        x: wifiWidgetRoot.showLayout ? 0 : barWindow.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow.s(30)

        ClickButton {
            id: wifiPill
            property bool initAnimTrigger: false
            property bool isActive: showEthernet ? (ethStatus === "Connected") : isWifiOn

            height: sysLayout.pillHeight
            maxWidth: barWindow.s(160)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
            horizontalPadding: barWindow.s(12)
            buttonIcon: showEthernet ? "󰈀" : wifiIcon
            iconFontSize: barWindow.s(15)
            buttonText: showEthernet ? ethStatus : ((isWifiOn ? (wifiSsid !== "" ? wifiSsid : "On") : "Off"))
            textFontSize: barWindow.s(12)
            accentColor: isActive ? ThemeBackend.blue : ThemeBackend.surface0
            textColor: isActive ? ThemeBackend.base : ThemeBackend.text

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            Timer { running: wifiWidgetRoot.moduleActive && wifiWidgetRoot.showLayout && !wifiPill.initAnimTrigger; interval: 130; onTriggered: wifiPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: wifiPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network wifi"])
        }
    }
}
