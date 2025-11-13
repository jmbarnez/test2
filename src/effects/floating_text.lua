local theme = require("src.ui.theme")
local CurrencyIcon = require("src.ui.util.currency_icon")

---@diagnostic disable-next-line: undefined-global
local love = love

local FloatingText = {}

local DEFAULT_DURATION = 1.6
local DEFAULT_RISE = 36
local HORIZONTAL_DRIFT = 8

local fallbackHost = nil

local function resolve_state(state)
    return state or fallbackHost
end

local function ensure_container(state)
    state = resolve_state(state)
    if not state then
        return nil
    end

    state.floatingText = state.floatingText or {}
    return state.floatingText
end

function FloatingText.setFallback(state)
    fallbackHost = state
end

function FloatingText.getFallback()
    return fallbackHost
end

local function normalize_position(position)
    if type(position) == "table" then
        local x = position.x or position[1]
        local y = position.y or position[2]
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    return nil, nil
end

function FloatingText.clear(state)
    local host = resolve_state(state)
    if not host then
        return
    end
    host.floatingText = {}
end

function FloatingText.add(state, position, text, opts)
    local container = ensure_container(state)
    if not container then
        return
    end

    local x, y = normalize_position(position)
    if not x or not y then
        return
    end

    opts = opts or {}

    local amount = opts.amount
    local label = text or (amount and string.format("+%s", tostring(amount))) or "+0"

    local fonts = theme.get_fonts()
    local requestedFont = opts.font
    local font
    if fonts then
        if type(requestedFont) == "string" and fonts[requestedFont] then
            font = fonts[requestedFont]
        elseif type(requestedFont) == "userdata" then
            font = requestedFont
        else
            font = fonts.body
        end
    end
    font = font or love.graphics.getFont()

    local lines = {}
    for line in string.gmatch(label, "[^\n]+") do
        lines[#lines + 1] = line
    end
    if #lines == 0 then
        lines[1] = label
    end

    local duration = math.max(0.1, opts.duration or DEFAULT_DURATION)
    local rise = opts.rise or DEFAULT_RISE
    local offsetY = opts.offsetY or 0

    local color = opts.color or theme.colors.toast and theme.colors.toast.accent or { 0.7, 0.9, 1.0, 1.0 }

    local entry = {
        x = x + (opts.offsetX or 0),
        y = y - offsetY,
        vx = (opts.vx or 0) + (love.math.random() - 0.5) * HORIZONTAL_DRIFT,
        vy = -(rise),
        text = label,
        lines = lines,
        font = font,
        fontHeight = font:getHeight(),
        lineHeight = font:getHeight() * font:getLineHeight(),
        color = {
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            color[4] or 1,
        },
        age = 0,
        duration = duration,
        shadow = opts.shadow ~= false,
        scale = opts.scale or 1,
        icon = opts.icon,
        __alive = true,
    }
    container[#container + 1] = entry

    return entry
end

function FloatingText.update(state, dt)
    local host = resolve_state(state)
    local container = host and host.floatingText
    if not container or #container == 0 then
        return
    end

    for index = #container, 1, -1 do
        local entry = container[index]
        entry.age = entry.age + dt
        if entry.age >= entry.duration then
            entry.__alive = false
            table.remove(container, index)
        else
            entry.x = entry.x + entry.vx * dt
            entry.y = entry.y + entry.vy * dt
        end
    end
end

function FloatingText.draw(state)
    local host = resolve_state(state)
    local container = host and host.floatingText
    if not container or #container == 0 then
        return
    end

    local fonts = theme.get_fonts()
    local defaultFont = fonts and fonts.body or love.graphics.getFont()

    love.graphics.push("all")

    for i = 1, #container do
        local entry = container[i]
        local t = entry.age / entry.duration
        local alpha = math.max(0, 1 - t)
        local scale = entry.scale

        local textX = entry.x
        local textY = entry.y

        local font = entry.font or defaultFont
        love.graphics.setFont(font)
        local baseLineHeight = entry.lineHeight or (font:getHeight() * font:getLineHeight())
        local scaledLineHeight = baseLineHeight * scale

        if entry.shadow then
            love.graphics.setColor(0, 0, 0, alpha * 0.55)
            for lineIndex = 1, #entry.lines do
                local line = entry.lines[lineIndex]
                local lineY = textY + (lineIndex - 1) * scaledLineHeight
                love.graphics.print(line, textX + 1, lineY + 1, 0, scale, scale)
            end
        end

        local color = entry.color
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
        for lineIndex = 1, #entry.lines do
            local line = entry.lines[lineIndex]
            local lineY = textY + (lineIndex - 1) * scaledLineHeight
            love.graphics.print(line, textX, lineY, 0, scale, scale)
        end

        if entry.icon == "currency" then
            local lastLine = entry.lines[#entry.lines] or entry.text
            local textWidth = font:getWidth(lastLine or "") * scale
            local iconSize = (entry.fontHeight or font:getHeight()) * scale * 0.9
            local iconX = textX + textWidth + 4
            local iconY = textY + scaledLineHeight * (#entry.lines - 1)
            CurrencyIcon.draw(iconX, iconY, iconSize, alpha)
        end
    end

    love.graphics.pop()
end

return FloatingText
