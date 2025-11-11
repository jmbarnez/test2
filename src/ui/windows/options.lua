local window = require("src.ui.components.window")
local UIStateManager = require("src.ui.state_manager")
local theme = require("src.ui.theme")

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

local SCROLLBAR_WIDTH = 10

local BINDING_ACTIONS = {
    { id = "moveLeft", label = "Move Left" },
    { id = "moveRight", label = "Move Right" },
    { id = "moveUp", label = "Move Up" },
    { id = "moveDown", label = "Move Down" },
    { id = "cycleWeaponPrev", label = "Cycle Weapon (Previous)" },
    { id = "cycleWeaponNext", label = "Cycle Weapon (Next)" },
    { id = "toggleCargo", label = "Toggle Cargo" },
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
    pause = { "escape" },
}

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
            settings.fullscreen = flags.fullscreen or false
            settings.vsync = flags.vsync or 0
        else
            settings.windowWidth = settings.windowWidth or 1600
            settings.windowHeight = settings.windowHeight or 900
            settings.flags = settings.flags or { fullscreen = false, vsync = 0 }
            settings.fullscreen = settings.flags.fullscreen
            settings.vsync = settings.flags.vsync
        end
    end

    settings.masterVolume = clamp01(settings.masterVolume)
    settings.musicVolume = clamp01(settings.musicVolume)
    settings.sfxVolume = clamp01(settings.sfxVolume)
    settings.fullscreen = not not settings.fullscreen
    settings.vsync = settings.vsync or 0
    settings.resolutionIndex = resolve_resolution_index(settings.windowWidth, settings.windowHeight) or settings.resolutionIndex or 2

    return settings
end

local function apply_volume(settings)
    if love.audio and love.audio.setVolume then
        love.audio.setVolume(settings.masterVolume or 1)
    end
end

local function apply_window_flags(settings)
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
    flags.vsync = settings.vsync

    if love.window.setMode(width, height, flags) then
        settings.flags = flags
        settings.windowWidth = width
        settings.windowHeight = height
        settings.resolutionIndex = resolve_resolution_index(width, height) or settings.resolutionIndex
    end
end

local function point_in_rect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
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

        local buttonsPerRow = 3
        local resolutionButtonHeight = 32
        local buttonSpacing = 12
        local resolutionButtonWidth = (columnWidth - buttonSpacing * (buttonsPerRow - 1)) / buttonsPerRow
        local rows = math.ceil(#RESOLUTIONS / buttonsPerRow)

        if mode == "draw" then
            for index, res in ipairs(RESOLUTIONS) do
                local col = (index - 1) % buttonsPerRow
                local row = math.floor((index - 1) / buttonsPerRow)
                local rect = {
                    x = viewportX + col * (resolutionButtonWidth + buttonSpacing),
                    y = viewportY + cursorY + row * (resolutionButtonHeight + buttonSpacing),
                    w = resolutionButtonWidth,
                    h = resolutionButtonHeight,
                    res = res,
                    index = index,
                }

                local isSelected = (not settings.fullscreen)
                    and settings.windowWidth == res.width
                    and settings.windowHeight == res.height
                local hovered = point_in_rect(mouseX, mouseY, rect)

                love.graphics.setColor(isSelected and (windowColors.button_hover or { 0.18, 0.24, 0.32, 1 })
                    or hovered and (windowColors.button_hover or { 0.18, 0.24, 0.32, 1 })
                    or (windowColors.button or { 0.12, 0.16, 0.22, 1 }))
                love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)

                love.graphics.setColor(windowColors.border or { 0.12, 0.18, 0.28, 0.9 })
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1, 6, 6)

                love.graphics.setFont(fonts.small)
                love.graphics.setColor(windowColors.title_text or textColor)
                love.graphics.printf(res.label, rect.x, rect.y + (rect.h - fonts.small:getHeight()) * 0.5, rect.w, "center")

                params.resolutionButtons[#params.resolutionButtons + 1] = rect
            end
        end

        cursorY = cursorY + rows * (resolutionButtonHeight + buttonSpacing) + 10

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
            draw_toggle(fonts, "VSync", vsyncRect, (settings.vsync or 0) ~= 0)
            params.refs.fullscreenRect = fullscreenRect
            params.refs.vsyncRect = vsyncRect
        end

        cursorY = cursorY + toggleHeight + 36

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

            params.refs.restoreRect = restoreRect
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
    state._resolutionButtons = {}
    state._bindingButtons = {}
    state._fullscreenRect = nil
    state._vsyncRect = nil
    state._restoreRect = nil
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
        resolutionButtons = state._resolutionButtons,
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
            for _, rect in ipairs(state._resolutionButtons) do
                if point_in_rect(mouseX, mouseY, rect) then
                    if settings.fullscreen then
                        settings.fullscreen = false
                    end
                    settings.windowWidth = rect.res.width
                    settings.windowHeight = rect.res.height
                    settings.resolutionIndex = rect.index
                    apply_window_flags(settings)
                    break
                end
            end

            for _, rect in ipairs(state._bindingButtons) do
                if point_in_rect(mouseX, mouseY, rect) then
                    state.awaitingBindAction = rect.action.id
                    state.awaitingBindActionLabel = rect.action.label
                    break
                end
            end

            if state._fullscreenRect and point_in_rect(mouseX, mouseY, state._fullscreenRect) then
                settings.fullscreen = not settings.fullscreen
                apply_window_flags(settings)
            elseif state._vsyncRect and point_in_rect(mouseX, mouseY, state._vsyncRect) then
                settings.vsync = (settings.vsync or 0) ~= 0 and 0 or 1
                apply_window_flags(settings)
            elseif state._restoreRect and point_in_rect(mouseX, mouseY, state._restoreRect) then
                settings.masterVolume = 1
                settings.musicVolume = 1
                settings.sfxVolume = 1
                settings.fullscreen = false
                settings.vsync = 0
                settings.keybindings = copy_bindings(DEFAULT_KEYBINDINGS)
                apply_volume(settings)
                apply_window_flags(settings)
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

return options_window
