import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"
import "../../singletons"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 48
    property real minHeight: 48
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.5
    property real maxAspect: 2.0

    property string imagePath: (typeof model !== "undefined" && model && model.wImagePath) ? model.wImagePath : (parent && parent.wImagePath ? parent.wImagePath : "")
    property string wVariant: (typeof model !== "undefined" && model && model.wVariant) ? model.wVariant : (parent && parent.wVariant ? parent.wVariant : "icon")

    // Parse App Info
    property string targetAppId: ""
    property string targetAppName: ""
    property string targetAppIcon: ""

    function resolveAppInfo() {
        let raw = root.imagePath ? root.imagePath.trim() : "";
        if (!raw) {
            targetAppId = "";
            targetAppName = "";
            targetAppIcon = "";
            return;
        }

        let parsedId = raw;
        if (raw.startsWith("{")) {
            try {
                let obj = JSON.parse(raw);
                if (obj.id) parsedId = obj.id;
                if (obj.name) targetAppName = obj.name;
                if (obj.icon) targetAppIcon = obj.icon;
            } catch(e) {}
        } else if (raw.startsWith("[")) {
            try {
                let arr = JSON.parse(raw);
                if (arr.length > 0) parsedId = arr[0];
            } catch(e) {}
        }

        targetAppId = parsedId;

        let entry = (typeof DesktopEntries !== "undefined" && DesktopEntries.byId) ? DesktopEntries.byId(parsedId) : null;
        if (!entry && typeof DesktopEntries !== "undefined" && DesktopEntries.applications) {
            let entries = DesktopEntries.applications.values;
            for (let i = 0; i < entries.length; i++) {
                let e = entries[i];
                if (e.id === parsedId || e.id.replace(".desktop", "") === parsedId || (e.name && e.name.toLowerCase() === parsedId.toLowerCase())) {
                    entry = e;
                    break;
                }
            }
        }

        if (entry) {
            targetAppName = entry.name || targetAppName || parsedId.replace(".desktop", "");
            targetAppIcon = entry.icon || targetAppIcon || "";
        } else if (!targetAppName) {
            targetAppName = parsedId.replace(".desktop", "");
        }
    }

    onImagePathChanged: resolveAppInfo()
    Component.onCompleted: resolveAppInfo()

    function launchApp() {
        if (!root.targetAppId) return;

        let entry = (typeof DesktopEntries !== "undefined" && DesktopEntries.byId) ? DesktopEntries.byId(root.targetAppId) : null;
        if (entry) {
            try {
                entry.execute();
            } catch(e) {
                Quickshell.execDetached(["gtk-launch", root.targetAppId]);
            }
        } else {
            Quickshell.execDetached(["gtk-launch", root.targetAppId]);
        }

        if (Caching.qsDir) {
            Quickshell.execDetached(["python3", Caching.qsDir + "/bar/sidemodules/pill/app_rank.py", "--log-launch", "--name", root.targetAppName || root.targetAppId]);
        }
    }

    property real hoverScale: mouseArea.containsMouse ? 1.06 : 1.0
    property real pressScale: mouseArea.pressed ? 0.94 : 1.0

    // Main Container
    Item {
        id: container
        anchors.fill: parent
        scale: root.hoverScale * root.pressScale
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

        // Background for Card or Badge variant
        Rectangle {
            anchors.fill: parent
            visible: root.wVariant === "card" || root.wVariant === "badge"
            color: root.wVariant === "badge" ? ThemeBackend.surface0 : Qt.rgba(ThemeBackend.surface0.r, ThemeBackend.surface0.g, ThemeBackend.surface0.b, 0.6)
            radius: root.wVariant === "badge" ? Math.min(width, height) * 0.28 : ThemeBackend.borderRadius
            border.color: mouseArea.containsMouse ? ThemeBackend.mauve : ThemeBackend.surface1
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        // Layout Content
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.wVariant === "card" ? Scaler.s(10) : (root.wVariant === "badge" ? Scaler.s(8) : Scaler.s(4))
            spacing: Scaler.s(4)

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                AppIcon {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * (root.wVariant === "icon" ? 0.95 : 0.85)
                    height: width
                    appId: root.targetAppId
                    appName: root.targetAppName
                    iconName: root.targetAppIcon
                    fallbackColor: mouseArea.containsMouse ? ThemeBackend.mauve : ThemeBackend.subtext0
                }
            }

            // App Label (Shown in Card variant)
            Text {
                visible: root.wVariant === "card" && root.targetAppName !== "" && root.height >= 70
                Layout.fillWidth: true
                text: root.targetAppName
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(10, Math.min(13, root.height * 0.14))
                font.bold: true
                color: ThemeBackend.text
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchApp()
        }
    }
}
