local tiny = require("libs.tiny")
local Hud = require("src.hud")
local PlayerManager = require("src.player.manager")
local UIStateManager = require("src.ui.state_manager")
---@diagnostic disable-next-line: undefined-global
local love = love

---@class HudSystemContext
---@field state table|nil          # Gameplay state, used to derive player and HUD data
---@field resolveLocalPlayer fun(self:table):table|nil @ Optional helper for resolving local player

return function(context)
    return tiny.system {
        draw = function()
            local player = PlayerManager.resolveLocalPlayer(context)

            love.graphics.push("all")
            love.graphics.origin()

            Hud.draw(context, player)

            love.graphics.pop()
        end,
    }
end
