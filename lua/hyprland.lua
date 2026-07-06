
-- Setup module search path to include the lua/ subfolder
local home = os.getenv("HOME") or "/home/khxnh"
package.path = package.path .. ";" .. home .. "/.config/niri/lua/?.lua;" .. home .. "/.config/niri/lua/?/init.lua;lua/?.lua;lua/?/init.lua"


-- Force reload Lua modules on configuration reload to prevent caching issues
package.loaded["colors"] = nil
package.loaded["config.variables"] = nil
package.loaded["config.monitors"] = nil
package.loaded["config.env"] = nil
package.loaded["config.autostart"] = nil
package.loaded["config.settings"] = nil
package.loaded["config.rules"] = nil
package.loaded["config.keybindings"] = nil

-- Load global colors (dynamically updated by Matugen)
require("colors")

-- Load modular configurations
require("config.variables")
require("config.monitors")
require("config.env")
require("config.autostart")
require("config.settings")
require("config.rules")
require("config.keybindings")
