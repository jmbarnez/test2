local UIStateManager = require("src.ui.state_manager")
local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local UIButton = require("src.ui.components.button")
local Gamestate = require("libs.hump.gamestate")
local start_menu = require("src.states.start_menu")

local death_window = {}

function death_window.draw(context)
    local state = context and context.deathUI
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
    local windowWidth = 420
    local windowHeight = 260
    local windowX = (screenWidth - windowWidth) * 0.5
    local windowY = (screenHeight - windowHeight) * 0.5

    local frame = window.draw_frame {
        x = windowX,
        y = windowY,
        width = windowWidth,
        height = windowHeight,
        title = "You Died",
        fonts = fonts,
        state = state,
        input = {
            x = mouseX,
            y = mouseY,
            is_down = isMouseDown,
            just_pressed = justPressed,
        },
        show_close = false,
    }

    local content = frame.content
    local windowColors = theme.colors.window or {}
    local textColor = windowColors.text or { 0.75, 0.75, 0.8, 1 }
    local mutedColor = windowColors.muted or { 0.45, 0.48, 0.54, 1 }
    local palette = theme.palette or {}

    local message = state.message or "Your ship has been destroyed. Respawn to re-enter the fight."
    local hint = state.hint or "Press Enter or Space to respawn"

    local textY = content.y
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(textColor)
    love.graphics.printf(message, content.x, textY, content.width, "center")
    textY = textY + fonts.body:getHeight() + 16

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(mutedColor)
    love.graphics.printf(hint, content.x, textY, content.width, "center")
    textY = textY + fonts.small:getHeight() + 28

    local buttonWidth = math.min(280, content.width)
    local buttonHeight = 44
    local buttonX = content.x + (content.width - buttonWidth) * 0.5
    local spacing = 14

    local respawnBase = palette.accent_player or { 0.3, 0.78, 0.46, 1 }
    local respawnHover = { respawnBase[1] * 1.1, respawnBase[2] * 1.05, respawnBase[3] * 1.05, 1 }
    local respawnActive = { respawnBase[1] * 0.9, respawnBase[2] * 0.9, respawnBase[3] * 0.9, 1 }

    local exitBase = palette.accent_warning or { 0.85, 0.42, 0.38, 1 }
    local exitHover = { exitBase[1] * 1.05, exitBase[2] * 1.05, exitBase[3] * 1.05, 1 }
    local exitActive = { exitBase[1] * 0.9, exitBase[2] * 0.9, exitBase[3] * 0.9, 1 }

    local respawnRect = {
        x = buttonX,
        y = textY,
        width = buttonWidth,
        height = buttonHeight,
    }

    local respawnResult = UIButton.render {
        rect = respawnRect,
        label = state.buttonLabel or "Respawn",
        font = fonts.body,
        fonts = fonts,
        input = {
            x = mouseX,
            y = mouseY,
            is_down = isMouseDown,
            just_pressed = justPressed,
        },
        fill_color = respawnBase,
        hover_color = respawnHover,
        active_color = respawnActive,
        border_color = windowColors.border,
        text_color = windowColors.title_text,
    }

    state.respawnHovered = respawnResult.hovered

    local exitRect = {
        x = buttonX,
        y = textY + buttonHeight + spacing,
        width = buttonWidth,
        height = buttonHeight,
    }

    local exitResult = UIButton.render {
        rect = exitRect,
        label = state.exitButtonLabel or "Exit to Menu",
        font = fonts.body,
        fonts = fonts,
        input = {
            x = mouseX,
            y = mouseY,
            is_down = isMouseDown,
            just_pressed = justPressed,
        },
        fill_color = exitBase,
        hover_color = exitHover,
        active_color = exitActive,
        border_color = windowColors.border,
        text_color = windowColors.title_text,
    }

    state.exitHovered = exitResult.hovered
    state.buttonHovered = state.respawnHovered or state.exitHovered

    if respawnResult.clicked then
        UIStateManager.requestRespawn(context)
    elseif exitResult.clicked then
        UIStateManager.clearRespawnRequest(context)
        UIStateManager.hideDeathUI(context)
        Gamestate.switch(start_menu)
        love.graphics.pop()
        return true
    end

    love.graphics.pop()

    return true
end

return death_window
