
local home = os.getenv("HOME") or "/home/khxnh"
local settings_path = home .. "/.config/niri/settings.json"

local file = io.open(settings_path, "r")
if file then
    local content = file:read("*all")
    file:close()

    -- Extract the full monitors JSON array content
    local monitors_block = content:match('"monitors"%s*:%s*%[(.-)%]')
    if monitors_block then
        -- Find primary monitor's resolution (first monitor in settings)
        local primaryRes = "preferred"
        local first_entry = monitors_block:match('{([^{}]+)}')
        if first_entry then
            local w = first_entry:match('"resW"%s*:%s*(%d+)')
            local h = first_entry:match('"resH"%s*:%s*(%d+)')
            if w and h then
                primaryRes = w .. "x" .. h
            end
        end

        -- Iterate over each {...} object within the monitors array
        for entry in monitors_block:gmatch('{([^{}]+)}') do
            local name = entry:match('"name"%s*:%s*"([^"]+)"')
            if name then
                local resW = entry:match('"resW"%s*:%s*(%d+)')
                local resH = entry:match('"resH"%s*:%s*(%d+)')
                local rate = entry:match('"rate"%s*:%s*(%d+)')
                local x = entry:match('"x"%s*:%s*(%d+)')
                local y = entry:match('"y"%s*:%s*(%d+)')
                local scale = entry:match('"scale"%s*:%s*([%d%.]+)') or "1"
                local transform = tonumber(entry:match('"transform"%s*:%s*(%d+)')) or 0
                local mirrorOf = entry:match('"mirrorOf"%s*:%s*"([^"]*)"') or ""

                if mirrorOf ~= "" then
                    -- Mirror mode: this monitor mirrors another, matching its resolution
                    hl.monitor({
                        output    = name,
                        mode      = primaryRes,
                        position  = "auto",
                        scale     = tonumber(scale) or 1,
                        mirror    = mirrorOf,
                    })
                else
                    -- Extend mode: normal positioning
                    local mode = "preferred"
                    if resW and resH then
                        if rate then
                            mode = resW .. "x" .. resH .. "@" .. rate
                        else
                            mode = resW .. "x" .. resH
                        end
                    end

                    local position = "auto"
                    if x and y then
                        position = x .. "x" .. y
                    end

                    hl.monitor({
                        output    = name,
                        mode      = mode,
                        position  = position,
                        scale     = tonumber(scale) or 1,
                        transform = transform,
                    })
                end
            end
        end
    end
end

-- Catch-all: any new/unknown monitor (e.g. HDMI hotplug) gets auto config
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
