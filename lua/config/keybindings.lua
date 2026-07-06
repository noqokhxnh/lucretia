
local vars    = require("config.variables")
local mainMod = vars.mainMod
local terminal = vars.terminal

-- ───────── Gestures ──────────────────────────────────────────────────────────
local function is_overview_open()
    local f = io.open("/tmp/overview_open", "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content:match("1") ~= nil
    end
    return false
end

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.gesture({
    fingers   = 3,
    direction = "up",
    action    = function()
        hl.dispatch(hl.dsp.exec_cmd("~/.config/niri/scripts/qs_manager.sh toggle overview"))
    end,
})

hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = function()
        if is_overview_open() then
            hl.dispatch(hl.dsp.exec_cmd("quickshell -p ~/.config/niri/scripts/quickshell/Shell.qml ipc call overview close"))
        end
    end,
})


-- ───────── Mouse Binds ───────────────────────────────────────────────────────
-- v0.55: hl.bind("MODS + mouse:BTN", dispatcher, { mouse = true })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ───────── Core & Window Manager Toggles ─────────────────────────────────────
-- close = one window; kill() SIGKILLs the whole process (all windows of that app)
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F",   hl.dsp.window.float())
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.window.float())

-- ───────── Window Resizing (repeating) ───────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }),  { repeating = true })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = 50, relative = true }),  { repeating = true })
hl.bind(mainMod .. " + CTRL + H",      hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L",      hl.dsp.window.resize({ x = 50, y = 0, relative = true }),  { repeating = true })
hl.bind(mainMod .. " + CTRL + K",      hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J",      hl.dsp.window.resize({ x = 0, y = 50, relative = true }),  { repeating = true })

-- ───────── Window Moving ─────────────────────────────────────────────────────
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }))

local function move_window(dir, dx, dy)
    local win = hl.get_active_window()
    if win then
        if win.floating then
            hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
        else
            hl.dispatch(hl.dsp.window.move({ direction = dir }))
        end
    end
end

hl.bind(mainMod .. " + SHIFT + H", function() move_window("l", -50, 0) end, { repeating = true })
hl.bind(mainMod .. " + SHIFT + L", function() move_window("r", 50, 0) end,  { repeating = true })
hl.bind(mainMod .. " + SHIFT + K", function() move_window("u", 0, -50) end, { repeating = true })
hl.bind(mainMod .. " + SHIFT + J", function() move_window("d", 0, 50) end,  { repeating = true })

-- ───────── Focus Movement ─────────────────────────────────────────────────────
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + H",     hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L",     hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K",     hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J",     hl.dsp.focus({ direction = "d" }) )

-- ───────── Applications ───────────────────────────────────────────────────────
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + W",      hl.dsp.exec_cmd("brave"))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("nautilus"))

-- ───────── Quickshell Scripts ─────────────────────────────────────────────────
local qs = "bash ~/.config/niri/scripts/qs_manager.sh toggle "
hl.bind(mainMod .. " + SHIFT + ALT + R", hl.dsp.exec_cmd("bash ~/.config/niri/scripts/reload.sh"))
hl.bind(mainMod .. " + V",              hl.dsp.exec_cmd("~/.config/niri/scripts/qs_manager.sh toggle clipboard"))
hl.bind(mainMod .. " + SHIFT + P",      hl.dsp.exec_cmd(qs .. "movies"))
hl.bind(mainMod .. " + Super_L",        hl.dsp.exec_cmd(qs .. "applauncher"))
hl.bind(mainMod .. " + SHIFT + I",      hl.dsp.exec_cmd(qs .. "settings"))
hl.bind(mainMod .. " + SHIFT + Q",      hl.dsp.exec_cmd(qs .. "music"))
hl.bind(mainMod .. " + SHIFT + B",      hl.dsp.exec_cmd(qs .. "battery"))
hl.bind(mainMod .. " + SHIFT + W",      hl.dsp.exec_cmd(qs .. "wallpaper"))
hl.bind(mainMod .. " + SHIFT + C",      hl.dsp.exec_cmd(qs .. "calendar"))
hl.bind(mainMod .. " + C",             hl.dsp.exec_cmd(qs .. "photobooth"))
hl.bind(mainMod .. " + SHIFT + N",      hl.dsp.exec_cmd(qs .. "network"))
hl.bind(mainMod .. " + N",             hl.dsp.exec_cmd(qs .. "notes"))
hl.bind(mainMod .. " + SHIFT + T",      hl.dsp.exec_cmd(qs .. "focustime"))
hl.bind(mainMod .. " + SHIFT + V",      hl.dsp.exec_cmd(qs .. "volume"))
hl.bind(mainMod .. " + SHIFT + ALT + H",      hl.dsp.exec_cmd(qs .. "guide"))
hl.bind(mainMod .. " + SHIFT + M",      hl.dsp.exec_cmd(qs .. "monitors"))
hl.bind(mainMod .. " + D",             hl.dsp.exec_cmd(qs .. "dashboard"))
hl.bind(mainMod .. " + SHIFT + D",      hl.dsp.exec_cmd(qs .. "services"))

-- ───────── Hardware Controls (locked: work even on lockscreen) ────────────────
hl.bind("Caps_Lock",           hl.dsp.exec_cmd("sleep 0.1 && swayosd-client --caps-lock"),        { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"),            { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"),            { locked = true })

-- ───────── Screenshot Binds ───────────────────────────────────────────────────
hl.bind("Print",                   hl.dsp.exec_cmd("~/.config/niri/scripts/screenshot.sh"))
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd("~/.config/niri/scripts/screenshot.sh --edit"))
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd("~/.config/niri/scripts/screenshot.sh --full"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("~/.config/niri/scripts/screenshot.sh --full --edit"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/niri/scripts/screenshot.sh"))

-- ───────── Session & Media Controls (locked) ─────────────────────────────────
hl.bind("XF86PowerOff",         hl.dsp.exec_cmd("bash ~/.config/niri/scripts/lock.sh"),   { locked = true })
hl.bind(mainMod .. " + comma",  hl.dsp.exec_cmd("bash ~/.config/niri/scripts/lock.sh"),   { locked = true, repeating = true })
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd("playerctl play-pause"),                  { locked = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"),                  { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"),                  { locked = true })
hl.bind("xf86AudioMicMute",     hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  { locked = true })
hl.bind("xf86audiomute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("xf86audiolowervolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),  { locked = true, repeating = true })
hl.bind("xf86audioraisevolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"),  { locked = true, repeating = true })

-- ───────── Workspaces ─────────────────────────────────────────────────────────
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,           hl.dsp.exec_cmd("~/.config/niri/scripts/qs_manager.sh " .. i))
    hl.bind(mainMod .. " + ALT + " .. i,     hl.dsp.exec_cmd("~/.config/niri/scripts/qs_manager.sh " .. i .. " move"))
end
hl.bind(mainMod .. " + 0",           hl.dsp.exec_cmd("~/.config/niri/scripts/qs_manager.sh 10"))
hl.bind(mainMod .. " + ALT + 0",     hl.dsp.exec_cmd("~/.config/niri/scripts/qs_manager.sh 10 move"))

-- ───────── Workspace Overview ─────────────────────────────────────────────────
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("~/.config/niri/scripts/qs_manager.sh toggle overview"))
