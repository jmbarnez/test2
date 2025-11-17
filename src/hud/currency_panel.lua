local constants = require("src.constants.game")
local theme = require("src.ui.theme")
local Util = require("src.hud.util")
local PlayerCurrency = require("src.player.currency")

---@diagnostic disable-next-line: undefined-global
local love = love

local CurrencyPanel = {}

local ui_constants = (constants.ui and constants.ui.currency_panel) or {}

local function get_time()
    local loveTimer = love and love.timer
    if loveTimer and loveTimer.getTime then
        return loveTimer.getTime()
    end
    return os.time()
end

local function ease_out_cubic(t)
    t = Util.clamp01(t or 0)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function compose_credit_text(amount)
    local numeric = tonumber(amount) or 0
    local prefix = numeric >= 0 and "+" or ""
    return string.format("%s%d", prefix, math.floor(numeric + 0.5))
end

local function draw_currency_icon(x, y, size, colors)
    if not (love and love.graphics) then
        return
    end

    local lg = love.graphics
    local radius = size * 0.5
    local centerX = x + radius
    local centerY = y + radius

    local base = colors.base or { 0.35, 0.7, 1.0, 1 }
    local highlight = colors.highlight or { 0.75, 0.9, 1.0, 0.9 }
    local border = colors.border or { 0.08, 0.25, 0.38, 1 }
    local symbol = colors.symbol or { 1, 1, 1, 1 }

    lg.push("all")

    lg.setColor(base[1], base[2], base[3], base[4] or 1)
    lg.circle("fill", centerX, centerY, radius)

    lg.setColor(highlight[1], highlight[2], highlight[3], highlight[4] or 1)
    lg.circle("fill", centerX, centerY - radius * 0.28, radius * 0.62)

    lg.setColor(border[1], border[2], border[3], border[4] or 1)
    local borderWidth = math.max(1, size * 0.08)
    lg.setLineWidth(borderWidth)
    lg.circle("line", centerX, centerY, radius - borderWidth * 0.5)

    lg.setColor(symbol[1], symbol[2], symbol[3], symbol[4] or 1)
    local vertical = math.max(1.2, size * 0.14)
    lg.setLineWidth(vertical)
    lg.line(centerX, centerY - radius * 0.42, centerX, centerY + radius * 0.42)

    local horizontal = math.max(1, size * 0.1)
    lg.setLineWidth(horizontal)
    lg.line(centerX - radius * 0.48, centerY - radius * 0.18, centerX + radius * 0.48, centerY - radius * 0.18)
    lg.line(centerX - radius * 0.48, centerY + radius * 0.22, centerX + radius * 0.48, centerY + radius * 0.22)

    lg.pop()
end

function CurrencyPanel.draw(context)
    local lg = love and love.graphics
    if not lg then
        return
    end

    context = context or {}
    local state = context.state or context
    if type(state) ~= "table" then
        return
    end

    local gain = PlayerCurrency.getActiveGain(state)
    if not gain then
        return
    end

    local fonts = theme.get_fonts()
    if not fonts then
        return
    end

    local hud_colors = theme.colors.hud or {}
    local window_colors = theme.colors.window or {}
    local palette = theme.palette or {}
    local spacing = theme.spacing or {}
    local set_color = theme.utils.set_color

    local now = get_time()
    local createdAt = tonumber(gain.createdAt) or now
    local visibleDuration = tonumber(gain.visibleDuration) or 2.6
    if visibleDuration <= 0 then
        visibleDuration = 2.6
    end

    local expiresAt = tonumber(gain.expiresAt or 0)
    if expiresAt <= 0 then
        expiresAt = createdAt + visibleDuration
    end

    if now >= expiresAt then
        state.currencyGain = state.currencyGain or {}
        state.currencyGain.active = nil
        return
    end

    local animStart = tonumber(gain.animStart) or createdAt
    local animDuration = tonumber(gain.animDuration) or 0.45
    if animDuration <= 0 then
        animDuration = 0.45
    end

    local animElapsed = now - animStart
    local animFactor = ease_out_cubic(animElapsed / animDuration)

    local elapsed = now - createdAt
    local alpha = 1
    if visibleDuration > 0 then
        local fadeWindow = math.min(0.8, visibleDuration * 0.45)
        local fadeStart = visibleDuration - fadeWindow
        if fadeStart < 0 then
            fadeStart = 0
        end
        if elapsed >= fadeStart then
            local fadeT = Util.clamp01((elapsed - fadeStart) / math.max(fadeWindow, 0.0001))
            alpha = 1 - fadeT
        end
    end

    if alpha <= 0 then
        return
    end

    local amountText = compose_credit_text(gain.lastAmount or gain.amount or 0)
    local balance = tonumber(gain.balance) or 0
    local balanceText = string.format("Balance: %s", tostring(math.floor(balance + 0.5)))

    local width = ui_constants.width or 180
    local height = ui_constants.height or 62
    local padding = math.min(12, spacing.window_padding or 12)

    local screenWidth = lg.getWidth()
    local minimapDiameter = ui_constants.minimap_diameter or 120
    local minimapMargin = ui_constants.minimap_margin or 24
    local gap = ui_constants.gap or 16

    local x = screenWidth - minimapDiameter - minimapMargin - width - gap
    if x < minimapMargin then
        x = minimapMargin
    end

    local baseY = ui_constants.base_y or 122
    local offsetY = (1 - animFactor) * (ui_constants.offset_y or 22)
    local y = baseY - offsetY

    lg.push("all")
    lg.origin()

    lg.setColor(0, 0, 0, 0.25 * alpha)
    lg.rectangle("fill", x, y + 2, width, height)

    local panelColor = hud_colors.status_panel or { 0.05, 0.06, 0.09, 0.95 }
    set_color({ panelColor[1], panelColor[2], panelColor[3], (panelColor[4] or 1) * alpha })
    lg.rectangle("fill", x, y, width, height)

    local borderColor = hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 }
    lg.setLineWidth(1)
    lg.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * alpha)
    lg.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)

    local iconSize = 36
    local iconX = x + padding
    local iconY = y + padding
    draw_currency_icon(iconX, iconY, iconSize, {
        base = window_colors.currency_icon_base or palette.accent or { 0.35, 0.7, 1.0, 1 },
        highlight = window_colors.currency_icon_highlight or { 0.75, 0.9, 1.0, 0.9 },
        border = window_colors.currency_icon_border or borderColor,
        symbol = window_colors.currency_icon_symbol or { 1, 1, 1, 1 },
    })

    local textColor = hud_colors.status_text or { 0.85, 0.89, 0.93, 1 }
    local mutedColor = hud_colors.status_muted or { 0.46, 0.52, 0.58, 1 }

    lg.setFont(fonts.body)
    lg.setColor(textColor[1], textColor[2], textColor[3], alpha)
    local textX = iconX + iconSize + padding
    local textY = y + padding
    lg.print(string.format("%s credits", amountText), textX, textY)

    lg.setFont(fonts.small)
    lg.setColor(mutedColor[1], mutedColor[2], mutedColor[3], alpha * 0.9)
    lg.print(balanceText, textX, textY + fonts.body:getHeight() + 4)

    lg.pop()
end

return CurrencyPanel
