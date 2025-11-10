local UIStateManager = require("src.ui.state_manager")
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
    local layout = theme.draw_modal_window(state, fonts, {
        defaultButtonLabel = state.buttonLabel or "Respawn"
    })

    if context and context.uiInput then
        context.uiInput.mouseCaptured = true
        context.uiInput.keyboardCaptured = true
    end

    if layout and layout.buttonActivated then
        UIStateManager.requestRespawn(context)
    end

    return true
end

return death_window
