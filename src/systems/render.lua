-- render.lua
-- Handles rendering of all game entities
-- Implements draw functions for different entity types (ships, asteroids)
-- Manages the game's visual presentation and HUD
-- Part of the ECS architecture using tiny-ecs

---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")
local asteroid_renderer = require("src.renderers.asteroid")
local projectile_renderer = require("src.renderers.projectile")

return function(context)
    return tiny.system {
        filter = tiny.requireAll("position", "drawable"),
        drawEntity = function(_, entity)
            if entity.drawable.type == "asteroid" then
                asteroid_renderer.draw(entity)
            elseif entity.drawable.type == "projectile" then
                projectile_renderer.draw(entity)
            end
        end,
        draw = function() end,
    }
end
