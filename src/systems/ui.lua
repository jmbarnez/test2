local tiny = require("libs.tiny")
local theme = require("src.ui.theme")
local tooltip = require("src.ui.tooltip")
local cargo_window = require("src.ui.windows.cargo")
local death_window = require("src.ui.windows.death")
local chat_window = require("src.ui.windows.chat")
local multiplayer_window = require("src.ui.windows.multiplayer")
---@diagnostic disable-next-line: undefined-global
local love = love

return function(context)
    return tiny.system {
        draw = function()
            local uiInput = context and context.uiInput
            if uiInput then
                uiInput.mouseCaptured = false
                uiInput.keyboardCaptured = false
            end

            tooltip.begin_frame()
            cargo_window.draw(context)
            death_window.draw(context)
            chat_window.draw(context)
            multiplayer_window.draw(context)
            local mouse_x, mouse_y = love.mouse.getPosition()
            tooltip.draw(mouse_x, mouse_y, theme.get_fonts())
        end,
    }
end
