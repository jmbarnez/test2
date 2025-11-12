local window = require("src.ui.components.window")
local UIStateManager = require("src.ui.state_manager")
local theme = require("src.ui.theme")
local UIButton = require("src.ui.components.button")
local SaveLoad = require("src.util.save_load")
local Gamestate = require("libs.hump.gamestate")
local start_menu = require("src.states.start_menu")

---@diagnostic disable-next-line: undefined-global
local love = love

local pause_window = {}

local function set_status(state, message, color)
    if not state then
        return
    end

    state.statusMessage = message
    state.statusColor = color or { 0.75, 0.78, 0.82, 1 }

    local timer = love and love.timer and love.timer.getTime and love.timer.getTime()
    if timer then
        state.statusExpiry = timer + 3
    else
        state.statusExpiry = nil
    end
end

function pause_window.draw(context)
    local state = context and context.pauseUI
    if not (state and state.visible) then
        return false
    end

    local fonts = theme.get_fonts()

    if context and context.uiInput then
        context.uiInput.mouseCaptured = true
        context.uiInput.keyboardCaptured = true
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    love.graphics.push("all")
    love.graphics.origin()

    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local windowWidth = 420
    local windowHeight = 340
    local mouseX, mouseY = love.mouse.getPosition()
    local isMouseDown = love.mouse.isDown(1)
    local justPressed = isMouseDown and not state._was_mouse_down
    state._was_mouse_down = isMouseDown

    local frame = window.draw_frame {
        x = (screenWidth - windowWidth) * 0.5,
        y = (screenHeight - windowHeight) * 0.5,
        width = windowWidth,
        height = windowHeight,
        title = state.title or "Paused",
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

    local content = frame.content
    local windowColors = theme.colors.window or {}
    local textColor = windowColors.text or { 0.75, 0.75, 0.8, 1 }
    local mutedColor = windowColors.muted or { 0.4, 0.4, 0.45, 1 }

    local textY = content.y
    local message = state.message or "Take a moment before diving back in."
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(textColor)
    love.graphics.printf(message, content.x, textY, content.width, "center")
    textY = textY + fonts.body:getHeight() + 14

    local hint = state.hint or "Press Esc or Enter to resume"
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(mutedColor)
    love.graphics.printf(hint, content.x, textY, content.width, "center")
    textY = textY + fonts.small:getHeight() + 18

    local now = love.timer and love.timer.getTime and love.timer.getTime()
    if state.statusMessage and state.statusExpiry and now and now >= state.statusExpiry then
        state.statusMessage = nil
        state.statusColor = nil
        state.statusExpiry = nil
    end

    local buttons = {
        { label = "Resume Game", action = "resume" },
        { label = "Save Game", action = "save" },
        { label = "Options", action = "options" },
        { label = "Exit to Menu", action = "exit_to_menu" },
    }

    local buttonWidth = math.min(300, content.width)
    local buttonHeight = 40
    local buttonSpacing = 12
    local buttonX = content.x + (content.width - buttonWidth) * 0.5
    local buttonY = textY
    state.buttonHovered = false
    local exitRequested = false

    for _, button in ipairs(buttons) do
        local rect = {
            x = buttonX,
            y = buttonY,
            width = buttonWidth,
            height = buttonHeight,
            w = buttonWidth,
            h = buttonHeight,
        }

        local result = UIButton.render {
            rect = rect,
            label = button.label,
            font = fonts.body,
            fonts = fonts,
            input = {
                x = mouseX,
                y = mouseY,
                is_down = isMouseDown,
                just_pressed = justPressed,
            },
        }

        state.buttonHovered = state.buttonHovered or result.hovered

        if result.clicked then
            if button.action == "resume" then
                UIStateManager.hidePauseUI(context)
            elseif button.action == "save" then
                local success, err = SaveLoad.saveGame(context)
                if success then
                    set_status(state, "Game Saved", { 0.45, 0.95, 0.45, 1.0 })
                else
                    set_status(state, "Save Failed: " .. tostring(err), { 1.0, 0.45, 0.45, 1.0 })
                    print("[PauseUI] Save error: " .. tostring(err))
                end
            elseif button.action == "options" then
                UIStateManager.showOptionsUI(context, "pause")
            elseif button.action == "exit_to_menu" then
                exitRequested = true
                break
            end
        end

        buttonY = buttonY + buttonHeight + buttonSpacing
    end

    if exitRequested then
        love.graphics.pop()
        UIStateManager.hidePauseUI(context)
        Gamestate.switch(start_menu)
        return true
    end

    if state.statusMessage and state.statusMessage ~= "" then
        love.graphics.setFont(fonts.small)
        local statusColor = state.statusColor or mutedColor
        love.graphics.setColor(statusColor)
        love.graphics.printf(state.statusMessage, content.x, buttonY + 6, content.width, "center")
    end

    if frame.close_clicked then
        UIStateManager.hidePauseUI(context)
    end

    love.graphics.pop()

    return true
end

return pause_window
