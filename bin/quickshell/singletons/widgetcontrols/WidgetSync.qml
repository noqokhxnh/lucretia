pragma Singleton
import QtQuick
import Quickshell
import "../../widgets"

Item {
    id: root

    signal geometryChanged(string monitor, string widgetId, real x, real y, real w, real h, real opacity, real rotation)
    signal positionChanged(string monitor, string widgetId, real x, real y)
    signal widgetOpacityChanged(string monitor, string widgetId, real opacity)
    signal widgetRotationChanged(string monitor, string widgetId, real rotation)
    signal variantChanged(string monitor, string widgetId, string variant)
    signal imagePathChanged(string monitor, string widgetId, string imagePath)
    signal widgetAdded(string monitor, string widgetId, string type, real x, real y, real w, real h, real opacity, string imagePath, real rotation, string variant)
    signal widgetRemoved(string monitor, string widgetId)
    signal widgetsByTypeRemoved(string monitor, string type)
    signal widgetsCleared(string monitor)
    signal presetApplied(string monitor, var widgetsList)
    signal bringToFrontRequested(string monitor, string widgetId)
    signal redactModeChanged(string monitor, bool active)

    function setPosition(monitor, widgetId, x, y) {
        root.positionChanged(monitor, widgetId, x, y);
    }

    function setPositions(monitor, positions) {
        if (!positions) return;
        if (Array.isArray(positions)) {
            for (let i = 0; i < positions.length; i++) {
                let p = positions[i];
                if (p && p.id !== undefined && p.x !== undefined && p.y !== undefined) {
                    root.positionChanged(monitor, String(p.id), p.x, p.y);
                }
            }
        } else if (typeof positions === "object") {
            for (let k in positions) {
                let p = positions[k];
                if (p && p.x !== undefined && p.y !== undefined) {
                    root.positionChanged(monitor, String(k), p.x, p.y);
                }
            }
        }
    }

    function setGeometry(monitor, widgetId, x, y, w, h, opacity, rotation) {
        root.geometryChanged(monitor, widgetId, x, y, w, h, opacity, rotation);
    }

    function setOpacity(monitor, widgetId, opacity) {
        root.widgetOpacityChanged(monitor, widgetId, opacity);
    }

    function setRotation(monitor, widgetId, rotation) {
        root.widgetRotationChanged(monitor, widgetId, rotation);
    }

    function setVariant(monitor, widgetId, variant) {
        root.variantChanged(monitor, widgetId, variant);
    }

    function setImagePath(monitor, widgetId, imagePath) {
        root.imagePathChanged(monitor, widgetId, imagePath);
    }

    function addWidget(monitor, widgetId, type, x, y, w, h, opacity, imagePath, rotation, variant) {
        root.widgetAdded(monitor, widgetId, type, x, y, w, h, opacity, imagePath, rotation, variant || "");
    }

    function addFromRegistry(monitor, type, config) {
        let def = WidgetRegistry.defaultSize(type);
        let id = (config && config.id) ? String(config.id) : ("w_" + Date.now() + "_" + Math.floor(Math.random() * 1000));
        let op = (config && config.opacity !== undefined) ? config.opacity : 1.0;
        let img = (config && config.imagePath !== undefined) ? config.imagePath : "";
        let rot = (config && config.rotation !== undefined) ? config.rotation : 0;
        let variant = (config && config.variant) ? config.variant : WidgetRegistry.defaultVariant(type);

        let sw = 1920;
        let sh = 1080;
        if (Quickshell.screens && Quickshell.screens.length > 0) {
            let target = String(monitor || "").trim().toLowerCase();
            let found = null;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name) {
                    let nm = String(scr.name).trim().toLowerCase();
                    let safe = nm.replace(/[^a-zA-Z0-9_-]/g, "_");
                    if (nm === target || safe === target) {
                        found = scr;
                        break;
                    }
                }
            }
            if (!found) found = Quickshell.screens[0];
            if (found) {
                if (found.width > 0) sw = found.width;
                if (found.height > 0) sh = found.height;
            }
        }

        let rawW = (config && config.w !== undefined) ? config.w : (config && config.width !== undefined ? config.width : def.w);
        let rawH = (config && config.h !== undefined) ? config.h : (config && config.height !== undefined ? config.height : def.h);
        let w = (config && (config.stretchWidth || config.wStretchWidth)) ? sw : WidgetRegistry.resolveDimension(rawW, sw, def.w);
        let h = (config && (config.stretchHeight || config.wStretchHeight)) ? sh : WidgetRegistry.resolveDimension(rawH, sh, def.h);

        let pos = WidgetRegistry.resolvePosition(config || {}, sw, sh, w, h);
        let x = pos.x;
        let y = pos.y;

        root.widgetAdded(monitor, id, type, x, y, w, h, op, img, rot, variant);
        return id;
    }

    function removeWidget(monitor, widgetId) {
        root.widgetRemoved(monitor, widgetId);
    }

    function removeWidgetsByType(monitor, type) {
        root.widgetsByTypeRemoved(monitor, type);
    }

    function clearWidgets(monitor) {
        root.widgetsCleared(monitor);
    }

    function applyPreset(monitor, widgetsList, clearFirst) {
        let len = (widgetsList && widgetsList.length !== undefined) ? widgetsList.length : 0;
        if (!widgetsList || len === 0) {
            return;
        }
        root.presetApplied(monitor, widgetsList);
    }

    function bringToFront(monitor, widgetId) {
        root.bringToFrontRequested(monitor, widgetId);
    }

    function setRedactMode(monitor, active) {
        root.redactModeChanged(monitor, active);
    }
}
