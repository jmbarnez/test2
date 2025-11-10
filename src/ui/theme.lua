local constants = require("src.constants.game")
---@diagnostic disable-next-line: undefined-global
local love = love

local theme = {
    font_sizes = {
        title = 16,
        body = 13,
        small = 11,
        tiny = 9,
    },
    colors = {
        window = {
            shadow = { 0, 0, 0, 0.9 },
            background = { 0.02, 0.02, 0.04, 0.98 },
            border = { 0.08, 0.08, 0.12, 0.8 },
            top_bar = { 0.01, 0.01, 0.02, 1 },
            bottom_bar = { 0.01, 0.01, 0.02, 1 },
            title_text = { 0.85, 0.85, 0.9, 1 },
            text = { 0.75, 0.75, 0.8, 1 },
            muted = { 0.4, 0.4, 0.45, 1 },
            row_alternate = { 0.04, 0.04, 0.06, 0.5 },
            row_hover = { 0.06, 0.06, 0.1, 0.3 },
            progress_background = { 0.03, 0.03, 0.05, 1 },
            progress_fill = { 0.15, 0.4, 0.6, 1 },
            warning = { 0.7, 0.3, 0.3, 1 },
            accent = { 0.2, 0.5, 0.7, 1 },
            button = { 0.05, 0.05, 0.08, 1 },
            button_hover = { 0.08, 0.08, 0.12, 1 },
            icon_background = { 0.03, 0.03, 0.05, 0.9 },
            icon_border = { 0.1, 0.1, 0.15, 0.6 },
            slot_background = { 0.02, 0.02, 0.04, 0.95 },
            slot_border = { 0.08, 0.08, 0.12, 0.5 },
            close_button = { 0.5, 0.5, 0.55, 1 },
            close_button_hover = { 0.8, 0.3, 0.3, 1 },
            glow = { 0.2, 0.5, 0.7, 0.2 },
        },
        text = {
            heading = { 0.85, 0.85, 0.9, 1 },
            body = { 0.75, 0.75, 0.8, 1 },
            muted = { 0.4, 0.4, 0.45, 1 },
            warning = { 0.7, 0.3, 0.3, 1 },
        },
        hud = {
            health_border = { 0, 0, 0, 1 },
            health_fill = { 0.15, 0.6, 0.3, 0.9 },
            minimap_background = { 0, 0, 0, 0.8 },
            minimap_border = { 0.15, 0.15, 0.2, 1 },
            minimap_player = { 0, 0.8, 0, 1 },
            minimap_teammate = { 0.2, 0.6, 1, 1 },
            minimap_asteroid = { 0.4, 0.35, 0.3, 0.7 },
            minimap_ship = { 0.8, 0.2, 0.2, 1 },
            diagnostics = { 0.7, 0.7, 0.75, 1 },
        },
        tooltip = {
            background = { 0.03, 0.03, 0.05, 0.96 },
            border = { 0.2, 0.5, 0.7, 0.9 },
            shadow = { 0, 0, 0, 0.4 },
            heading = { 0.9, 0.9, 0.95, 1 },
            text = { 0.78, 0.78, 0.82, 1 },
        },
    },
    spacing = {
        window_margin = 50,
        window_padding = 20,
        window_corner_radius = 2,
        window_shadow_offset = 1,
        window_glow_extra = 2,
        slot_size = 56,
        slot_padding = 4,
        slot_text_height = 16,
        tooltip_padding = 8,
        tooltip_max_width = 240,
        tooltip_offset_x = 18,
        tooltip_offset_y = 16,
        tooltip_shadow_offset = 4,
        tooltip_line_spacing = 2,
    },
    window = {
        top_bar_height = 24,
        bottom_bar_height = 28,
        close_button_size = 14,
    },
}

local function get_line_height(font)
    if not font then
        return 0
    end
    return font:getHeight() * font:getLineHeight()
end

local function load_font(size)
    local font_path = constants.render and constants.render.fonts and constants.render.fonts.primary
    if font_path then
        local ok, font = pcall(love.graphics.newFont, font_path, size)
        if ok and font then
            return font
        end
    end
    return love.graphics.newFont(size)
end

function theme.get_fonts()
    if theme._fonts then
        return theme._fonts
    end

    theme._fonts = {
        title = load_font(theme.font_sizes.title),
        body = load_font(theme.font_sizes.body),
        small = load_font(theme.font_sizes.small),
        tiny = load_font(theme.font_sizes.tiny),
    }

    return theme._fonts
end

