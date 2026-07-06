
local M = {}

-- Fallbacks in case colors.conf is unreadable or empty
M.active_border   = "rgba(b8c3ffee)"
M.inactive_border = "rgba(374379aa)"

local home        = os.getenv("HOME") or "/home/khxnh"
local colors_path = home .. "/.config/niri/colors.conf"

local file = io.open(colors_path, "r")
if not file then
    file = io.open("colors.conf", "r")
end

if file then
    for line in file:lines() do
        local name, val = line:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
        if name and val then
            M[name] = val
        end
    end
    file:close()
end

return M
