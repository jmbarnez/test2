local theme = require("src.ui.theme")
---@diagnostic disable-next-line: undefined-global
local love = love

local death_window = {}

local window_colors = theme.colors.window
local text_colors = theme.colors.text
local spacing = theme.spacing

local function get_line_height(font)
    if not font then
        return 0
    end
    return font:getHeight() * font:getLineHeight()
end

function death_window.draw(context)
    local state = context and context.deathUI
    if not (state and state.visible) then
        return false
    end

    local fonts = theme.get_fonts()
    local titleFont = fonts.title or fonts.body
    local bodyFont = fonts.body or titleFont
    local hintFont = fonts.small or bodyFont

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local padding = (spacing and spacing.window_padding) or 20
    local cornerRadius = (spacing and spacing.window_corner_radius) or 6

    local maxPanelWidth = math.max(240, screenWidth - padding * 2)
    local panelWidth = math.min(440, maxPanelWidth)
    local innerWidth = math.max(160, panelWidth - padding * 2)

    local message = state.message or ""
    local hasMessage = message:match("%S") ~= nil
    local _, messageLines = bodyFont:getWrap(message, innerWidth)
    local messageLineCount = #messageLines
    local bodyLineHeight = get_line_height(bodyFont)
    local messageHeight = hasMessage and messageLineCount * bodyLineHeight or 0

    local hint = state.hint or ""
    local hasHint = hint:match("%S") ~= nil
    local _, hintLines = hintFont:getWrap(hint, innerWidth)
    local hintHeight = hasHint and (#hintLines * get_line_height(hintFont)) or 0

    local titleHeight = get_line_height(titleFont)
    local buttonHeight = 46

    local panelHeight = padding + titleHeight
    if hasMessage then
        panelHeight = panelHeight + 14 + messageHeight
    end
    panelHeight = panelHeight + 24 + buttonHeight
    if hasHint then
        panelHeight = panelHeight + 12 + hintHeight
    end
    panelHeight = panelHeight + padding

    panelWidth = math.min(panelWidth, screenWidth - padding * 2)
    panelHeight = math.min(panelHeight, screenHeight - padding * 2)

    local panelX = (screenWidth - panelWidth) * 0.5
    local panelY = (screenHeight - panelHeight) * 0.5

    love.graphics.push("all")
    love.graphics.origin()

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    if window_colors.shadow then
        love.graphics.setColor(window_colors.shadow)
        love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth, panelHeight, cornerRadius, cornerRadius)
    end

    love.graphics.setColor(window_colors.background or { 0.02, 0.02, 0.04, 0.95 })
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    love.graphics.setColor(window_colors.border or { 0.1, 0.1, 0.15, 0.8 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX + 1, panelY + 1, panelWidth - 2, panelHeight - 2, cornerRadius, cornerRadius)

    local textAreaX = panelX + (panelWidth - innerWidth) * 0.5
    local currentY = panelY + padding

    love.graphics.setFont(titleFont)
    love.graphics.setColor(window_colors.title_text or text_colors.heading or { 1, 1, 1, 1 })
    love.graphics.printf(state.title or "Ship Destroyed", textAreaX, currentY, innerWidth, "center")
    currentY = currentY + titleHeight

    if hasMessage and messageHeight > 0 then
        currentY = currentY + 14
        love.graphics.setFont(bodyFont)
        love.graphics.setColor(window_colors.text or text_colors.body or { 0.8, 0.8, 0.85, 1 })
        love.graphics.printf(message, textAreaX, currentY, innerWidth, "center")
        currentY = currentY + messageHeight
    end

    currentY = currentY + 24
    local buttonWidth = math.min(240, innerWidth)
    local buttonX = panelX + (panelWidth - buttonWidth) * 0.5
    local buttonY = currentY
    local mouseX, mouseY = love.mouse.getPosition()
    local isMouseDown = love.mouse.isDown(1)
    local hovered = mouseX >= buttonX and mouseX <= buttonX + buttonWidth and mouseY >= buttonY and mouseY <= buttonY + buttonHeight

    local buttonColor = window_colors.button or { 0.05, 0.05, 0.08, 1 }
    if hovered then
        buttonColor = window_colors.button_hover or { 0.15, 0.15, 0.2, 1 }
    end

    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, cornerRadius, cornerRadius)

    love.graphics.setColor(window_colors.border or { 0.1, 0.1, 0.15, 0.9 })
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, cornerRadius, cornerRadius)

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(window_colors.title_text or text_colors.heading or { 1, 1, 1, 1 })
    love.graphics.printf(state.buttonLabel or "Respawn", buttonX, buttonY + (buttonHeight - bodyFont:getHeight()) * 0.5, buttonWidth, "center")

    currentY = currentY + buttonHeight
    state.buttonHovered = hovered

    if hasHint and hintHeight > 0 then
        currentY = currentY + 12
        love.graphics.setFont(hintFont)
        love.graphics.setColor(window_colors.muted or text_colors.muted or { 0.6, 0.6, 0.68, 1 })
        love.graphics.printf(hint, textAreaX, currentY, innerWidth, "center")
    end

    love.graphics.pop()

    local justPressed = isMouseDown and not state._was_mouse_down
    if justPressed and hovered and context then
        context.respawnRequested = true
    end
    state._was_mouse_down = isMouseDown

    if context and context.uiInput then
        context.uiInput.mouseCaptured = true
        context.uiInput.keyboardCaptured = true
    end

    return true
end

return death_window
