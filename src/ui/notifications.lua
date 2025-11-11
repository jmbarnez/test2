local theme = require("src.ui.theme")

---@diagnostic disable-next-line: undefined-global
local love = love

local notifications = {}

local DEFAULT_DURATION = 2.2
local SLIDE_TIME = 0.18
local MAX_STACK = 4

local function resolve_host(context)
    if not context then
        return nil
    end

    if context.notifications then
        return context
    end

    if context.uiContext then
        context.uiContext.notifications = context.uiContext.notifications or {
            items = {},
        }
        return context.uiContext
    end

    context.notifications = {
        items = {},
    }

    return context
end

local function ensure_state(context)
    local host = resolve_host(context)
    if not host then
        return nil
    end

    host.notifications = host.notifications or {
        items = {},
    }

    return host.notifications
end

local function push_item(state, item)
    local items = state.items

    items[#items + 1] = item

    while #items > MAX_STACK do
        table.remove(items, 1)
    end
end

function notifications.push(context, opts)
    local state = ensure_state(context)
    if not state then
        return
    end

    opts = opts or {}

    local now = love.timer and love.timer.getTime and love.timer.getTime() or os.time()

    push_item(state, {
        text = opts.text or "",
        icon = opts.icon,
        accent = opts.accent,
        created_at = now,
        duration = opts.duration or DEFAULT_DURATION,
        slide_in = opts.slide_in or SLIDE_TIME,
    })
end

local function draw_item(item, index, x, y, width, fonts, colors, now)
    local bodyFont = fonts.body
    local textHeight = bodyFont:getHeight()
    local verticalSpacing = textHeight + 18
    local baseY = y - (index - 1) * verticalSpacing

    local elapsed = now - item.created_at
    local remaining = (item.duration or DEFAULT_DURATION) - elapsed
    if remaining <= 0 then
        return false
    end

    local slide = math.max(0, math.min(1, elapsed / (item.slide_in or SLIDE_TIME)))
    local offsetX = (1 - slide) * 120

    local alpha = 1
    if remaining < 0.4 then
        alpha = math.max(0, remaining / 0.4)
    end

    love.graphics.push("all")

    local background = colors.background
    love.graphics.setColor(background[1], background[2], background[3], (background[4] or 1) * alpha)
    love.graphics.rectangle("fill", x + offsetX, baseY, width, 28, 4, 4)

    local border = colors.border
    love.graphics.setColor(border[1], border[2], border[3], (border[4] or 1) * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + offsetX + 0.5, baseY + 0.5, width - 1, 27, 4, 4)

    local textColor = colors.text
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)

    local textX = x + offsetX + 12
    local textY = baseY + (28 - textHeight) * 0.5

    if item.icon then
        local accent = item.accent or colors.accent
        love.graphics.setColor(accent[1], accent[2], accent[3], alpha)
        love.graphics.circle("fill", textX, baseY + 14, 4)
        textX = textX + 16
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)
    end

    love.graphics.print(item.text, textX, textY)

    love.graphics.pop()

    return true
end

function notifications.draw(context, dt)
    local state = ensure_state(context)
    if not state then
        return
    end

    local items = state.items
    if not items or #items == 0 then
        return
    end

    if not (love and love.graphics and love.graphics.getWidth) then
        return
    end

    local fonts = theme.get_fonts()
    local colors = theme.colors.toast or {
        background = { 0.08, 0.1, 0.16, 0.92 },
        border = { 0.24, 0.36, 0.52, 0.85 },
        text = { 0.82, 0.88, 0.96, 1 },
        accent = { 0.32, 0.62, 0.92, 1 },
    }

    local screenWidth = love.graphics.getWidth()
    local margin = 32
    local width = 320
    local x = screenWidth - margin - width

    local now = love.timer and love.timer.getTime and love.timer.getTime() or os.time()

    local bottomY = love.graphics.getHeight() - margin
    local survivors = {}
    local drawIndex = 1

    for i = #items, 1, -1 do
        local item = items[i]
        if draw_item(item, drawIndex, x, bottomY, width, fonts, colors, now) then
            survivors[#survivors + 1] = item
            drawIndex = drawIndex + 1
        end
    end

    state.items = {}
    for i = #survivors, 1, -1 do
        state.items[#state.items + 1] = survivors[i]
    end
end

return notifications
