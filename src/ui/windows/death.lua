local UIStateManager = require("src.ui.state_manager")
local theme = require("src.ui.theme")

local death_window = {}

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
