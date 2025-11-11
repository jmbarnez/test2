local constants = require("src.constants.game")
---@diagnostic disable-next-line: undefined-global
local love = love

local palette = {
    shadow = { 0, 0, 0, 0.82 },
    overlay = { 0.02, 0.03, 0.05, 0.78 },
    surface_deep = { 0.04, 0.05, 0.07, 0.97 },
    surface_subtle = { 0.08, 0.09, 0.12, 0.95 },
    surface_top = { 0.12, 0.14, 0.18, 0.96 },
    border = { 0.22, 0.28, 0.36, 0.88 },
    accent = { 0.46, 0.64, 0.72, 1 },
    accent_alt = { 0.38, 0.52, 0.58, 1 },
    accent_glow = { 0.3, 0.54, 0.6, 0.14 },
    accent_warning = { 0.85, 0.42, 0.38, 1 },
    button_base = { 0.16, 0.2, 0.26, 1 },
    button_hover = { 0.22, 0.27, 0.34, 1 },
    button_active = { 0.28, 0.34, 0.42, 1 },
    text_heading = { 0.85, 0.89, 0.93, 1 },
    text_body = { 0.7, 0.76, 0.8, 1 },
    text_muted = { 0.46, 0.52, 0.58, 1 },
    tooltip_background = { 0.08, 0.09, 0.12, 0.94 },
    tooltip_border = { 0.32, 0.44, 0.52, 0.9 },
    tooltip_shadow = { 0, 0, 0, 0.5 },
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
    window_margin = 48,
    window_padding = 24,
    window_corner_radius = 0,
    window_shadow_offset = 0,
    window_glow_extra = 0,
    button_corner_radius = 0,
    slot_size = 58,
    slot_padding = 8,
    slot_text_height = 16,
    tooltip_padding = 12,
    tooltip_max_width = 260,
    tooltip_offset_x = 18,
    tooltip_offset_y = 18,
    tooltip_shadow_offset = 0,
    tooltip_line_spacing = 3,
}

local components = {}

components.window = {
    colors = {
        shadow = palette.shadow,
        background = palette.surface_deep,
        border = palette.border,
        top_bar = palette.surface_top,
        bottom_bar = palette.surface_top,
        title_text = palette.text_heading,
        text = palette.text_body,
        muted = palette.text_muted,
        row_alternate = { 0.09, 0.11, 0.14, 0.32 },
        row_hover = { 0.2, 0.26, 0.32, 0.28 },
        progress_background = palette.surface_subtle,
        progress_fill = palette.accent,
        warning = palette.accent_warning,
        accent = palette.accent,
        accent_secondary = palette.accent_alt,
        button = palette.button_base,
        button_hover = palette.button_hover,
        button_active = palette.button_active,
        icon_background = { 0.09, 0.11, 0.16, 0.96 },
        icon_border = { 0.32, 0.46, 0.68, 0.75 },
        slot_background = { 0.06, 0.07, 0.1, 0.98 },
        slot_border = { 0.26, 0.38, 0.56, 0.7 },
        close_button = { 0.24, 0.34, 0.52, 1 },
        close_button_hover = palette.accent_warning,
        glow = palette.accent_glow,
        input_background = { 0.12, 0.15, 0.22, 0.96 },
        caret = palette.accent,
        currency_icon_base = palette.accent,
        currency_icon_highlight = palette.accent_alt,
        currency_icon_border = palette.border,
        currency_icon_symbol = palette.text_heading,
    },
    metrics = {
        top_bar_height = 28,
        bottom_bar_height = 28,
        close_button_size = 12,
    },
}

components.text = {
    colors = {
        heading = palette.text_heading,
        body = palette.text_body,
        muted = palette.text_muted,
        warning = palette.accent_warning,
        accent = palette.accent,
    },
}

local window_colors = components.window.colors

components.hud = {
    colors = {
        health_border = { 0.12, 0.16, 0.22, 1 },
        health_fill = palette.accent,
        minimap_background = { 0.07, 0.08, 0.12, 0.94 },
        minimap_border = palette.border,
        minimap_player = palette.accent,
        minimap_teammate = palette.accent_alt,
        minimap_asteroid = { 0.58, 0.58, 0.68, 0.78 },
        minimap_ship = palette.accent_warning,
        diagnostics = palette.text_heading,
        status_panel = palette.surface_deep,
        status_shadow = { 0, 0, 0, 0 },
        status_border = palette.border,
        status_bar_background = palette.surface_subtle,
        status_text = palette.text_heading,
        status_muted = palette.text_muted,
        hull_fill = palette.accent_warning,
        shield_fill = palette.accent,
        energy_fill = palette.accent_alt,
    },
}

components.map = {
    colors = {
        overlay = palette.overlay,
        background = palette.surface_deep,
        border = palette.border,
        grid = { 0.24, 0.28, 0.34, 0.35 },
        bounds = palette.accent,
        player = palette.accent,
        teammate = palette.accent_alt,
        enemy = palette.accent_warning,
        asteroid = { 0.58, 0.58, 0.68, 0.78 },
        legend_heading = palette.text_heading,
        legend_text = palette.text_body,
        legend_muted = palette.text_muted,
    },
}

components.tooltip = {
    colors = {
        background = palette.tooltip_background,
        border = palette.tooltip_border,
        shadow = palette.tooltip_shadow,
        heading = palette.text_heading,
        text = palette.text_body,
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
    map = components.map.colors,
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
    local buttonHeight = options.button_height or options.buttonHeight or 28
    local buttonWidthMax = options.button_width or options.buttonWidth or 100

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

    love.graphics.setColor(windowColors.background or { 0.067, 0.067, 0.067, 1 })
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)

    love.graphics.setColor(windowColors.border or { 0.25, 0.25, 0.25, 1 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 0.5, panelY + 0.5, panelWidth - 1, panelHeight - 1)

    local titleBarHeight = 26
    love.graphics.setColor(windowColors.top_bar or { 0, 0, 0.5, 1 })
    love.graphics.rectangle("fill", panelX + 3, panelY + 3, panelWidth - 6, titleBarHeight)

    local textAreaX = panelX + (panelWidth - innerWidth) * 0.5
    local currentY = panelY + padding

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(windowColors.title_text or { 1, 1, 1, 1 })
    love.graphics.printf(title, textAreaX, currentY, innerWidth, "center")
    currentY = currentY + titleHeight

    if hasMessage and messageHeight > 0 then
        currentY = currentY + 14
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(windowColors.text or { 0.75, 0.75, 0.75, 1 })
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

        local buttonColor = windowColors.button or { 0.75, 0.75, 0.75, 1 }
        if buttonHovered then
            buttonColor = windowColors.button_hover or { 0.85, 0.85, 0.85, 1 }
        end

        love.graphics.setColor(buttonColor)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight)

        love.graphics.setColor(windowColors.border or { 0.18, 0.22, 0.28, 1 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX + 0.5, buttonY + 0.5, buttonWidth - 1, buttonHeight - 1)
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
