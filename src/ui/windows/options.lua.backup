local window = require("src.ui.components.window")
local UIStateManager = require("src.ui.state_manager")
local theme = require("src.ui.theme")
local dropdown = require("src.ui.components.dropdown")
local AudioManager = require("src.audio.manager")
local constants = require("src.constants.game")
local runtime_settings = require("src.settings.runtime")

---@diagnostic disable-next-line: undefined-global
local love = love

local RESOLUTIONS = {
    { width = 1920, height = 1080, label = "1920 x 1080" },
    { width = 1600, height = 900, label = "1600 x 900" },
    { width = 1366, height = 768, label = "1366 x 768" },
    { width = 1280, height = 720, label = "1280 x 720" },
    { width = 1024, height = 768, label = "1024 x 768" },
    { width = 800, height = 600, label = "800 x 600" },
}

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

local DEFAULT_MAX_FPS = math.max(0, (constants.window and constants.window.max_fps) or 0)

local SCROLLBAR_WIDTH = 10

local BINDING_ACTIONS = {
    { id = "moveLeft", label = "Move Left" },
    { id = "moveRight", label = "Move Right" },
    { id = "moveUp", label = "Move Up" },
    { id = "moveDown", label = "Move Down" },
    { id = "cycleWeaponPrev", label = "Cycle Weapon (Previous)" },
    { id = "cycleWeaponNext", label = "Cycle Weapon (Next)" },
    { id = "toggleCargo", label = "Toggle Cargo" },
    { id = "toggleMap", label = "Toggle Map" },
    { id = "toggleSkills", label = "Toggle Skills" },
    { id = "pause", label = "Pause / Back" },
}

local DEFAULT_KEYBINDINGS = {
    moveLeft = { "a", "left" },
    moveRight = { "d", "right" },
    moveUp = { "w", "up" },
    moveDown = { "s", "down" },
    cycleWeaponPrev = { "q" },
    cycleWeaponNext = { "e" },
    toggleCargo = { "tab" },
    toggleMap = { "m" },
    toggleSkills = { "k" },
    pause = { "escape" },
}

local STATIC_HOTKEYS = {
    { key = "F11", description = "Enable Fullscreen" },
}

local GLOBAL_FULLSCREEN_STATE = {}

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

local options_window = {}

local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
end

local function copy_bindings(source)
    local copy = {}
    for action, keys in pairs(source) do
        copy[action] = {}
        for i = 1, #keys do
            copy[action][i] = keys[i]
        end
    end
    return copy
end

local function resolve_resolution_index(width, height)
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

local function ensure_settings(state, context)
    local settings = context and context.settings or state.settings or {}

    state.settings = settings
    if context then
        context.settings = settings
    end

    settings.keybindings = settings.keybindings or copy_bindings(DEFAULT_KEYBINDINGS)
    for action, defaults in pairs(DEFAULT_KEYBINDINGS) do
        if type(settings.keybindings[action]) ~= "table" then
            settings.keybindings[action] = copy_bindings({ [action] = defaults })[action]
        end
    end

    if state.syncPending or not settings.masterVolume then
        state.syncPending = false

        settings.masterVolume = clamp01((love.audio and love.audio.getVolume and love.audio.getVolume()) or settings.masterVolume or 1)
        settings.musicVolume = clamp01(settings.musicVolume or settings.masterVolume)
        settings.sfxVolume = clamp01(settings.sfxVolume or settings.masterVolume)

        if love.window and love.window.getMode then
            local width, height, flags = love.window.getMode()
            settings.windowWidth = width
            settings.windowHeight = height
            settings.flags = settings.flags or {}
            for k, v in pairs(flags) do
                settings.flags[k] = v
            end
            settings.fullscreen = not not flags.fullscreen
            if type(flags.vsync) == "boolean" then
                settings.vsync = flags.vsync
            else
                settings.vsync = flags.vsync ~= 0
            end
        else
            settings.windowWidth = settings.windowWidth or 1600
            settings.windowHeight = settings.windowHeight or 900
            settings.flags = settings.flags or { fullscreen = false, vsync = 0 }
            settings.fullscreen = not not settings.flags.fullscreen
            local vs = settings.flags.vsync
            if type(vs) == "boolean" then
                settings.vsync = vs
            else
                settings.vsync = vs ~= 0
            end
        end
    else
        settings.fullscreen = not not settings.fullscreen
        if type(settings.vsync) == "boolean" then
            -- keep value
        else
            settings.vsync = settings.vsync ~= 0
        end
    end

    settings.masterVolume = clamp01(settings.masterVolume)
    settings.musicVolume = clamp01(settings.musicVolume)
    settings.sfxVolume = clamp01(settings.sfxVolume)
    settings.fullscreen = not not settings.fullscreen
    settings.vsync = not not settings.vsync
    settings.resolutionIndex = resolve_resolution_index(settings.windowWidth, settings.windowHeight) or settings.resolutionIndex or 2

    settings.flags = settings.flags or {}
    settings.flags.fullscreen = settings.fullscreen
    settings.flags.vsync = settings.vsync

    runtime_settings.set_vsync_enabled(settings.vsync)

    settings.maxFps = math.max(0, tonumber(settings.maxFps or DEFAULT_MAX_FPS) or 0)
    runtime_settings.set_max_fps(settings.maxFps)

    return settings
