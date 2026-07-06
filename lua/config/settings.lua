
local colors = require("colors")

-- Read animSpeedMultiplier from settings.json
local function get_anim_speed()
    local home = os.getenv("HOME") or "/home/khxnh"
    local settings_path = home .. "/.config/niri/settings.json"
    local speed_multiplier = 1.0
    local file = io.open(settings_path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local multiplier_str = content:match('"animSpeedMultiplier"%s*:%s*([%d%.]+)')
        if multiplier_str then
            speed_multiplier = tonumber(multiplier_str) or 1.0
        end
    end
    -- Base speed in deciseconds is 5.
    -- Higher multiplier means faster animation, so lower duration (in deciseconds).
    return math.max(0.1, 5 / speed_multiplier)
end

local anim_speed = get_anim_speed()

-- ─── Bezier Curves (must be declared before animation references) ───────────
-- v0.55 API: hl.curve(name, { type = "bezier", points = { {x1,y1}, {x2,y2} } })
hl.curve("myBezier", {
    type   = "bezier",
    points = { { 0.05, 0.9 }, { 0.1, 1.05 } }
})

-- ─── Core Settings ───────────────────────────────────────────────────────────
hl.config({
    general = {
        border_size          = 2,
        gaps_in              = 4,
        gaps_out             = 4,
        float_gaps           = 6,
        resize_on_border     = true,
        extend_border_grab_area = 30,
        col = {
            -- v0.55: border color is a table with `colors` array (and optional `angle`)
            active_border   = { colors = { colors.active_border } },
            inactive_border = { colors = { colors.inactive_border } },
        },
    },

    decoration = {
        rounding         = 4,
        active_opacity   = 0.93,
        inactive_opacity = 0.93,
        blur = {
            enabled          = true,
            size             = 8,
            passes           = 2,
            new_optimizations = true,
        },
        shadow = {
            enabled = false,
        },
    },

    input = {
        kb_layout  = "",
        kb_options = "",
        sensitivity = 0.0,  -- no acceleration bias (macOS-like neutral feel)
        touchpad = {
            natural_scroll       = true,    -- scroll like macOS (content follows fingers)
            scroll_factor        = 0.5,     -- smooth, controlled scroll speed
            tap_to_click         = true,    -- tap = click (macOS default)
            drag_lock            = true,    -- lift finger briefly while dragging without dropping
            disable_while_typing = true,    -- avoid accidental touches while typing
            clickfinger_behavior = true,    -- 2-finger tap = right click, 3-finger = middle (macOS style)
        },
    },

    cursor = {
        no_warps = true,
    },

    misc = {
        font_family              = "JetBrains Mono",
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },

    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },

    animations = {
        enabled = true,
        -- Animations reference curves by name (defined via hl.curve above)
        animation = {
            { "windows",             1, anim_speed, "myBezier", "popin 80%" },
            { "windowsOut",          1, anim_speed, "myBezier", "popin 80%" },
            { "layers",              1, anim_speed, "myBezier", "fade"      },
            { "layersIn",            1, anim_speed, "myBezier", "fade"      },
            { "layersOut",           1, anim_speed, "myBezier", "fade"      },
            { "fade",                1, anim_speed, "myBezier"              },
            { "workspaces",          1, anim_speed, "myBezier", "slide"     },
            { "specialWorkspaceIn",  1, anim_speed, "myBezier", "fade"      },
            { "specialWorkspaceOut", 1, anim_speed, "myBezier", "fade"      },
        },
    },
})
