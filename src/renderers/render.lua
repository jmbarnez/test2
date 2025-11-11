-- render.lua
-- Handles rendering of all game entities
-- Implements draw functions for different entity types (ships, asteroids)
-- Manages the game's visual presentation and HUD
-- Part of the ECS architecture using tiny-ecs

---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")
local ship_renderer = require("src.renderers.ship")
local asteroid_renderer = require("src.renderers.asteroid")
local projectile_renderer = require("src.renderers.projectile")
local pickup_renderer = require("src.renderers.pickup")
local wreckage_renderer = require("src.renderers.wreckage")

local highlight_primary = { 0.35, 0.92, 1.0, 0.65 }
local highlight_secondary = { 0.2, 0.7, 0.95, 0.25 }

local function get_target_cache(context)
    if not context then
        return nil
    end
    if context.targetingCache then
        return context.targetingCache
    end
    local state = context.state
    if state and state.targetingCache then
        return state.targetingCache
    end
    return nil
end

local function compute_highlight_radius(entity)
    if not entity then
        return 0
    end

    local radius = entity.hoverRadius
        or entity.targetRadius
        or entity.mountRadius

    if not radius then
        local drawable = entity.drawable
        if type(drawable) == "table" then
            radius = drawable.radius
                or drawable.size
                or drawable.width
                or drawable.height
        end
    end

    if type(radius) ~= "number" or radius <= 0 then
        radius = 48
    end

    return radius
end

local function draw_highlight(entity, cache)
    if not (cache and cache.entity and cache.entity == entity) then
        return
    end

    local position = entity.position
    if not (position and position.x and position.y) then
        return
    end

    local radius = cache.hoverRadius or compute_highlight_radius(entity)
    if radius <= 0 then
        return
    end

    love.graphics.push("all")
    love.graphics.setLineWidth(2)
    love.graphics.setColor(highlight_primary)
    love.graphics.circle("line", position.x, position.y, radius + 6)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(highlight_secondary)
    love.graphics.circle("line", position.x, position.y, radius + 10)
    love.graphics.pop()
end

return function(context)
    return tiny.system {
        filter = tiny.requireAll("position", "drawable"),
        drawEntity = function(_, entity)
            local cache = get_target_cache(context)
            if entity.drawable.type == "ship" then
                ship_renderer.draw(entity, context)
            elseif entity.drawable.type == "asteroid" then
                asteroid_renderer.draw(entity)
            elseif entity.drawable.type == "projectile" then
                projectile_renderer.draw(entity)
            elseif entity.drawable.type == "pickup" then
                pickup_renderer.draw(entity)
            elseif entity.drawable.type == "wreckage" then
                wreckage_renderer.draw(entity)
            end

            draw_highlight(entity, cache)
        end,
        draw = function() end,
    }
end
