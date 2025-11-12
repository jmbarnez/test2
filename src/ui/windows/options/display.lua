-- Display Settings: Resolution, fullscreen, vsync, and FPS limit configuration
-- Handles window mode changes and display-related settings

local theme = require("src.ui.theme")
local dropdown = require("src.ui.components.dropdown")
local UIStateManager = require("src.ui.state_manager")
local runtime_settings = require("src.settings.runtime")

---@diagnostic disable-next-line: undefined-global
local love = love

local DisplaySettings = {}

-- Available resolutions
local RESOLUTIONS = {
    { width = 1920, height = 1080, label = "1920 x 1080" },
    { width = 1600, height = 900, label = "1600 x 900" },
    { width = 1366, height = 768, label = "1366 x 768" },
    { width = 1280, height = 720, label = "1280 x 720" },
    { width = 1024, height = 768, label = "1024 x 768" },
    { width = 800, height = 600, label = "800 x 600" },
}

-- FPS limit options
local FPS_LIMIT_OPTIONS = {
    { value = 0, label = "Unlimited" },
    { value = 30 },
    { value = 45 },
    { value = 60 },
    { value = 75 },
    { value = 90 },
    { value = 120 },
    { value = 144 },
    { value = 165 },
    { value = 240 },
    { value = 360 },
}

--- Formats a resolution object for display
---@param res table|string|nil The resolution
---@return string The formatted label
local function format_resolution_label(res)
    if type(res) ~= "table" then
        return tostring(res or "")
    end

    if res.label then
        return res.label
    end

    if res.width and res.height then
        return string.format("%d x %d", res.width, res.height)
    end

    return tostring(res)
end

--- Formats an FPS option for display
---@param option table|number|nil The FPS option
---@return string The formatted label
local function format_fps_option(option)
    if type(option) ~= "table" then
        local value = tonumber(option)
        if value and value > 0 then
            return string.format("%d FPS", value)
        end
        return "Unlimited"
    end

    if option.label then
        return option.label
    end

    local value = tonumber(option.value)
    if value and value > 0 then
        return string.format("%d FPS", value)
    end

    return "Unlimited"
end

--- Resolves resolution index from width/height
---@param width number|nil The width
---@param height number|nil The height
---@return number|nil The resolution index
function DisplaySettings.resolveResolutionIndex(width, height)
    if not (width and height) then
        return nil
    end
    for index, res in ipairs(RESOLUTIONS) do
        if res.width == width and res.height == height then
            return index
        end
    end
    return nil
end

--- Resolves FPS index from value
---@param value number The FPS value
---@return number|nil The FPS option index
local function resolve_fps_index(value)
    local target = tonumber(value) or 0
    for index, option in ipairs(FPS_LIMIT_OPTIONS) do
        local optionValue = tonumber(option.value) or 0
        if optionValue == target then
            return index
        end
    end
    return nil
end

--- Applies window mode flags
---@param settings table The settings table
---@param context table|nil Optional context for resize callback
function DisplaySettings.applyWindowFlags(settings, context)
    if not (love.window and love.window.setMode and love.window.getMode) then
        return
    end

    local width = settings.windowWidth
    local height = settings.windowHeight
    if not (width and height) then
        width, height = love.window.getMode()
    end

    local flags = {}
    local currentFlags = settings.flags or select(3, love.window.getMode())
    if currentFlags then
        for k, v in pairs(currentFlags) do
            flags[k] = v
        end
    end

    flags.fullscreen = settings.fullscreen
    flags.vsync = not not settings.vsync

    if love.window.setMode(width, height, flags) then
        settings.flags = flags
        settings.windowWidth = width
        settings.windowHeight = height
        settings.resolutionIndex = DisplaySettings.resolveResolutionIndex(width, height) or settings.resolutionIndex

        runtime_settings.set_vsync_enabled(flags.vsync)

        if context then
            if type(context.resize) == "function" then
                context:resize(width, height)
            else
                UIStateManager.onResize(context, width, height)
            end
        end
    end
end

--- Applies FPS limit
---@param settings table The settings table
function DisplaySettings.applyFrameLimit(settings)
    settings.maxFps = math.max(0, tonumber(settings.maxFps) or 0)
    runtime_settings.set_max_fps(settings.maxFps)
end

