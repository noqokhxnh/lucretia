import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../reusables"
import "../"

PanelWindow {
    id: trayMenuWindow

    screen: TrayMenuController.screen

    WlrLayershell.namespace: "traymenu"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {
        item: (trayMenuWindow.isVisible || menuContainer.animProgress > 0.001) ? menuContainer : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: TrayMenuController.isVisible
    property string activeItemId: TrayMenuController.activeItemId
    property real targetX: TrayMenuController.targetX
    property real targetY: TrayMenuController.targetY
    property bool alignRight: TrayMenuController.alignRight
    property bool alignBottom: TrayMenuController.alignBottom
    property bool isSideBar: TrayMenuController.isSideBar

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            TrayMenuController.hide();
            trayMenuWindow.configRevision++;
        }
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }

    onBarStyleChanged: {
        TrayMenuController.hide();
    }

    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill"

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }

    property real cornerRadius: {
        let dummy = configRevision;
        let raw = (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null)
            ? ThemeBackend.borderRadius
            : s(12);
        let threshold = s(32);
        let maxLimit = s(44);
        if (raw <= threshold) {
            return Math.max(0, raw);
        }
        let excess = raw - threshold;
        let range = maxLimit - threshold;
        return threshold + range * (1.0 - Math.exp(-excess / range));
    }

    property real menuMargin: isSolid ? 0 : s(20)

    visible: isVisible || menuContainer.animProgress > 0.001

    function closeMenu() {
        TrayMenuController.hide();
    }

    property var activeItem: {
        if (!activeItemId && activeItemId !== 0) return null;
        let list = SystemTray.items;
        if (!list) return null;
        let arr = list.values || list;
        if (arr && arr.length !== undefined) {
            for (let i = 0; i < arr.length; i++) {
                let it = arr[i];
                if (it && (String(it.id) === String(activeItemId) || String(i) === String(activeItemId))) {
                    return it;
                }
            }
        }
        if (list.count !== undefined && typeof list.get === "function") {
            for (let j = 0; j < list.count; j++) {
                let it = list.get(j);
                if (it && (String(it.id) === String(activeItemId) || String(j) === String(activeItemId))) {
                    return it;
                }
            }
        }
        let num = parseInt(activeItemId);
        if (!isNaN(num)) {
            if (list.values && list.values[num]) return list.values[num];
            if (list[num]) return list[num];
        }
        return null;
    }

    onActiveItemChanged: {
        if (!activeItem && isVisible) {
            TrayMenuController.hide();
        }
    }

    onIsVisibleChanged: {
        if (isVisible && !activeItem) {
            TrayMenuController.hide();
        }
    }

    property var activeMenuHandle: activeItem ? activeItem.menu : null

    QsMenuOpener {
        id: menuOpener
        menu: trayMenuWindow.activeMenuHandle
    }

    property real menuWidth: s(200)
    property real itemHeight: s(32)
    property int menuCount: {
        if (!menuOpener.children) return 0;
        if (menuOpener.children.values) return menuOpener.children.values.length;
        if (menuOpener.children.count !== undefined) return menuOpener.children.count;
        if (menuOpener.children.length !== undefined) return menuOpener.children.length;
        return 0;
    }

    property real rawHeight: (menuCount * itemHeight) + s(16)
    property real targetMenuHeight: Math.max(s(40), rawHeight)
    property real menuHeight: targetMenuHeight

    Behavior on menuHeight {
        enabled: trayMenuWindow.isVisible && menuContainer.animProgress > 0.95
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    property real clampedX: {
        let w = menuWidth;
        let x = 0;
        if (isSideBar) {
            if (alignRight) {
                let barEdge = (targetX > trayMenuWindow.width / 2) ? targetX : (trayMenuWindow.width - barHeight);
                x = isSolid ? (trayMenuWindow.width - barHeight - w) : (barEdge - w - menuMargin);
            } else {
                let barEdge = (targetX > 0 && targetX < trayMenuWindow.width / 2) ? targetX : barHeight;
                x = isSolid ? barHeight : (barEdge + menuMargin);
            }
        } else {
            x = targetX - (w / 2);
        }
        let edgeBound = (isSolid && !isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(trayMenuWindow.width - w - edgeBound, x));
    }

    property real clampedY: {
        let h = menuHeight;
        let y = 0;
        if (isSideBar) {
            y = targetY - (h / 2);
        } else {
            if (alignBottom) {
                let barEdge = (targetY > trayMenuWindow.height / 2) ? targetY : (trayMenuWindow.height - barHeight);
                y = isSolid ? (trayMenuWindow.height - barHeight - h) : (barEdge - h - menuMargin);
            } else {
                let barEdge = (targetY > 0 && targetY < trayMenuWindow.height / 2) ? targetY : barHeight;
                y = isSolid ? barHeight : (barEdge + menuMargin);
            }
        }
        let edgeBound = (isSolid && isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(trayMenuWindow.height - h - edgeBound, y));
    }

    Item {
        id: menuContainer

        property real animProgress: trayMenuWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: trayMenuWindow.isVisible ? 280 : 220
                easing.type: Easing.OutCubic
            }
        }

        property real dynamicCornerRadius: trayMenuWindow.isSolid ? Math.max(0, Math.min(trayMenuWindow.cornerRadius, (trayMenuWindow.isSideBar ? width : height))) : 0

        x: {
            if (trayMenuWindow.isSolid) {
                if (trayMenuWindow.isSideBar) {
                    if (trayMenuWindow.alignRight) {
                        return trayMenuWindow.clampedX + (trayMenuWindow.menuWidth - width);
                    }
                    return trayMenuWindow.clampedX;
                }
                return trayMenuWindow.clampedX;
            }
            let slideOffset = trayMenuWindow.s(16) * (1.0 - animProgress);
            if (trayMenuWindow.isSideBar) {
                return trayMenuWindow.alignRight ? (trayMenuWindow.clampedX + slideOffset) : (trayMenuWindow.clampedX - slideOffset);
            }
            return trayMenuWindow.clampedX;
        }

        y: {
            if (trayMenuWindow.isSolid) {
                if (!trayMenuWindow.isSideBar) {
                    if (trayMenuWindow.alignBottom) {
                        return trayMenuWindow.clampedY + (trayMenuWindow.menuHeight - height);
                    }
                    return trayMenuWindow.clampedY;
                }
                return trayMenuWindow.clampedY;
            }
            let slideOffset = trayMenuWindow.s(16) * (1.0 - animProgress);
            if (!trayMenuWindow.isSideBar) {
                return trayMenuWindow.alignBottom ? (trayMenuWindow.clampedY + slideOffset) : (trayMenuWindow.clampedY - slideOffset);
            }
            return trayMenuWindow.clampedY;
        }

        width: {
            if (trayMenuWindow.isSolid && trayMenuWindow.isSideBar) {
                return trayMenuWindow.menuWidth * animProgress;
            }
            return trayMenuWindow.menuWidth;
        }

        height: {
            if (trayMenuWindow.isSolid && !trayMenuWindow.isSideBar) {
                return trayMenuWindow.menuHeight * animProgress;
            }
            return trayMenuWindow.menuHeight;
        }

        opacity: animProgress
        scale: !trayMenuWindow.isSolid ? (0.92 + (0.08 * animProgress)) : 1.0

        transformOrigin: {
            if (trayMenuWindow.isSideBar) {
                return trayMenuWindow.alignRight ? Item.Right : Item.Left;
            }
            return trayMenuWindow.alignBottom ? Item.Bottom : Item.Top;
        }

        Shape {
            visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
            x: -menuContainer.dynamicCornerRadius
            y: 0
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
            x: parent.width
            y: 0
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: menuContainer.dynamicCornerRadius
                startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                PathArc {
                    x: menuContainer.dynamicCornerRadius
                    y: 0
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
            x: -menuContainer.dynamicCornerRadius
            y: parent.height - menuContainer.dynamicCornerRadius
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: menuContainer.dynamicCornerRadius
                PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: menuContainer.dynamicCornerRadius
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
            x: parent.width
            y: parent.height - menuContainer.dynamicCornerRadius
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: menuContainer.dynamicCornerRadius
                startY: menuContainer.dynamicCornerRadius
                PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: menuContainer.dynamicCornerRadius
                    y: menuContainer.dynamicCornerRadius
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
            x: 0
            y: -menuContainer.dynamicCornerRadius
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
            x: 0
            y: parent.height
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: menuContainer.dynamicCornerRadius
                PathLine { x: 0; y: 0 }
                PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: menuContainer.dynamicCornerRadius
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
            x: parent.width - menuContainer.dynamicCornerRadius
            y: -menuContainer.dynamicCornerRadius
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: menuContainer.dynamicCornerRadius
                startY: 0
                PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                PathArc {
                    x: menuContainer.dynamicCornerRadius
                    y: 0
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
            x: parent.width - menuContainer.dynamicCornerRadius
            y: parent.height
            width: menuContainer.dynamicCornerRadius
            height: menuContainer.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: menuContainer.dynamicCornerRadius
                startY: menuContainer.dynamicCornerRadius
                PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: menuContainer.dynamicCornerRadius
                    y: menuContainer.dynamicCornerRadius
                    radiusX: menuContainer.dynamicCornerRadius
                    radiusY: menuContainer.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Rectangle {
            id: menuBox
            anchors.fill: parent
            color: ThemeBackend.base
            radius: trayMenuWindow.cornerRadius
            border.width: 0
            border.color: "transparent"
            clip: true

            Rectangle {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width - menuContainer.dynamicCornerRadius
                y: 0
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width - menuContainer.dynamicCornerRadius
                y: parent.height - menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width - menuContainer.dynamicCornerRadius
                y: 0
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width - menuContainer.dynamicCornerRadius
                y: parent.height - menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                color: ThemeBackend.base
            }

            HoverHandler {
                id: menuHoverHandler
                onHoveredChanged: {
                    TrayMenuController.menuHovered = hovered;
                    if (hovered) {
                        TrayMenuController.cancelHide();
                    } else {
                        TrayMenuController.requestHide();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
            }

            ListView {
                id: menuList
                anchors.fill: parent
                anchors.margins: trayMenuWindow.s(8)
                model: menuOpener.children
                clip: true
                spacing: 0
                cacheBuffer: 3000
                interactive: contentHeight > height

                delegate: Item {
                    width: menuList.width
                    height: trayMenuWindow.itemHeight

                    property bool isSep: modelData ? modelData.isSeparator : false

                    Rectangle {
                        anchors.fill: parent
                        visible: !parent.isSep
                        radius: trayMenuWindow.s(4)
                        color: itemMouse.containsMouse ? ThemeBackend.surface0 : "transparent"
                        opacity: (modelData && modelData.enabled) ? 1.0 : 0.4

                        Image {
                            id: itemIcon
                            anchors.left: parent.left
                            anchors.leftMargin: trayMenuWindow.s(8)
                            anchors.verticalCenter: parent.verticalCenter
                            width: (modelData && modelData.icon && modelData.icon !== "") ? trayMenuWindow.s(16) : 0
                            height: trayMenuWindow.s(16)
                            source: (modelData && modelData.icon) ? modelData.icon : ""
                            sourceSize: Qt.size(trayMenuWindow.s(16), trayMenuWindow.s(16))
                            visible: width > 0
                        }

                        Text {
                            anchors.left: itemIcon.visible ? itemIcon.right : parent.left
                            anchors.leftMargin: trayMenuWindow.s(8)
                            anchors.right: parent.right
                            anchors.rightMargin: trayMenuWindow.s(8)
                            anchors.verticalCenter: parent.verticalCenter
                            text: (modelData && modelData.text) ? modelData.text : ""
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: trayMenuWindow.s(13)
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: modelData ? modelData.enabled : false
                            cursorShape: Qt.PointingHandCursor
                            onEntered: TrayMenuController.cancelHide()
                            onClicked: {
                                if (modelData && !modelData.hasChildren) {
                                    modelData.triggered();
                                    TrayMenuController.hide();
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - trayMenuWindow.s(16)
                        height: 1
                        color: ThemeBackend.surface0
                        anchors.centerIn: parent
                        visible: parent.isSep
                    }
                }
            }
        }
    }
}
