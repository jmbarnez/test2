local tiny = require("libs.tiny")
local Hud = require("src.hud")
local PlayerManager = require("src.player.manager")
---@diagnostic disable-next-line: undefined-global
local love = love

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
