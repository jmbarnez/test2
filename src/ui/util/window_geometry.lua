local theme = require("src.ui.theme")
---@diagnostic disable-next-line: undefined-global
local love = love

local window_geometry = {}

local function clamp_margin(value, dimension)
    value = tonumber(value) or 0
    if value <= 0 then
        return 0
    end
    local max_margin = math.floor(math.max(0, dimension) * 0.5)
    if value > max_margin then
        return max_margin
    end
    return value
end

local function capture_preferred(option, fallback)
    if option ~= nil then
        return option
    end
    if fallback ~= nil then
        return fallback
    end
    return 0
end

function window_geometry.centered(options)
    options = options or {}

    local spacing = theme.get_spacing and theme.get_spacing() or theme.spacing or {}
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    local preferred_width = capture_preferred(options.width, options.preferred_width or options.preferredWidth or 640)
    local preferred_height = capture_preferred(options.height, options.preferred_height or options.preferredHeight or 520)
    local min_width = capture_preferred(options.min_width, options.minWidth or 320)
    local min_height = capture_preferred(options.min_height, options.minHeight or 240)

    min_width = math.min(min_width, screen_width)
    min_height = math.min(min_height, screen_height)

    local margin = options.margin
    if margin == nil then
        margin = spacing.window_margin or 48
    end
    margin = clamp_margin(margin, screen_width)

    local vertical_margin = options.vertical_margin
    if vertical_margin == nil then
        vertical_margin = options.verticalMargin or margin
    end
    vertical_margin = clamp_margin(vertical_margin, screen_height)

    local available_width = math.max(0, screen_width - margin * 2)
    local available_height = math.max(0, screen_height - vertical_margin * 2)

    local width = math.min(preferred_width, available_width)
    local height = math.min(preferred_height, available_height)

    if width <= 0 then
        width = math.min(preferred_width, screen_width)
    end
    if height <= 0 then
        height = math.min(preferred_height, screen_height)
    end

    width = math.max(min_width, math.min(width, screen_width))
    height = math.max(min_height, math.min(height, screen_height))

    local x = (screen_width - width) * 0.5
    local y = (screen_height - height) * 0.5

    x = math.max(margin, x)
    y = math.max(vertical_margin, y)

    local max_x = math.max(0, screen_width - width)
    local max_y = math.max(0, screen_height - height)

    x = math.min(x, max_x)
    y = math.min(y, max_y)

    return {
        x = x,
        y = y,
        width = width,
        height = height,
    }
end

return window_geometry
