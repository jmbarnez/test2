local tiny = require("libs.tiny")
local theme = require("src.ui.theme")
local tooltip = require("src.ui.tooltip")
local notifications = require("src.ui.notifications")
local cargo_window = require("src.ui.windows.cargo")
local death_window = require("src.ui.windows.death")
local pause_window = require("src.ui.windows.pause")
local options_window = require("src.ui.windows.options")
local map_window = require("src.ui.windows.map")
local skills_window = require("src.ui.windows.skills")
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
            pause_window.draw(context)
            options_window.draw(context)
            map_window.draw(context)
            skills_window.draw(context)
            notifications.draw(context)
            local mouse_x, mouse_y = love.mouse.getPosition()
            tooltip.draw(mouse_x, mouse_y, theme.get_fonts())
        end,
    }
end
