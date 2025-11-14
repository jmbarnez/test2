local tiny = require("libs.tiny")
local theme = require("src.ui.theme")
local tooltip = require("src.ui.components.tooltip")
local notifications = require("src.ui.notifications")
local cargo_window = require("src.ui.windows.cargo")
local death_window = require("src.ui.windows.death")
local pause_window = require("src.ui.windows.pause")
local options_window = require("src.ui.windows.options")
local map_window = require("src.ui.windows.map")
local skills_window = require("src.ui.windows.skills")
local debug_window = require("src.ui.windows.debug")
local station_window = require("src.ui.windows.station")
---@diagnostic disable-next-line: undefined-global
local love = love

---@class UISystemContext
---@field state table|nil         # Gameplay/UI state passed through to windows
---@field uiInput table|nil       # Shared UI input capture flags

return function(context)
    return tiny.system {
        draw = function()
            local uiInput = context and context.uiInput
            if uiInput then
                uiInput.mouseCaptured = false
                uiInput.keyboardCaptured = false
            end

            -- Reset coordinate system to screen space for UI rendering
            love.graphics.push("all")
            love.graphics.origin()

            tooltip.begin_frame()
            local state = context and context.state

            cargo_window.draw(context)
            death_window.draw(context)
            pause_window.draw(context)
            options_window.draw(context)
            map_window.draw(context)
            skills_window.draw(context)
            debug_window.draw(context)
            station_window.draw(context)
            notifications.draw(context)

            if state and state.hudTooltipRequest then
                tooltip.request(state.hudTooltipRequest)
                state.hudTooltipRequest = nil
            end

            -- Individual windows are responsible for declaring when they capture input.
            local mouse_x, mouse_y = love.mouse.getPosition()
            tooltip.draw(mouse_x, mouse_y, theme.get_fonts())

            love.graphics.pop()
        end,
    }
end
