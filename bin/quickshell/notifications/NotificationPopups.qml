import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../WindowRegistry.js" as Registry
import "../components" as Components
PanelWindow {
    id: popupWindow

    Caching { id: paths }

    property var popupModel
    property real uiScale: 1.0

    // Local map — live QObjects are stored here directly via storeNotif()
    // called from Main.qml's onNotification handler. Never crosses window
    // boundaries via a binding, which is what was breaking sourceNotif.
    property var _notifMap: ({})

    function storeNotif(uid, notif) {
        _notifMap[uid] = notif;
    }

    function getNotif(uid) {
        return _notifMap[uid] || null;
    }

    function removeNotif(uid) {
        delete _notifMap[uid];
        popupWindow.removeRequested(uid);
    }

    signal removeRequested(int uid)

    property var layoutConfig: Registry.getPopupLayout(Screen.width, popupWindow.uiScale)

    WlrLayershell.namespace: "qs-popups"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        right: true
    }

    margins {
        top: popupWindow.layoutConfig.marginTop
        right: popupWindow.layoutConfig.marginRight
    }

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    width: popupWindow.layoutConfig.w
    height: Math.min(popupList.contentHeight, Screen.height * 0.8)

    property bool dndEnabled: false

    Process {
        id: dndPoller
        command: ["bash", "-c", "cat '" + paths.getCacheDir("dnd") + "/state' 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: popupWindow.dndEnabled = (this.text.trim() === "1")
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: dndPoller.running = true
    }

    Item {
        id: contentWrapper
        anchors.fill: parent

        opacity: popupWindow.dndEnabled ? 0.0 : 1.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 300 } }

        MatugenColors { id: _theme }

        ListView {
            id: popupList
            anchors.fill: parent
            model: popupWindow.popupModel
            spacing: popupWindow.layoutConfig.spacing
            interactive: false
            clip: false

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutQuad }
                    NumberAnimation { property: "x"; from: popupWindow.width * 0.2; to: 0; duration: 300; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                    NumberAnimation { property: "x"; to: popupWindow.width * 0.2; duration: 250; easing.type: Easing.InCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 450; easing.type: Easing.OutQuint }
            }

            delegate: Item {
                id: delegateRoot
                width: ListView.view.width
                height: popupCard.height

                property string fullSummary: model.summary || ""
                property string fullBody: model.body || ""
                property int popupUid: model.uid
                property real progress: 1.0

                // Resolved fresh each time via function — no binding across windows
                property var sourceNotif: popupWindow.getNotif(model.uid)

                // actionArray is built from the JSON we constructed ourselves in Main.qml
                // so "id" key is correct here — it's our own data, not the QObject
                property var actionArray: {
                    try {
                        let parsed = model.actionsJson ? JSON.parse(model.actionsJson) : []
                        return parsed
                    } catch (e) {
                        return []
                    }
                }

                property int effectiveTimeout: {
                    var n = popupWindow.getNotif(model.uid);
                    if (!n || n.timeout === undefined) return 5000;
                    if (n.timeout === 0) return 0;
                    if (n.timeout > 0) return n.timeout;
                    return 5000;
                }

                property color dynamicAccentColor: {
                    let app = (model.appName || "").toLowerCase();
                    let summary = (model.summary || "").toLowerCase();
                    let body = (model.body || "").toLowerCase();
                    if (app.includes("error") || app.includes("critical") || summary.includes("error") || body.includes("error")) return _theme.red;
                    return _theme.mauve; // Consistent system accent color!
                }

                property string appIconSymbol: {
                    let app = (model.appName || "").toLowerCase();
                    if (app.includes("spotify") || app.includes("music")) return "󰓇";
                    if (app.includes("discord") || app.includes("vesktop")) return "󰙯";
                    if (app.includes("chrome") || app.includes("firefox") || app.includes("browser") || app.includes("web")) return "󰊯";
                    if (app.includes("telegram")) return "󰔗";
                    if (app.includes("steam")) return "󰓓";
                    if (app.includes("terminal") || app.includes("kitty") || app.includes("alacritty")) return "󰞷";
                    if (app.includes("screenshot")) return "󰄀";
                    if (app.includes("system") || app.includes("settings")) return "󰒓";
                    if (app.includes("battery")) return "󰁹";
                    if (app.includes("volume") || app.includes("audio")) return "󰕾";
                    if (app.includes("wifi") || app.includes("network")) return "󰖩";
                    if (app.includes("update") || app.includes("package")) return "󰚰";
                    if (app.includes("mail")) return "󰇰";
                    if (app.includes("calendar")) return "󰃭";
                    if (app.includes("file") || app.includes("nautilus") || app.includes("thunar")) return "󰉋";
                    return "󰵚";
                }

                Connections {
                    target: delegateRoot.sourceNotif || null
                    function onClosed() {
                        popupWindow.removeNotif(delegateRoot.popupUid);
                    }
                }

                Timer {
                    id: progressTimer
                    interval: 32 // ~30fps for ultra-low CPU overhead
                    running: delegateRoot.effectiveTimeout > 0 && !cardMouseArea.containsMouse
                    repeat: true
                    onTriggered: {
                        delegateRoot.progress -= 32 / delegateRoot.effectiveTimeout;
                        if (delegateRoot.progress <= 0) {
                            delegateRoot.progress = 0;
                            running = false;
                            popupWindow.removeNotif(delegateRoot.popupUid);
                        }
                    }
                }

                Rectangle {
                    id: popupCard
                    width: parent.width
                    height: innerLayout.implicitHeight + (28 * popupWindow.uiScale)
                    radius: 16 * popupWindow.uiScale // Optimized, extremely clean rounded corners
                    border.color: cardMouseArea.containsMouse ? delegateRoot.dynamicAccentColor : Qt.rgba(delegateRoot.dynamicAccentColor.r, delegateRoot.dynamicAccentColor.g, delegateRoot.dynamicAccentColor.b, 0.2)
                    border.width: 1 // Clean 1px border for maximum performance
                    clip: true

                    // --- STATIC PREMIUM AURORA GLASS GRADIENT ---
                    // Combines base, mauve, and blue colors into a gorgeous static mesh representation
                    // Breathtaking aesthetic with absolute 0% CPU/GPU overhead!
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.90) }
                        GradientStop { position: 0.5; color: Qt.rgba(
                                          (_theme.base.r * 0.9) + (_theme.mauve.r * 0.1),
                                          (_theme.base.g * 0.9) + (_theme.mauve.g * 0.1),
                                          (_theme.base.b * 0.9) + (_theme.mauve.b * 0.1),
                                          0.92
                                      ) }
                        GradientStop { position: 1.0; color: Qt.rgba(
                                          (_theme.base.r * 0.85) + (_theme.blue.r * 0.15),
                                          (_theme.base.g * 0.85) + (_theme.blue.g * 0.15),
                                          (_theme.base.b * 0.85) + (_theme.blue.b * 0.15),
                                          0.94
                                      ) }
                    }

                    scale: cardMouseArea.containsMouse ? 1.015 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: 200 }
                    }

                    // Card body click — invokes "default" action
                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            var n = popupWindow.getNotif(delegateRoot.popupUid);
                            if (n && n.actions) {
                                for (var i = 0; i < n.actions.length; i++) {
                                    if (n.actions[i].identifier === "default") {
                                        n.actions[i].invoke();
                                        break;
                                    }
                                }
                            }
                            Qt.callLater(function() { popupWindow.removeNotif(delegateRoot.popupUid); });
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: popupCard.radius
                            color: "white"
                            opacity: parent.containsMouse ? 0.04 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                        }
                    }

                    // Soft glass highlight edge
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 1
                        height: 1.5
                        color: Qt.rgba(255, 255, 255, 0.15)
                        radius: popupCard.radius
                    }

                    RowLayout {
                        id: innerLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 16 * popupWindow.uiScale
                        anchors.rightMargin: 16 * popupWindow.uiScale
                        anchors.topMargin: 16 * popupWindow.uiScale
                        spacing: 14 * popupWindow.uiScale

                        // Soft Aurora App Icon Badge Container
                        Item {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * popupWindow.uiScale
                            Layout.preferredHeight: 38 * popupWindow.uiScale

                            Rectangle {
                                anchors.fill: parent
                                radius: 19 * popupWindow.uiScale // Circle badge
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.rgba(delegateRoot.dynamicAccentColor.r, delegateRoot.dynamicAccentColor.g, delegateRoot.dynamicAccentColor.b, 0.3) }
                                    GradientStop { position: 1.0; color: Qt.rgba(delegateRoot.dynamicAccentColor.r, delegateRoot.dynamicAccentColor.g, delegateRoot.dynamicAccentColor.b, 0.08) }
                                }
                                border.color: Qt.rgba(delegateRoot.dynamicAccentColor.r, delegateRoot.dynamicAccentColor.g, delegateRoot.dynamicAccentColor.b, 0.45)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: delegateRoot.appIconSymbol
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 18 * popupWindow.uiScale
                                    color: delegateRoot.dynamicAccentColor
                                }
                            }
                        }

                        // Right Text & Actions Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5 * popupWindow.uiScale

                            // Header row: App Name & Dismiss button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8 * popupWindow.uiScale

                                Text {
                                    text: model.appName || "System"
                                    font.family: "Outfit"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 12 * popupWindow.uiScale
                                    color: _theme.overlay1
                                    Layout.fillWidth: true
                                }

                                // Soft close button with rotation and scaling hover effect
                                Rectangle {
                                    id: closeBtn
                                    width: 22 * popupWindow.uiScale
                                    height: 22 * popupWindow.uiScale
                                    radius: 11 * popupWindow.uiScale
                                    color: closeMouseArea.containsMouse ? Qt.rgba(_theme.red.r, _theme.red.g, _theme.red.b, 0.2) : Qt.rgba(255, 255, 255, 0.06)
                                    border.color: closeMouseArea.containsMouse ? Qt.rgba(_theme.red.r, _theme.red.g, _theme.red.b, 0.4) : Qt.rgba(255, 255, 255, 0.1)
                                    border.width: 1
                                    z: 10

                                    scale: closeMouseArea.containsMouse ? 1.15 : 1.0
                                    rotation: closeMouseArea.containsMouse ? 90 : 0

                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: 11 * popupWindow.uiScale
                                        color: closeMouseArea.containsMouse ? _theme.red : _theme.overlay1

                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: closeMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            popupWindow.removeNotif(delegateRoot.popupUid);
                                        }
                                    }
                                }
                            }

                            // Summary Text
                            Text {
                                text: delegateRoot.fullSummary
                                Layout.fillWidth: true
                                font.family: "Outfit"
                                font.weight: Font.Bold
                                font.pixelSize: 14 * popupWindow.uiScale
                                color: _theme.text
                                wrapMode: Text.Wrap
                            }

                            // Body Text
                            Text {
                                text: delegateRoot.fullBody
                                Layout.fillWidth: true
                                visible: delegateRoot.fullBody !== ""
                                font.family: "Outfit"
                                font.weight: Font.Medium
                                font.pixelSize: 12 * popupWindow.uiScale
                                color: _theme.subtext0
                                wrapMode: Text.Wrap
                                textFormat: Text.StyledText
                            }

                            // --- INLINE ACTION BUTTONS ---
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: delegateRoot.actionArray.length > 0 ? (6 * popupWindow.uiScale) : 0
                                spacing: 8 * popupWindow.uiScale
                                visible: delegateRoot.actionArray.length > 0

                                Repeater {
                                    model: delegateRoot.actionArray
                                    delegate: Components.QsButton {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30 * popupWindow.uiScale
                                        radius: 15 * popupWindow.uiScale // Pill shaped

                                        property bool isPrimary: index === 0

                                        baseColor: isPrimary ? Qt.rgba(delegateRoot.dynamicAccentColor.r, delegateRoot.dynamicAccentColor.g, delegateRoot.dynamicAccentColor.b, 0.2) : Qt.rgba(255, 255, 255, 0.05)
                                        hoverColor: isPrimary ? Qt.rgba(delegateRoot.dynamicAccentColor.r, delegateRoot.dynamicAccentColor.g, delegateRoot.dynamicAccentColor.b, 0.35) : Qt.rgba(255, 255, 255, 0.12)
                                        borderColor: isPrimary ? delegateRoot.dynamicAccentColor : _theme.surface2

                                        text: modelData.text || "Action"
                                        textSize: 11 * popupWindow.uiScale
                                        textColor: isPrimary ? delegateRoot.dynamicAccentColor : _theme.text

                                        onClicked: {
                                            var n = popupWindow.getNotif(delegateRoot.popupUid);
                                            if (n && n.actions) {
                                                for (var i = 0; i < n.actions.length; i++) {
                                                    if (n.actions[i].identifier === modelData.id) {
                                                        n.actions[i].invoke();
                                                        break;
                                                    }
                                                }
                                            }
                                            Qt.callLater(function() { popupWindow.removeNotif(delegateRoot.popupUid); });
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Glowing neon-like progress bar at the bottom
                    Rectangle {
                        id: progressBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 3 * popupWindow.uiScale
                        color: Qt.rgba(delegateRoot.dynamicAccentColor.r, delegateRoot.dynamicAccentColor.g, delegateRoot.dynamicAccentColor.b, 0.12)
                        visible: delegateRoot.effectiveTimeout > 0
                        bottomLeftRadius: popupCard.radius
                        bottomRightRadius: popupCard.radius

                        Rectangle {
                            height: parent.height
                            width: parent.width * delegateRoot.progress
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: delegateRoot.dynamicAccentColor }
                                GradientStop { position: 1.0; color: Qt.lighter(delegateRoot.dynamicAccentColor, 1.25) }
                            }

                            Behavior on width {
                                NumberAnimation { duration: 32; easing.type: Easing.Linear }
                            }
                        }
                    }
                }
            }
        }
    }
}