end

local function apply_volume(settings)
    if AudioManager and AudioManager.ensure_initialized then
        AudioManager.ensure_initialized()
        AudioManager.set_master_volume(settings.masterVolume or 1)
        AudioManager.set_music_volume(settings.musicVolume or settings.masterVolume or 1)
        AudioManager.set_sfx_volume(settings.sfxVolume or settings.masterVolume or 1)
    elseif love.audio and love.audio.setVolume then
        love.audio.setVolume(settings.masterVolume or 1)
    end
end

local function close_resolution_dropdown(state)
    if not state then
        return
    end

    if state.resolutionDropdown then
        state.resolutionDropdown.open = false
    end

    state.resolutionDropdownOpen = false
end

local function close_fps_dropdown(state)
    if not state then
        return
    end

    if state.fpsDropdown then
        state.fpsDropdown.open = false
    end

    state.fpsDropdownOpen = false
end

local function apply_window_flags(settings, context)
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
        settings.resolutionIndex = resolve_resolution_index(width, height) or settings.resolutionIndex

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

local function apply_frame_limit(settings)
    settings.maxFps = math.max(0, tonumber(settings.maxFps) or 0)
    runtime_settings.set_max_fps(settings.maxFps)
end

local function point_in_rect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function reset_scroll_interaction(state)
    if not state then
        return
    end

    state.draggingThumb = false
    state.draggingContent = false
    state.activeSlider = nil
end

local function get_binding_text(binding)
    if not binding or #binding == 0 then
        return "Unassigned"
    end
    return table.concat(binding, ", ")
end

local function draw_slider(fonts, label, rect, value, registry)
    local windowColors = theme.colors.window or {}
    local textColor = windowColors.text or { 0.85, 0.85, 0.9, 1 }
    local accentColor = windowColors.accent or { 0.2, 0.55, 0.95, 1 }
    local trackColor = windowColors.progress_background or { 0.06, 0.07, 0.1, 1 }
    local knobColor = windowColors.button or { 0.08, 0.08, 0.12, 1 }

    love.graphics.setFont(fonts.body)
    love.graphics.setColor(textColor)
    love.graphics.print(label, rect.x, rect.y - (fonts.body:getHeight() + 6))

    love.graphics.setColor(trackColor)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)

    love.graphics.setColor(accentColor)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w * value, rect.h, 4, 4)

    love.graphics.setColor(knobColor)
    local knobRadius = math.min(rect.h * 0.75, 8)
    love.graphics.circle("fill", rect.x + rect.w * value, rect.y + rect.h * 0.5, knobRadius)

    local percentText = string.format("%d%%", math.floor(value * 100 + 0.5))
    love.graphics.setFont(fonts.small)
    local percentWidth = fonts.small:getWidth(percentText)
    love.graphics.setColor(textColor)
    love.graphics.print(percentText, rect.x + rect.w - percentWidth, rect.y + rect.h + 4)

    registry[label] = rect
end

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

