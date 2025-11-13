-- Options Window: Coordinator for game settings UI
-- Delegates to specialized modules for audio, display, and keybinding configuration
-- Handles overall layout, scrolling, and window frame

local window = require("src.ui.components.window")
local UIStateManager = require("src.ui.state_manager")
local theme = require("src.ui.theme")
local dropdown = require("src.ui.components.dropdown")
local geometry = require("src.util.geometry")

-- Specialized settings modules
local OptionsData = require("src.settings.options_data")
local AudioSettings = require("src.ui.windows.options.audio")
local DisplaySettings = require("src.ui.windows.options.display")
local Keybindings = require("src.ui.windows.options.keybindings")

---@diagnostic disable-next-line: undefined-global
local love = love

local options_window = {}

local SCROLLBAR_WIDTH = 10
local GLOBAL_FULLSCREEN_STATE = {}

--- Checks if a point is inside a rectangle
---@param x number Point X
---@param y number Point Y
---@param rect table Rectangle {x, y, w, h}
---@return boolean Whether the point is inside
local function point_in_rect(x, y, rect)
    return geometry.point_in_rect(x, y, rect)
end

--- Resets scroll interaction state
---@param state table The options UI state
local function reset_scroll_interaction(state)
    if not state then
        return
    end

    state.draggingThumb = false
    state.draggingContent = false
    state.activeSlider = nil
end