function theme.draw_modal_window(state, fonts, options)
    options = options or {}
    fonts = fonts or theme.get_fonts()

    local windowColors = theme.colors.window or {}
    local textColors = theme.colors.text or {}
    local spacing = theme.spacing or {}

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local overlayColor = options.overlay_color or options.overlayColor or { 0, 0, 0, 0.75 }
    local padding = options.padding or spacing.window_padding or 20
    local cornerRadius = options.corner_radius or options.cornerRadius or spacing.window_corner_radius or 6
    local buttonHeight = options.button_height or options.buttonHeight or 46
    local buttonWidthMax = options.button_width or options.buttonWidth or 240

    local defaultTitle = options.defaultTitle or options.title or state and state.title or ""
    local title = options.title or defaultTitle
    local message = options.message or (state and state.message) or ""
    local hint = options.hint or (state and state.hint) or ""
    local showButton = options.showButton ~= false
    local baseButtonLabel = options.buttonLabel or options.defaultButtonLabel or (state and state.buttonLabel) or "OK"
    local hoverField = options.hoverField or "buttonHovered"

    local maxPanelWidth = math.max(240, screenWidth - padding * 2)
    local panelWidth = math.min(options.max_width or options.maxWidth or 440, maxPanelWidth)
    local innerWidth = math.max(160, panelWidth - padding * 2)

    local titleHeight = get_line_height(fonts.title)

    local hasMessage = message:match("%S") ~= nil
    local messageHeight = 0
    if hasMessage then
        local _, wrapped = fonts.body:getWrap(message, innerWidth)
        messageHeight = #wrapped * get_line_height(fonts.body)
    end

    local hasHint = hint:match("%S") ~= nil
    local hintHeight = 0
    if hasHint then
        local _, wrappedHint = fonts.small:getWrap(hint, innerWidth)
        hintHeight = #wrappedHint * get_line_height(fonts.small)
    end

    local panelHeight = padding + titleHeight
    if hasMessage and messageHeight > 0 then
        panelHeight = panelHeight + 14 + messageHeight
    end
    local buttonHeightSection = showButton and (24 + buttonHeight) or 0
    panelHeight = panelHeight + buttonHeightSection
    if hasHint and hintHeight > 0 then
        panelHeight = panelHeight + 12 + hintHeight
    end
    panelHeight = panelHeight + padding

    panelWidth = math.min(panelWidth, screenWidth - padding * 2)
    panelHeight = math.min(panelHeight, screenHeight - padding * 2)

    local panelX = (screenWidth - panelWidth) * 0.5
    local panelY = (screenHeight - panelHeight) * 0.5

    love.graphics.push("all")
    love.graphics.origin()

    love.graphics.setColor(overlayColor)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    if windowColors.shadow then
        love.graphics.setColor(windowColors.shadow)
        love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth, panelHeight, cornerRadius, cornerRadius)
    end

    love.graphics.setColor(windowColors.background or { 0.02, 0.02, 0.04, 0.95 })
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    love.graphics.setColor(windowColors.border or { 0.1, 0.1, 0.15, 0.8 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX + 1, panelY + 1, panelWidth - 2, panelHeight - 2, cornerRadius, cornerRadius)

    local textAreaX = panelX + (panelWidth - innerWidth) * 0.5
    local currentY = panelY + padding

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(windowColors.title_text or textColors.heading or { 0.85, 0.85, 0.9, 1 })
    love.graphics.printf(title, textAreaX, currentY, innerWidth, "center")
    currentY = currentY + titleHeight

    if hasMessage and messageHeight > 0 then
        currentY = currentY + 14
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(windowColors.text or textColors.body or { 0.75, 0.75, 0.8, 1 })
        love.graphics.printf(message, textAreaX, currentY, innerWidth, "center")
        currentY = currentY + messageHeight
    end

    local buttonRect
    local buttonHovered = false
    local buttonActivated = false

    if showButton then
        currentY = currentY + 24
        local buttonWidth = math.min(buttonWidthMax, innerWidth)
        local buttonX = panelX + (panelWidth - buttonWidth) * 0.5
        local buttonY = currentY
        buttonRect = {
            x = buttonX,
            y = buttonY,
            width = buttonWidth,
            height = buttonHeight,
        }

        local mouseX, mouseY = nil, nil
        if love.mouse and love.mouse.getPosition then
            mouseX, mouseY = love.mouse.getPosition()
        end

        if mouseX and mouseY then
            buttonHovered = mouseX >= buttonX and mouseX <= buttonX + buttonWidth and mouseY >= buttonY and mouseY <= buttonY + buttonHeight
        end

        local isMouseDown = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
        local justPressed = isMouseDown and not (state and state._was_mouse_down)
        if state then
            state._was_mouse_down = isMouseDown
        end

        if buttonHovered and justPressed then
            buttonActivated = true
        end

        local buttonColor = windowColors.button or { 0.05, 0.05, 0.08, 1 }
        if buttonHovered then
            buttonColor = windowColors.button_hover or { 0.08, 0.08, 0.12, 1 }
        end

        love.graphics.setColor(buttonColor)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, cornerRadius, cornerRadius)

        love.graphics.setColor(windowColors.border or { 0.1, 0.1, 0.15, 0.9 })
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, cornerRadius, cornerRadius)

        love.graphics.setFont(fonts.body)
        love.graphics.setColor(windowColors.title_text or textColors.heading or { 0.85, 0.85, 0.9, 1 })
        love.graphics.printf(baseButtonLabel, buttonX, buttonY + (buttonHeight - fonts.body:getHeight()) * 0.5, buttonWidth, "center")

        currentY = currentY + buttonHeight
    else
        if state then
            state._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
        end
    end

    if hasHint and hintHeight > 0 then
        currentY = currentY + 12
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(windowColors.muted or textColors.muted or { 0.4, 0.4, 0.45, 1 })
        love.graphics.printf(hint, textAreaX, currentY, innerWidth, "center")
    end

    love.graphics.pop()

    if state then
        state[hoverField] = showButton and buttonHovered or false
    end

    return {
        panel = {
            x = panelX,
            y = panelY,
            width = panelWidth,
            height = panelHeight,
        },
        content = {
            x = textAreaX,
            width = innerWidth,
        },
        buttonRect = buttonRect,
        buttonHovered = buttonHovered,
        buttonActivated = buttonActivated,
        showButton = showButton,
    }
end

return theme