function options_window.draw(context)
    local state = context and context.optionsUI
    if not (state and state.visible) then
        return false
    end

    local fonts = theme.get_fonts()
    local settings = ensure_settings(state, context)

    state.resolutionDropdown = state.resolutionDropdown or dropdown.create_state()
    local resolutionDropdownState = state.resolutionDropdown
    state.resolutionDropdownOpen = resolutionDropdownState and resolutionDropdownState.open or false

    state.fpsDropdown = state.fpsDropdown or dropdown.create_state()
    local fpsDropdownState = state.fpsDropdown
    state.fpsDropdownOpen = fpsDropdownState and fpsDropdownState.open or false

    if context and context.uiInput then
        context.uiInput.mouseCaptured = true
        context.uiInput.keyboardCaptured = true
    end

    local windowColors = theme.colors.window or {}
    local textColor = windowColors.text or { 0.85, 0.85, 0.9, 1 }
    local headingColor = windowColors.title_text or { 0.9, 0.92, 0.96, 1 }

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mouseX, mouseY = love.mouse.getPosition()
    local isMouseDown = love.mouse.isDown(1)
    local justPressed = isMouseDown and not state._was_mouse_down
    state._was_mouse_down = isMouseDown

    love.graphics.push("all")
    love.graphics.origin()

    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local windowWidth = 620
    local windowHeight = 520
    local frame = window.draw_frame {
        x = (screenWidth - windowWidth) * 0.5,
        y = (screenHeight - windowHeight) * 0.5,
        width = windowWidth,
        height = windowHeight,
        title = state.title or "Options",
        fonts = fonts,
        state = state,
        input = {
            x = mouseX,
            y = mouseY,
            is_down = isMouseDown,
            just_pressed = justPressed,
        },
        show_close = true,
    }

    local contentFrame = frame.content_full or frame.content
    local viewportPaddingX = 20
    local viewportPaddingY = 16
    local viewportX = contentFrame.x + viewportPaddingX
    local viewportY = contentFrame.y + viewportPaddingY
    local scrollbarX = contentFrame.x + contentFrame.width - SCROLLBAR_WIDTH
    local viewportWidth = math.max(80, scrollbarX - viewportX)
    local viewportHeight = math.max(1, contentFrame.height - viewportPaddingY * 2)
    local columnWidth = math.max(60, viewportWidth - 20)

    local function layout_content(mode, params)
        local cursorY = params.startY or 0

        local function heading(text)
            if mode == "draw" then
                love.graphics.setFont(fonts.title)
                love.graphics.setColor(headingColor)
                love.graphics.print(text, viewportX, viewportY + cursorY)
                love.graphics.setColor(textColor)
            end
            cursorY = cursorY + fonts.title:getHeight() + 12
        end

        local sliderHeight = 10
        local sliderWidth = columnWidth

        local function add_slider(label, key)
            cursorY = cursorY + fonts.body:getHeight() + 6
            if mode == "draw" then
                draw_slider(fonts, label, {
                    x = viewportX,
                    y = viewportY + cursorY,
                    w = sliderWidth,
                    h = sliderHeight,
                }, settings[key], params.sliderRects)
            end
            cursorY = cursorY + sliderHeight + 40
        end

        heading("Audio")
        add_slider("Master Volume", "masterVolume")
        add_slider("Music Volume", "musicVolume")
        add_slider("Effects Volume", "sfxVolume")

        cursorY = cursorY + 6

        heading("Display")

        if mode == "draw" then
            love.graphics.setFont(fonts.body)
            love.graphics.print("Window Resolution", viewportX, viewportY + cursorY)
        end
        cursorY = cursorY + fonts.body:getHeight() + 12

        local dropdownHeight = 32
        local dropdownRect = {
            x = viewportX,
            y = viewportY + cursorY,
            w = columnWidth,
            h = dropdownHeight,
        }

        local dropdownState = resolutionDropdownState
        local currentIndex = resolve_resolution_index(settings.windowWidth, settings.windowHeight) or settings.resolutionIndex
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

        if mode == "draw" then
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
        end

        cursorY = cursorY + dropdownHeightTotal

        cursorY = cursorY + 24

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

        if mode == "draw" then
            draw_toggle(fonts, "Fullscreen", fullscreenRect, settings.fullscreen)
            draw_toggle(fonts, "VSync", vsyncRect, not not settings.vsync)
            params.refs._fullscreenRect = fullscreenRect
            params.refs._vsyncRect = vsyncRect
        end

        cursorY = cursorY + toggleHeight + 24

        if mode == "draw" then
            love.graphics.setFont(fonts.body)
            love.graphics.print("Frame Limit", viewportX, viewportY + cursorY)
        end
        cursorY = cursorY + fonts.body:getHeight() + 12

        local fpsDropdownRect = {
            x = viewportX,
            y = viewportY + cursorY,
            w = columnWidth,
            h = dropdownHeight,
        }

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

        if mode == "draw" then
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
            params.refs._fpsDropdownRect = fpsDropdownRect
        end

        cursorY = cursorY + fpsDropdownHeightTotal

        cursorY = cursorY + 36

        heading("Hotkey Configuration")

        if state.awaitingBindAction and state.awaitingBindActionLabel then
            if mode == "draw" then
                love.graphics.setFont(fonts.small)
                love.graphics.setColor(windowColors.accent or { 0.2, 0.55, 0.95, 1 })
                local prompt = string.format("Press a key for %s (Backspace to clear, Esc to cancel)", state.awaitingBindActionLabel)
                love.graphics.printf(prompt, viewportX, viewportY + cursorY, columnWidth, "left")
                love.graphics.setColor(textColor)
            end
            cursorY = cursorY + fonts.small:getHeight() + 12
        end

        local bindingButtonWidth = 110
        for _, action in ipairs(BINDING_ACTIONS) do
            local labelY = cursorY
            local bindings = settings.keybindings[action.id]
            local bindingText = get_binding_text(bindings)
            local isAwaiting = state.awaitingBindAction == action.id

            if mode == "draw" then
                love.graphics.setFont(fonts.body)
                love.graphics.setColor(isAwaiting and (windowColors.accent or { 0.2, 0.55, 0.95, 1 }) or textColor)
                love.graphics.print(action.label, viewportX, viewportY + labelY)

                love.graphics.setFont(fonts.small)
                love.graphics.setColor(windowColors.muted or { 0.5, 0.55, 0.6, 1 })
                love.graphics.print(bindingText, viewportX + 220, viewportY + labelY + 4)

                local rect = {
                    x = viewportX + columnWidth - bindingButtonWidth,
                    y = viewportY + labelY - 2,
                    w = bindingButtonWidth,
                    h = 28,
                    action = action,
                }

                local hovered = point_in_rect(mouseX, mouseY, rect)
                love.graphics.setColor(hovered and (windowColors.button_hover or { 0.18, 0.24, 0.32, 1 }) or (windowColors.button or { 0.12, 0.16, 0.22, 1 }))
                love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 5, 5)

                love.graphics.setColor(windowColors.border or { 0.12, 0.18, 0.28, 0.9 })
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1, 5, 5)

                love.graphics.setFont(fonts.small)
                love.graphics.setColor(windowColors.title_text or textColor)
                love.graphics.printf(isAwaiting and "Press..." or "Rebind", rect.x, rect.y + (rect.h - fonts.small:getHeight()) * 0.5, rect.w, "center")

                params.bindingButtons[#params.bindingButtons + 1] = rect
            end

            cursorY = cursorY + fonts.body:getHeight() + 18
        end

        if #STATIC_HOTKEYS > 0 then
            cursorY = cursorY + 4
            if mode == "draw" then
                love.graphics.setFont(fonts.small)
                love.graphics.setColor(windowColors.muted or { 0.5, 0.55, 0.6, 1 })
                love.graphics.print("Additional Hotkeys", viewportX, viewportY + cursorY)
                love.graphics.setColor(textColor)
            end
            cursorY = cursorY + fonts.small:getHeight() + 6

            local keyColumnWidth = 80
            local rowSpacing = 12
            for _, entry in ipairs(STATIC_HOTKEYS) do
                if mode == "draw" then
                    love.graphics.setFont(fonts.body)
                    love.graphics.setColor(windowColors.title_text or textColor)
                    love.graphics.print(entry.key, viewportX, viewportY + cursorY)

                    love.graphics.setColor(textColor)
                    love.graphics.print(entry.description, viewportX + keyColumnWidth, viewportY + cursorY)
                end
                cursorY = cursorY + fonts.body:getHeight() + rowSpacing
            end
        end

        cursorY = cursorY + 8

        heading("Utilities")

        local restoreRect = {
            x = viewportX,
            y = viewportY + cursorY,
            w = 220,
            h = 38,
        }

        if mode == "draw" then
            local hovered = point_in_rect(mouseX, mouseY, restoreRect)
            love.graphics.setColor(hovered and (windowColors.button_hover or { 0.18, 0.24, 0.32, 1 }) or (windowColors.button or { 0.12, 0.16, 0.22, 1 }))
            love.graphics.rectangle("fill", restoreRect.x, restoreRect.y, restoreRect.w, restoreRect.h, 6, 6)
            love.graphics.setColor(windowColors.border or { 0.12, 0.18, 0.28, 0.9 })
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", restoreRect.x + 0.5, restoreRect.y + 0.5, restoreRect.w - 1, restoreRect.h - 1, 6, 6)

            love.graphics.setFont(fonts.body)
            love.graphics.setColor(windowColors.title_text or textColor)
            love.graphics.print("Restore Defaults", restoreRect.x + 18, restoreRect.y + (restoreRect.h - fonts.body:getHeight()) * 0.5)

            params.refs._restoreRect = restoreRect
        end

        cursorY = cursorY + restoreRect.h + 18

        if mode == "draw" then
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(windowColors.muted or { 0.5, 0.55, 0.6, 1 })
            love.graphics.printf("Changes apply instantly. Press Esc to return to the pause menu.", viewportX, viewportY + cursorY, columnWidth, "left")
        end

        cursorY = cursorY + fonts.small:getHeight()

        return cursorY - (params.startY or 0)
    end

    -- Measure content height
    local contentHeight = layout_content("measure", {
        startY = 0,
    }) or 0

    local innerHeight = math.max(1, viewportHeight)

    state.scroll = tonumber(state.scroll) or 0

    local maxScroll = math.max(0, contentHeight - innerHeight)
    maxScroll = tonumber(maxScroll) or 0
    if maxScroll == 0 then
        state.scroll = 0
    else
        if state.scroll > maxScroll then
            state.scroll = maxScroll
        elseif state.scroll < 0 then
            state.scroll = 0
        end
    end

    local viewportRect = {
        x = viewportX,
        y = viewportY,
        w = math.max(1, viewportWidth),
        h = viewportHeight,
    }

    state._sliderRects = {}
    state._bindingButtons = {}
    state._fullscreenRect = nil
    state._vsyncRect = nil
    state._restoreRect = nil
    state._fpsDropdownRect = nil
    state._viewportRect = viewportRect
    state._maxScroll = maxScroll
    state._viewportHeight = viewportHeight
    state._contentHeight = contentHeight
    love.graphics.setScissor(viewportRect.x, viewportRect.y, viewportRect.w, viewportRect.h)
    love.graphics.setColor(textColor)
    love.graphics.setFont(fonts.body)

    layout_content("draw", {
        startY = -state.scroll,
        sliderRects = state._sliderRects,
        dropdownItems = state._resolutionDropdownItems,
        bindingButtons = state._bindingButtons,
        refs = state,
    })

    love.graphics.setScissor()

    -- Scrollbar
    if maxScroll > 0 then
        local scrollAreaX = scrollbarX
        local scrollAreaY = viewportY
        local scrollAreaHeight = viewportHeight
        local thumbHeight = math.max(18, scrollAreaHeight * (viewportHeight / contentHeight))
        local thumbTravel = scrollAreaHeight - thumbHeight
        local thumbY = scrollAreaY + (thumbTravel > 0 and (state.scroll / maxScroll) * thumbTravel or 0)

        local thumbRect = {
            x = scrollAreaX,
            y = thumbY,
            w = SCROLLBAR_WIDTH,
            h = thumbHeight,
        }

        local hoveredThumb = point_in_rect(mouseX, mouseY, thumbRect)

        if justPressed then
            if hoveredThumb then
                state.draggingThumb = true
                state.dragOffset = mouseY - thumbRect.y
            elseif point_in_rect(mouseX, mouseY, {
                x = scrollAreaX,
                y = scrollAreaY,
                w = SCROLLBAR_WIDTH,
                h = scrollAreaHeight,
            }) then
                local target = math.max(0, math.min(mouseY - thumbHeight * 0.5, scrollAreaY + thumbTravel))
                state.scroll = ((target - scrollAreaY) / thumbTravel) * maxScroll
            elseif point_in_rect(mouseX, mouseY, viewportRect) then
                state.draggingContent = true
                state.dragStartY = mouseY
                state.scrollStart = state.scroll
            end
        end

        if state.draggingThumb and isMouseDown then
            local newThumbY = mouseY - (state.dragOffset or thumbHeight * 0.5)
            newThumbY = math.max(scrollAreaY, math.min(scrollAreaY + thumbTravel, newThumbY))
            state.scroll = ((newThumbY - scrollAreaY) / thumbTravel) * maxScroll
        elseif state.draggingContent and isMouseDown then
            local delta = mouseY - (state.dragStartY or mouseY)
            state.scroll = math.max(0, math.min(maxScroll, (state.scrollStart or 0) - delta))
        end

        if not isMouseDown then
            state.draggingThumb = false
            state.draggingContent = false
        end

        love.graphics.setColor(windowColors.border or { 0.12, 0.18, 0.28, 0.9 })
        love.graphics.rectangle("fill", scrollAreaX, scrollAreaY, SCROLLBAR_WIDTH, scrollAreaHeight, 4, 4)

        love.graphics.setColor(hoveredThumb and (windowColors.title_text or { 1, 1, 1, 1 }) or windowColors.button or { 0.12, 0.16, 0.22, 1 })
        love.graphics.rectangle("fill", thumbRect.x, thumbRect.y, thumbRect.w, thumbRect.h, 3, 3)
    else
        state.draggingThumb = false
        state.draggingContent = false
    end

    -- Interaction handling
    if state.activeSlider and not isMouseDown then
        state.activeSlider = nil
    end

    if isMouseDown then
        local function update_slider(label, key)
            local rect = state._sliderRects[label]
            if not rect then
                return false
            end

            if justPressed and point_in_rect(mouseX, mouseY, rect) then
                state.activeSlider = label
            end

            if state.activeSlider == label then
                local localX = math.max(rect.x, math.min(rect.x + rect.w, mouseX))
                settings[key] = clamp01((localX - rect.x) / rect.w)
                return true
            end

            return false
        end

        local slidersChanged = update_slider("Master Volume", "masterVolume")
        slidersChanged = update_slider("Music Volume", "musicVolume") or slidersChanged
        slidersChanged = update_slider("Effects Volume", "sfxVolume") or slidersChanged
        if slidersChanged then
            apply_volume(settings)
        end

        if justPressed then
            local handled = false

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
                            close_fps_dropdown(state)
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
                            close_resolution_dropdown(state)
                            close_fps_dropdown(state)
                            apply_window_flags(settings, context)
                            apply_frame_limit(settings)
                        end
                        handled = true
                    elseif dropdownResult.toggled then
                        handled = true
                    end
                end
            end

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
                            close_resolution_dropdown(state)
                        end
                    else
                        state.fpsDropdownOpen = state.fpsDropdown and state.fpsDropdown.open or false
                    end

                    if fpsResult.selected_index then
                        local option = FPS_LIMIT_OPTIONS[fpsResult.selected_index]
                        if option then
                            settings.maxFps = math.max(0, tonumber(option.value) or 0)
                            apply_frame_limit(settings)
                        end
                        close_fps_dropdown(state)
                        handled = true
                    elseif fpsResult.toggled then
                        handled = true
                    end
                end
            end

            if not handled then
                for _, rect in ipairs(state._bindingButtons) do
                    if point_in_rect(mouseX, mouseY, rect) then
                        state.awaitingBindAction = rect.action.id
                        state.awaitingBindActionLabel = rect.action.label
                        handled = true
                        break
                    end
                end
            end

            if not handled then
                if state._fullscreenRect and point_in_rect(mouseX, mouseY, state._fullscreenRect) then
                    settings.fullscreen = not settings.fullscreen
                    close_resolution_dropdown(state)
                    close_fps_dropdown(state)
                    apply_window_flags(settings, context)
                    apply_frame_limit(settings)
                    reset_scroll_interaction(state)
                    handled = true
                elseif state._vsyncRect and point_in_rect(mouseX, mouseY, state._vsyncRect) then
                    settings.vsync = not settings.vsync
                    close_resolution_dropdown(state)
                    close_fps_dropdown(state)
                    apply_window_flags(settings, context)
                    apply_frame_limit(settings)
                    reset_scroll_interaction(state)
                    handled = true
                elseif state._restoreRect and point_in_rect(mouseX, mouseY, state._restoreRect) then
                    settings.masterVolume = 1
                    settings.musicVolume = 1
                    settings.sfxVolume = 1
                    settings.fullscreen = false
                    settings.vsync = false
                    settings.maxFps = DEFAULT_MAX_FPS
                    settings.keybindings = copy_bindings(DEFAULT_KEYBINDINGS)
                    apply_volume(settings)
                    close_resolution_dropdown(state)
                    close_fps_dropdown(state)
                    apply_window_flags(settings, context)
                    apply_frame_limit(settings)
                    reset_scroll_interaction(state)
                    handled = true
                end
            end
        end
    end

    love.graphics.pop()

    if frame.close_clicked then
        UIStateManager.hideOptionsUI(context)
    end

    return true
end

function options_window.keypressed(context, key)
    local state = context and context.optionsUI
    if not (state and state.visible) then
        return false
    end

    local settings = ensure_settings(state, context)

    if state.awaitingBindAction then
        if key == "escape" then
            state.awaitingBindAction = nil
            state.awaitingBindActionLabel = nil
            return true
        end

        settings.keybindings[state.awaitingBindAction] = {}
        if key ~= "backspace" then
            settings.keybindings[state.awaitingBindAction][1] = key
        end

        state.awaitingBindAction = nil
        state.awaitingBindActionLabel = nil
        return true
    end

    if key == "f11" then
        options_window.toggle_fullscreen(context)
        return true
    end

    if key == "escape" then
        UIStateManager.hideOptionsUI(context)
        return true
    end

    return false
end

function options_window.wheelmoved(context, x, y)
    local state = context and context.optionsUI
    if not (state and state.visible) then
        return false
    end

    y = tonumber(y)
    if not y or y == 0 then
        return false
    end

    local maxScroll = tonumber(state._maxScroll) or 0
    if maxScroll <= 0 then
        return false
    end

    local current = tonumber(state.scroll) or 0
    local step = tonumber(state._viewportHeight) or 0
    if step <= 0 then
        step = 60
    else
        step = math.max(24, step * 0.15)
    end

    local nextScroll = math.max(0, math.min(maxScroll, current - y * step))
    if math.abs(nextScroll - current) < 1e-3 then
        return false
    end

    state.scroll = nextScroll
    return true
end

function options_window.get_default_keybindings()
    return copy_bindings(DEFAULT_KEYBINDINGS)
end

function options_window.toggle_fullscreen(context)
    if not (love and love.window and love.window.setMode and love.window.getMode) then
        return false
    end

    local state = context and context.optionsUI
    if not state then
        if context then
            state = context._fullscreenOptionsState
            if not state then
                state = {}
                context._fullscreenOptionsState = state
            end
        else
            state = GLOBAL_FULLSCREEN_STATE
        end
    end

    local settings = ensure_settings(state, context)
    settings._windowedWidth = settings._windowedWidth or settings.windowWidth
    settings._windowedHeight = settings._windowedHeight or settings.windowHeight

    if not settings.fullscreen then
        settings._windowedWidth = settings.windowWidth
        settings._windowedHeight = settings.windowHeight
    end

    settings.fullscreen = not settings.fullscreen

    if not settings.fullscreen and settings._windowedWidth and settings._windowedHeight then
        settings.windowWidth = settings._windowedWidth
        settings.windowHeight = settings._windowedHeight
    end

    close_resolution_dropdown(state)
    close_fps_dropdown(state)
    apply_window_flags(settings, context)
    apply_frame_limit(settings)

    return settings.fullscreen
end

return options_window