--- Lays out and renders all settings sections
---@param mode string "measure" or "draw"
---@param params table Layout parameters
---@return number The total content height
local function layout_content(mode, params)
    local cursorY = params.startY or 0
    local settings = params.settings
    local state = params.state
    local fonts = params.fonts
    local viewportX = params.viewportX
    local viewportY = params.viewportY
    local columnWidth = params.columnWidth
    local windowColors = theme.colors.window or {}
    local headingColor = windowColors.title_text or { 0.9, 0.92, 0.96, 1 }
    local textColor = windowColors.text or { 0.85, 0.85, 0.9, 1 }
    local mouseX = params.mouseX or 0
    local mouseY = params.mouseY or 0

    if mode == "draw" then
        -- Audio Section
        cursorY = AudioSettings.render({
            fonts = fonts,
            settings = settings,
            viewportX = viewportX,
            viewportY = viewportY,
            cursorY = cursorY,
            columnWidth = columnWidth,
            sliderRects = params.sliderRects,
        })

        cursorY = cursorY + 6

        -- Display Section
        cursorY = DisplaySettings.render({
            fonts = fonts,
            settings = settings,
            state = state,
            viewportX = viewportX,
            viewportY = viewportY,
            cursorY = cursorY,
            columnWidth = columnWidth,
            mouseX = mouseX,
            mouseY = mouseY,
            refs = params.refs,
        })

        cursorY = cursorY + 36

        -- Keybindings Section
        cursorY = Keybindings.render({
            fonts = fonts,
            settings = settings,
            state = state,
            viewportX = viewportX,
            viewportY = viewportY,
            cursorY = cursorY,
            columnWidth = columnWidth,
            mouseX = mouseX,
            mouseY = mouseY,
            bindingButtons = params.bindingButtons,
        })

        cursorY = cursorY + 8

        -- Utilities Section
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(headingColor)
        love.graphics.print("Utilities", viewportX, viewportY + cursorY)
        cursorY = cursorY + fonts.title:getHeight() + 12

        local restoreRect = {
            x = viewportX,
            y = viewportY + cursorY,
            w = 220,
            h = 38,
        }

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
        cursorY = cursorY + restoreRect.h + 18

        -- Footer hint
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(windowColors.muted or { 0.5, 0.55, 0.6, 1 })
        love.graphics.printf("Changes apply instantly. Press Esc to return to the pause menu.", viewportX, viewportY + cursorY, columnWidth, "left")
        cursorY = cursorY + fonts.small:getHeight()
    else
        -- Measure mode - approximate heights
        cursorY = cursorY + fonts.title:getHeight() + 12 -- Audio heading
        cursorY = cursorY + (fonts.body:getHeight() + 6 + 10 + 40) * 3 -- Three sliders
        cursorY = cursorY + 6
        cursorY = cursorY + fonts.title:getHeight() + 12 -- Display heading
        cursorY = cursorY + fonts.body:getHeight() + 12 + 32 -- Resolution label + dropdown
        cursorY = cursorY + 24 + 32 + 24 -- Toggles
        cursorY = cursorY + fonts.body:getHeight() + 12 + 32 -- FPS label + dropdown
        cursorY = cursorY + 36
        cursorY = cursorY + fonts.title:getHeight() + 12 -- Keybindings heading
        if state.awaitingBindAction then
            cursorY = cursorY + fonts.small:getHeight() + 12
        end
        cursorY = cursorY + (#Keybindings.getActions() * (fonts.body:getHeight() + 18))
        cursorY = cursorY + 4 + fonts.small:getHeight() + 6
        cursorY = cursorY + (#Keybindings.getStaticHotkeys() * (fonts.body:getHeight() + 12))
        cursorY = cursorY + 8
        cursorY = cursorY + fonts.title:getHeight() + 12 -- Utilities heading
        cursorY = cursorY + 38 + 18 + fonts.small:getHeight()
    end

    return cursorY - (params.startY or 0)
end

--- Main draw function for the options window
---@param context table The gameplay context
---@return boolean Whether the window was drawn
function options_window.draw(context)
    local state = context and context.optionsUI
    if not (state and state.visible) then
        return false
    end

    local fonts = theme.get_fonts()
    local settings = OptionsData.ensure(state, context)

    -- Ensure dropdown states exist
    state.resolutionDropdown = state.resolutionDropdown or dropdown.create_state()
    state.fpsDropdown = state.fpsDropdown or dropdown.create_state()
    state.resolutionDropdownOpen = state.resolutionDropdown and state.resolutionDropdown.open or false
    state.fpsDropdownOpen = state.fpsDropdown and state.fpsDropdown.open or false

    -- Capture input
    if context and context.uiInput then
        context.uiInput.mouseCaptured = true
        context.uiInput.keyboardCaptured = true
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mouseX, mouseY = love.mouse.getPosition()
    local isMouseDown = love.mouse.isDown(1)
    local justPressed = isMouseDown and not state._was_mouse_down
    state._was_mouse_down = isMouseDown

    love.graphics.push("all")
    love.graphics.origin()

    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Window frame
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

    -- Content area setup
    local contentFrame = frame.content_full or frame.content
    local viewportPaddingX = 20
    local viewportPaddingY = 16
    local viewportX = contentFrame.x + viewportPaddingX
    local viewportY = contentFrame.y + viewportPaddingY
    local scrollbarX = contentFrame.x + contentFrame.width - SCROLLBAR_WIDTH
    local viewportWidth = math.max(80, scrollbarX - viewportX)
    local viewportHeight = math.max(1, contentFrame.height - viewportPaddingY * 2)
    local columnWidth = math.max(60, viewportWidth - 20)

    -- Measure content height
    local contentHeight = layout_content("measure", {
        startY = 0,
        settings = settings,
        state = state,
        fonts = fonts,
    }) or 0

    local innerHeight = math.max(1, viewportHeight)
    state.scroll = tonumber(state.scroll) or 0

    local maxScroll = math.max(0, contentHeight - innerHeight)
    maxScroll = tonumber(maxScroll) or 0
    if maxScroll == 0 then
        state.scroll = 0
    else
        state.scroll = math.max(0, math.min(maxScroll, state.scroll))
    end

    local viewportRect = {
        x = viewportX,
        y = viewportY,
        w = math.max(1, viewportWidth),
        h = viewportHeight,
    }

    -- Initialize state tracking tables
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

    -- Draw content with scissor
    love.graphics.setScissor(viewportRect.x, viewportRect.y, viewportRect.w, viewportRect.h)
    layout_content("draw", {
        startY = -state.scroll,
        settings = settings,
        state = state,
        fonts = fonts,
        viewportX = viewportX,
        viewportY = viewportY,
        columnWidth = columnWidth,
        mouseX = mouseX,
        mouseY = mouseY,
        sliderRects = state._sliderRects,
        bindingButtons = state._bindingButtons,
        refs = state,
    })
    love.graphics.setScissor()

    -- Scrollbar
    if maxScroll > 0 then
        local windowColors = theme.colors.window or {}
        local scrollAreaY = viewportY
        local scrollAreaHeight = viewportHeight
        local thumbHeight = math.max(18, scrollAreaHeight * (viewportHeight / contentHeight))
        local thumbTravel = scrollAreaHeight - thumbHeight
        local thumbY = scrollAreaY + (thumbTravel > 0 and (state.scroll / maxScroll) * thumbTravel or 0)

        local thumbRect = {
            x = scrollbarX,
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
                x = scrollbarX,
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
        love.graphics.rectangle("fill", scrollbarX, scrollAreaY, SCROLLBAR_WIDTH, scrollAreaHeight, 4, 4)

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
        -- Audio sliders
        local audioHandled = AudioSettings.handleInteraction(state, settings, mouseX, mouseY, isMouseDown, justPressed)

        if justPressed then
            local handled = not not audioHandled

            -- Display settings
            handled = DisplaySettings.handleInteraction(state, settings, context, mouseX, mouseY, justPressed) or handled

            -- Keybindings
            if not handled then
                handled = Keybindings.handleInteraction(state, mouseX, mouseY, justPressed) or handled
            end

            -- Restore defaults button
            if not handled and state._restoreRect and point_in_rect(mouseX, mouseY, state._restoreRect) then
                OptionsData.resetToDefaults(settings)
                AudioSettings.apply(settings)
                DisplaySettings.applyWindowFlags(settings, context)
                DisplaySettings.applyFrameLimit(settings)
                handled = true
            end

            if handled then
                reset_scroll_interaction(state)
            end
        end
    end

    love.graphics.pop()

    if frame.close_clicked then
        UIStateManager.hideOptionsUI(context)
    end

    return true
end

--- Handles keypresses
---@param context table The gameplay context
---@param key string The key that was pressed
---@return boolean Whether the key was handled
function options_window.keypressed(context, key)
    local state = context and context.optionsUI
    if not (state and state.visible) then
        return false
    end

    local settings = OptionsData.ensure(state, context)

    -- Keybinding configuration
    if Keybindings.handleKeypress(state, settings, key) then
        return true
    end

    -- F11 for fullscreen toggle
    if key == "f11" then
        options_window.toggle_fullscreen(context)
        return true
    end

    -- Escape to close
    if key == "escape" then
        UIStateManager.hideOptionsUI(context)
        return true
    end

    return false
end

--- Handles mouse wheel scrolling
---@param context table The gameplay context
---@param x number X scroll amount
---@param y number Y scroll amount
---@return boolean Whether the scroll was handled
function options_window.wheelmoved(context, x, y)
    local state = context and context.optionsUI
    if not (state and state.visible) then
        return false
    end

    local yAmount = tonumber(y)
    if not yAmount or yAmount == 0 then
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

    local nextScroll = math.max(0, math.min(maxScroll, current - yAmount * step))
    if math.abs(nextScroll - current) < 1e-3 then
        return false
    end

    state.scroll = nextScroll
    return true
end

--- Gets the default keybindings
---@return table The default keybindings
function options_window.get_default_keybindings()
    return OptionsData.getDefaultKeybindings()
end

--- Toggles fullscreen mode
---@param context table The gameplay context
---@return boolean The new fullscreen state
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

    local settings = OptionsData.ensure(state, context)
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

    DisplaySettings.applyWindowFlags(settings, context)
    DisplaySettings.applyFrameLimit(settings)

    return settings.fullscreen
end

return options_window