--- Draws a toggle switch
---@param fonts table Font table from theme
---@param label string The toggle label
---@param rect table The toggle rectangle {x, y, w, h}
---@param isOn boolean Whether the toggle is on
local function draw_toggle(fonts, label, rect, isOn)
    local windowColors = theme.colors.window or {}
    local borderColor = windowColors.border or { 0.12, 0.18, 0.28, 0.9 }
    local fillOff = windowColors.button or { 0.06, 0.07, 0.1, 1 }
    local fillOn = windowColors.accent or { 0.2, 0.55, 0.95, 1 }
    local textColor = windowColors.text or { 0.85, 0.85, 0.9, 1 }
    local knobColor = { 0.96, 0.97, 0.98, 1 }

    love.graphics.setFont(fonts.body)
    love.graphics.setColor(textColor)
    love.graphics.print(label, rect.x, rect.y - (fonts.body:getHeight() + 6))

    love.graphics.setColor(isOn and fillOn or fillOff)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, rect.h * 0.5, rect.h * 0.5)

    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1, rect.h * 0.5, rect.h * 0.5)

    local knobRadius = rect.h * 0.4
    local knobPadding = rect.h * 0.2
    local knobX = isOn and (rect.x + rect.w - knobPadding - knobRadius) or (rect.x + knobPadding + knobRadius)
    love.graphics.setColor(knobColor)
    love.graphics.circle("fill", knobX, rect.y + rect.h * 0.5, knobRadius)
end

--- Renders the display settings section
---@param params table {fonts, settings, state, viewportX, viewportY, cursorY, columnWidth, mouseX, mouseY, refs}
---@return number The updated cursorY position
function DisplaySettings.render(params)
    local fonts = params.fonts
    local settings = params.settings
    local state = params.state
    local viewportX = params.viewportX
    local viewportY = params.viewportY
    local cursorY = params.cursorY
    local columnWidth = params.columnWidth
    local mouseX = params.mouseX
    local mouseY = params.mouseY
    local refs = params.refs

    local windowColors = theme.colors.window or {}
    local headingColor = windowColors.title_text or { 0.9, 0.92, 0.96, 1 }
    local textColor = windowColors.text or { 0.85, 0.85, 0.9, 1 }

    -- Heading
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(headingColor)
    love.graphics.print("Display", viewportX, viewportY + cursorY)
    cursorY = cursorY + fonts.title:getHeight() + 12

    -- Resolution dropdown
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(textColor)
    love.graphics.print("Window Resolution", viewportX, viewportY + cursorY)
    cursorY = cursorY + fonts.body:getHeight() + 12

    local dropdownHeight = 32
    local dropdownRect = {
        x = viewportX,
        y = viewportY + cursorY,
        w = columnWidth,
        h = dropdownHeight,
    }

    local dropdownState = state.resolutionDropdown
    local currentIndex = DisplaySettings.resolveResolutionIndex(settings.windowWidth, settings.windowHeight) or settings.resolutionIndex
    local selectedLabel = "Select resolution"
    if currentIndex and RESOLUTIONS[currentIndex] then
        selectedLabel = format_resolution_label(RESOLUTIONS[currentIndex])
    elseif settings.windowWidth and settings.windowHeight then
        selectedLabel = string.format("%d x %d", settings.windowWidth, settings.windowHeight)
    end

    local dropdownHeightTotal = dropdown.measure {
        state = dropdownState,
        items = RESOLUTIONS,
        selected_index = currentIndex,
        base_height = dropdownHeight,
        item_height = dropdownHeight,
    }

    dropdown.render {
        rect = dropdownRect,
        state = dropdownState,
        items = RESOLUTIONS,
        selected_index = currentIndex,
        selected_label = selectedLabel,
        base_height = dropdownHeight,
        item_height = dropdownHeight,
        fonts = fonts,
        placeholder = "Select resolution",
        label_formatter = format_resolution_label,
        input = {
            x = mouseX,
            y = mouseY,
        },
    }

    cursorY = cursorY + dropdownHeightTotal + 24

    -- Fullscreen and VSync toggles
    local toggleWidth = 120
    local toggleHeight = 32
    local fullscreenRect = {
        x = viewportX,
        y = viewportY + cursorY,
        w = toggleWidth,
        h = toggleHeight,
    }
    local vsyncRect = {
        x = fullscreenRect.x + toggleWidth + 32,
        y = viewportY + cursorY,
        w = toggleWidth,
        h = toggleHeight,
    }

    draw_toggle(fonts, "Fullscreen", fullscreenRect, settings.fullscreen)
    draw_toggle(fonts, "VSync", vsyncRect, not not settings.vsync)
    refs._fullscreenRect = fullscreenRect
    refs._vsyncRect = vsyncRect

    cursorY = cursorY + toggleHeight + 24

    -- FPS Limit dropdown
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(textColor)
    love.graphics.print("Frame Limit", viewportX, viewportY + cursorY)
    cursorY = cursorY + fonts.body:getHeight() + 12

    local fpsDropdownRect = {
        x = viewportX,
        y = viewportY + cursorY,
        w = columnWidth,
        h = dropdownHeight,
    }

    local fpsDropdownState = state.fpsDropdown
    local fpsIndex = resolve_fps_index(settings.maxFps) or 1
    local fpsLabel
    if FPS_LIMIT_OPTIONS[fpsIndex] then
        fpsLabel = format_fps_option(FPS_LIMIT_OPTIONS[fpsIndex])
    else
        fpsLabel = format_fps_option(settings.maxFps)
    end

    local fpsDropdownHeightTotal = dropdown.measure {
        state = fpsDropdownState,
        items = FPS_LIMIT_OPTIONS,
        selected_index = fpsIndex,
        base_height = dropdownHeight,
        item_height = dropdownHeight,
    }

    dropdown.render {
        rect = fpsDropdownRect,
        state = fpsDropdownState,
        items = FPS_LIMIT_OPTIONS,
        selected_index = fpsIndex,
        selected_label = fpsLabel,
        base_height = dropdownHeight,
        item_height = dropdownHeight,
        fonts = fonts,
        placeholder = "Unlimited",
        label_formatter = format_fps_option,
        input = {
            x = mouseX,
            y = mouseY,
        },
    }
    refs._fpsDropdownRect = fpsDropdownRect

    cursorY = cursorY + fpsDropdownHeightTotal

    return cursorY
