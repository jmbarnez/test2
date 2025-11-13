local theme = require("src.ui.theme")

---@diagnostic disable-next-line: undefined-global
local love = love

local CurrencyIcon = {}

---Draws a stylized credit icon at the specified position.
---@param x number
---@param y number
---@param size number
---@param alpha number|nil
function CurrencyIcon.draw(x, y, size, alpha)
    if not (love and love.graphics and size and size > 0) then
        return
    end

    alpha = alpha or 1
    if alpha <= 0 then
        return
    end

    local lg = love.graphics
    local window_colors = theme.colors.window or {}

    local base = window_colors.currency_icon_base or { 0.35, 0.7, 1.0, 1 }
    local highlight = window_colors.currency_icon_highlight or { 0.75, 0.9, 1.0, 0.9 }
    local border = window_colors.currency_icon_border or { 0.08, 0.25, 0.38, 1 }
    local symbol = window_colors.currency_icon_symbol or { 1, 1, 1, 1 }

    local radius = size * 0.5
    local centerX = x + radius
    local centerY = y + radius

    lg.push("all")

    lg.setColor(base[1], base[2], base[3], (base[4] or 1) * alpha)
    lg.circle("fill", centerX, centerY, radius)

    lg.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 1) * alpha)
    lg.circle("fill", centerX, centerY - radius * 0.28, radius * 0.62)

    lg.setColor(border[1], border[2], border[3], (border[4] or 1) * alpha)
    local borderWidth = math.max(0.8, size * 0.08)
    lg.setLineWidth(borderWidth)
    lg.circle("line", centerX, centerY, radius - borderWidth * 0.5)

    lg.setColor(symbol[1], symbol[2], symbol[3], (symbol[4] or 1) * alpha)
    local vertical = math.max(1, size * 0.14)
    lg.setLineWidth(vertical)
    lg.line(centerX, centerY - radius * 0.42, centerX, centerY + radius * 0.42)

    local horizontal = math.max(0.8, size * 0.1)
    lg.setLineWidth(horizontal)
    lg.line(centerX - radius * 0.48, centerY - radius * 0.18, centerX + radius * 0.48, centerY - radius * 0.18)
    lg.line(centerX - radius * 0.48, centerY + radius * 0.22, centerX + radius * 0.48, centerY + radius * 0.22)

    lg.pop()
end

return CurrencyIcon
