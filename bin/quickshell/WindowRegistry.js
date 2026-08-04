.pragma library

function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }

    if (mw <= 0 || mh <= 0) return 1.0;
    
    let rw = mw / 1920.0;
    let rh = mh / 1080.0;
    let r = Math.min(rw, rh);
    
    let baseScale = 1.0;
    
    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }
    
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);

    let rawLayouts = {
        // --- Top Right Popups ---
        "battery":           { baseW: 801,  baseH: 760,  pos: "top-right", comp: "battery/BatteryPopup.qml" },
        "network":           { baseW: 900,  baseH: 700,  pos: "top-right", comp: "network/NetworkPopup.qml" },
        "volume":            { baseW: 450,  baseH: 700,  pos: "top-right", comp: "volume/VolumePopup.qml" },
        "controlcenter":     { baseW: 420,  baseH: 580,  pos: "center",    comp: "controlcenter/ControlCenterPopup.qml" },
        
        // --- Central Standard Tools ---
        "applauncher":       { baseW: 800,  baseH: 700,  pos: "center",    comp: "applauncher/appLauncher.qml" },
        "clipboard":         { baseW: 800,  baseH: 700,  pos: "center",    comp: "clipboard/ClipboardManager.qml" },
        "monitors":          { baseW: 800,  baseH: 650,  pos: "center",    comp: "monitors/MonitorPopup.qml" },
        "stewart":           { baseW: 800,  baseH: 650,  pos: "center",    comp: "stewart/stewart.qml" },
        "notes":             { baseW: 900,  baseH: 700,  pos: "center",    comp: "notes/NotesPopup.qml" },
        "photobooth":        { baseW: 850,  baseH: 750,  pos: "center",    comp: "photobooth/PhotoBooth.qml" },
        "screenshotgallery": { baseW: 900,  baseH: 700,  pos: "center",    comp: "screenshot/ScreenshotGallery.qml" },

        // --- Central Large Tools ---
        "focustime":         { baseW: 900,  baseH: 700,  pos: "center",    comp: "focustime/FocusTimePopup.qml" },
        "services":          { baseW: 1150, baseH: 800,  pos: "center",    comp: "services/ServicesOverlay.qml" },

        // --- Extralarge / Custom Centered ---
        "guide":             { baseW: 1200, baseH: 750,  pos: "center",    comp: "guide/GuidePopup.qml" },
        "dashboard":         { baseW: 1200, baseH: 800,  pos: "center",    comp: "Dashboard.qml" },
        "calendar":          { baseW: 1450, baseH: 750,  pos: "top-center", comp: "calendar/CalendarPopup.qml" },
        "updater":           { baseW: 950,  baseH: 850,  pos: "center",    comp: "updater/UpdaterPopup.qml" },
        "wallpaper":         { baseW: 1920, baseH: 650,  pos: "wallpaper", comp: "wallpaper/WallpaperPicker.qml" },
        
        // --- Top Left Edge ---
        "music":             { baseW: 700,  baseH: 650,  pos: "top-left",  comp: "music/MusicPopup.qml" },

        "movies":            { baseW: 1370, baseH: 850,  pos: "bottom-center", comp: "movies/MovieWidget.qml" },
        
        // --- Screen Spanning Panels ---
        "settings":          { baseW: 450,  baseH: 1080, pos: "left-span", comp: "settings/SettingsPopup.qml" },
        
        // --- Utility ---
        "hidden":            { baseW: 1,    baseH: 1,    pos: "hidden",    comp: "" } 
    };

    if (!rawLayouts[name]) return null;

    let item = rawLayouts[name];
    if (item.pos === "hidden") {
        return { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, x: -5000, y: -5000, comp: "" };
    }

    // Dynamic relative bounds calculations
    let maxW = Math.floor(mw * 0.95);
    let maxH = Math.floor(mh * 0.90);
    
    let w = Math.min(s(item.baseW, scale), maxW);
    let h = Math.min(s(item.baseH, scale), maxH);
    
    let rx = 0;
    let ry = 0;

    if (item.pos === "top-right") {
        rx = mw - w - s(10, scale);
        ry = s(60, scale);
    } else if (item.pos === "top-left") {
        rx = s(5, scale);
        ry = s(60, scale);
    } else if (item.pos === "top-center") {
        rx = Math.floor((mw - w) / 2);
        ry = s(60, scale);
    } else if (item.pos === "bottom-center") {
        rx = Math.floor((mw - w) / 2);
        ry = mh - h;
    } else if (item.pos === "wallpaper") {
        w = mw;
        h = Math.min(s(650, scale), Math.floor(mh * 0.85));
        rx = 0;
        ry = Math.floor((mh - h) / 2);
    } else if (item.pos === "left-span") {
        w = Math.min(s(450, scale), Math.floor(mw * 0.4));
        h = mh;
        rx = 0;
        ry = 0;
    } else { // "center"
        rx = Math.floor((mw - w) / 2);
        ry = Math.floor((mh - h) / 2);
    }

    return {
        w: w,
        h: h,
        rx: rx,
        ry: ry,
        x: mx + rx,
        y: my + ry,
        comp: item.comp
    };
}

function getPopupLayout(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }
    
    let scale = getScale(mw, mh, userScale);
    return {
        w: s(350, scale),
        marginTop: s(60, scale),
        marginRight: s(20, scale),
        spacing: s(12, scale),
        radius: s(14, scale),
        padding: s(12, scale)
    };
}
