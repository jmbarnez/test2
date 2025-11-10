local constants = require("src.constants.game")
---@diagnostic disable-next-line: undefined-global
local love = love

local palette = {
    shadow = { 0, 0, 0, 0.98 },
    overlay = { 0, 0, 0, 0.88 },
    surface_deep = { 0.008, 0.008, 0.012, 1 },
    surface_subtle = { 0.015, 0.015, 0.02, 1 },
    surface_top = { 0.006, 0.008, 0.012, 1 },
    border = { 0.18, 0.22, 0.28, 1 },
    accent = { 0.18, 0.58, 0.88, 1 },
    accent_glow = { 0.18, 0.58, 0.88, 0.12 },
    accent_warning = { 0.88, 0.28, 0.28, 1 },
    button_base = { 0.035, 0.045, 0.065, 1 },
    button_hover = { 0.065, 0.095, 0.14, 1 },
    text_heading = { 0.92, 0.95, 1, 1 },
    text_body = { 0.75, 0.78, 0.82, 1 },
    text_muted = { 0.42, 0.45, 0.5, 1 },
    tooltip_background = { 0.012, 0.015, 0.022, 0.99 },
    tooltip_border = { 0.18, 0.58, 0.88, 0.95 },
    tooltip_shadow = { 0, 0, 0, 0.6 },
}

local typography = {
    sizes = {
        title = 16,
        body = 13,
        small = 11,
        tiny = 9,
    },
}

local spacing = {
    window_margin = 50,
    window_padding = 20,
    window_corner_radius = 0,
    window_shadow_offset = 3,
    window_glow_extra = 2,
    slot_size = 56,
    slot_padding = 6,
    slot_text_height = 16,
    tooltip_padding = 10,
    tooltip_max_width = 240,
    tooltip_offset_x = 18,
    tooltip_offset_y = 16,
    tooltip_shadow_offset = 5,
    tooltip_line_spacing = 3,
}

local components = {
    window = {
        colors = {
            shadow = palette.shadow,
            background = palette.surface_deep,
            border = palette.border,
            top_bar = palette.surface_top,
            bottom_bar = palette.surface_top,
            title_text = palette.text_heading,
            text = palette.text_body,
            muted = palette.text_muted,
            row_alternate = { 0.015, 0.02, 0.03, 0.3 },
            row_hover = { 0.06, 0.08, 0.12, 0.2 },
            progress_background = palette.surface_subtle,
            progress_fill = { 0.12, 0.48, 0.78, 1 },
            warning = palette.accent_warning,
            accent = palette.accent,
            button = palette.button_base,
            button_hover = palette.button_hover,
            icon_background = { 0.015, 0.015, 0.025, 0.95 },
            icon_border = { 0.15, 0.2, 0.28, 0.75 },
            slot_background = { 0.012, 0.015, 0.022, 0.98 },
            slot_border = { 0.12, 0.16, 0.24, 0.65 },
            close_button = { 0.48, 0.52, 0.58, 1 },
            close_button_hover = palette.accent_warning,
            glow = palette.accent_glow,
            input_background = { 0.06, 0.07, 0.1, 1 },
        },
        metrics = {
            top_bar_height = 26,
            bottom_bar_height = 28,
            close_button_size = 12,
        },
    },
    text = {
        colors = {
            heading = palette.text_heading,
            body = palette.text_body,
            muted = palette.text_muted,
            warning = palette.accent_warning,
        },
    },
    hud = {
        colors = {
            health_border = { 0, 0, 0, 1 },
            health_fill = { 0.12, 0.68, 0.42, 0.94 },
            minimap_background = { 0, 0, 0, 0.88 },
            minimap_border = { 0.15, 0.2, 0.28, 1 },
            minimap_player = { 0, 0.88, 0.32, 1 },
            minimap_teammate = { 0.18, 0.58, 0.98, 1 },
            minimap_asteroid = { 0.4, 0.38, 0.35, 0.78 },
            minimap_ship = { 0.88, 0.22, 0.22, 1 },
            diagnostics = { 0.68, 0.72, 0.78, 1 },
        },
    },
    tooltip = {
        colors = {
            background = palette.tooltip_background,
            border = palette.tooltip_border,
            shadow = palette.tooltip_shadow,
            heading = palette.text_heading,
            text = { 0.75, 0.78, 0.85, 1 },
        },
    },
}