end

--- Handles mouse interaction for display settings
---@param state table The options UI state
---@param settings table The settings table
---@param context table The gameplay context
---@param mouseX number Mouse X position
---@param mouseY number Mouse Y position
---@param justPressed boolean Whether mouse was just pressed
---@return boolean Whether anything was handled
function DisplaySettings.handleInteraction(state, settings, context, mouseX, mouseY, justPressed)
    if not justPressed then
        return false
    end

    local handled = false

    local function point_in_rect(x, y, rect)
        return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
    end

    local function close_resolution_dropdown()
        if state.resolutionDropdown then
            state.resolutionDropdown.open = false
        end
        state.resolutionDropdownOpen = false
    end

    local function close_fps_dropdown()
        if state.fpsDropdown then
            state.fpsDropdown.open = false
        end
        state.fpsDropdownOpen = false
    end

    -- Handle resolution dropdown
    if state.resolutionDropdown then
        local dropdownResult = dropdown.handle_mouse(state.resolutionDropdown, {
            x = mouseX,
            y = mouseY,
            just_pressed = justPressed,
        })

        if dropdownResult then
            handled = handled or dropdownResult.consumed

            if dropdownResult.open ~= nil then
                state.resolutionDropdownOpen = not not dropdownResult.open
                if state.resolutionDropdownOpen then
                    close_fps_dropdown()
                end
            else
                state.resolutionDropdownOpen = state.resolutionDropdown and state.resolutionDropdown.open or false
            end

            if dropdownResult.selected_index then
                local selected = RESOLUTIONS[dropdownResult.selected_index]
                if selected then
                    if settings.fullscreen then
                        settings.fullscreen = false
                    end
                    settings.windowWidth = selected.width
                    settings.windowHeight = selected.height
                    settings.resolutionIndex = dropdownResult.selected_index
                    close_resolution_dropdown()
                    close_fps_dropdown()
                    DisplaySettings.applyWindowFlags(settings, context)
                    DisplaySettings.applyFrameLimit(settings)
                end
                handled = true
            elseif dropdownResult.toggled then
                handled = true
            end
        end
    end

    -- Handle FPS dropdown
    if not handled and state.fpsDropdown then
        local fpsResult = dropdown.handle_mouse(state.fpsDropdown, {
            x = mouseX,
            y = mouseY,
            just_pressed = justPressed,
        })

        if fpsResult then
            handled = handled or fpsResult.consumed

            if fpsResult.open ~= nil then
                state.fpsDropdownOpen = not not fpsResult.open
                if state.fpsDropdownOpen then
                    close_resolution_dropdown()
                end
            else
                state.fpsDropdownOpen = state.fpsDropdown and state.fpsDropdown.open or false
            end

            if fpsResult.selected_index then
                local option = FPS_LIMIT_OPTIONS[fpsResult.selected_index]
                if option then
                    settings.maxFps = math.max(0, tonumber(option.value) or 0)
                    DisplaySettings.applyFrameLimit(settings)
                end
                close_fps_dropdown()
                handled = true
            elseif fpsResult.toggled then
                handled = true
            end
        end
    end

    -- Handle toggle buttons
    if not handled then
        if state._fullscreenRect and point_in_rect(mouseX, mouseY, state._fullscreenRect) then
            settings.fullscreen = not settings.fullscreen
            close_resolution_dropdown()
            close_fps_dropdown()
            DisplaySettings.applyWindowFlags(settings, context)
            DisplaySettings.applyFrameLimit(settings)
            handled = true
        elseif state._vsyncRect and point_in_rect(mouseX, mouseY, state._vsyncRect) then
            settings.vsync = not settings.vsync
            close_resolution_dropdown()
            close_fps_dropdown()
            DisplaySettings.applyWindowFlags(settings, context)
            DisplaySettings.applyFrameLimit(settings)
            handled = true
        end
    end

    return handled
end

--- Gets the available resolutions
---@return table The resolutions table
function DisplaySettings.getResolutions()
    return RESOLUTIONS
end

--- Gets the FPS limit options
---@return table The FPS options table
function DisplaySettings.getFpsOptions()
    return FPS_LIMIT_OPTIONS
end

return DisplaySettings