local theme = {
    palette = palette,
    typography = typography,
    spacing = spacing,
    components = components,
}

theme.font_sizes = theme.typography.sizes
theme.colors = {
    window = components.window.colors,
    text = components.text.colors,
    hud = components.hud.colors,
    tooltip = components.tooltip.colors,
}
theme.window = components.window.metrics

theme.utils = theme.utils or {}
function theme.utils.set_color(color)
    if type(color) == "table" then
        love.graphics.setColor(
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            color[4] or 1
        )
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function theme.get_component(name)
    return theme.components[name]
end

function theme.get_colors(name)
    local component = theme.components[name]
    if component then
        return component.colors
    end
    return nil
end

function theme.get_spacing()
    return theme.spacing
end

function theme.get_typography()
    return theme.typography
end

function theme.apply_scale(scale)
    scale = tonumber(scale)
    if not scale or scale <= 0 or math.abs(scale - 1) < 1e-6 then
        return
    end

    for key, value in pairs(theme.font_sizes) do
        if type(value) == "number" then
            theme.font_sizes[key] = math.max(1, math.floor(value * scale + 0.5))
        end
    end

    for key, value in pairs(theme.spacing) do
        if type(value) == "number" then
            theme.spacing[key] = value * scale
        end
    end

    for _, component in pairs(theme.components) do
        if component.metrics then
            for key, value in pairs(component.metrics) do
                if type(value) == "number" then
                    component.metrics[key] = value * scale
                end
            end
        end
    end

    theme.window = theme.components.window.metrics
    theme._fonts = nil
end

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

    local overlayColor = options.overlay_color or options.overlayColor or { 0, 0, 0, 0.88 }
    local padding = options.padding or spacing.window_padding or 20
    local cornerRadius = 0
    local buttonHeight = options.button_height or options.buttonHeight or 44
    local buttonWidthMax = options.button_width or options.buttonWidth or 220

    local defaultTitle = options.defaultTitle or options.title or state and state.title or ""
    local title = options.title or defaultTitle
    local message = options.message or (state and state.message) or ""
    local hint = options.hint or (state and state.hint) or ""
    local showButton = options.showButton ~= false
    local baseButtonLabel = options.buttonLabel or options.defaultButtonLabel or (state and state.buttonLabel) or "OK"
    local hoverField = options.hoverField or "buttonHovered"

    local maxPanelWidth = math.max(240, screenWidth - padding * 2)
    local panelWidth = math.min(options.max_width or options.maxWidth or 420, maxPanelWidth)
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
        love.graphics.rectangle("fill", panelX + 2, panelY + 2, panelWidth, panelHeight)
    end

    love.graphics.setColor(windowColors.background or { 0.008, 0.008, 0.012, 1 })
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)

    love.graphics.setColor(windowColors.border or { 0.18, 0.22, 0.28, 1 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 0.5, panelY + 0.5, panelWidth - 1, panelHeight - 1)

    local textAreaX = panelX + (panelWidth - innerWidth) * 0.5
    local currentY = panelY + padding

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(windowColors.title_text or textColors.heading or { 0.92, 0.95, 1, 1 })
    love.graphics.printf(title, textAreaX, currentY, innerWidth, "center")
    currentY = currentY + titleHeight

    if hasMessage and messageHeight > 0 then
        currentY = currentY + 14
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(windowColors.text or textColors.body or { 0.75, 0.78, 0.82, 1 })
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

        local buttonColor = windowColors.button or { 0.035, 0.045, 0.065, 1 }
        if buttonHovered then
            buttonColor = windowColors.button_hover or { 0.065, 0.095, 0.14, 1 }
        end

        love.graphics.setColor(buttonColor)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight)

        love.graphics.setColor(windowColors.border or { 0.18, 0.22, 0.28, 1 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX + 0.5, buttonY + 0.5, buttonWidth - 1, buttonHeight - 1)

        if buttonHovered and windowColors.accent then
            love.graphics.setColor(windowColors.accent)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", buttonX + 1.5, buttonY + 1.5, buttonWidth - 3, buttonHeight - 3)
        end

        love.graphics.setFont(fonts.body)
        love.graphics.setColor(windowColors.title_text or textColors.heading or { 0.92, 0.95, 1, 1 })
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
        love.graphics.setColor(windowColors.muted or textColors.muted or { 0.42, 0.45, 0.5, 1 })
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
