-- render.lua
-- Handles rendering of all game entities
-- Implements draw functions for different entity types (ships, asteroids)
-- Manages the game's visual presentation and HUD
-- Part of the ECS architecture using tiny-ecs

---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")
local vector = require("src.util.vector")
local constants = require("src.constants.game")
local ship_renderer = require("src.renderers.ship")
local station_renderer = require("src.renderers.station")
local asteroid_renderer = require("src.renderers.asteroid")
local projectile_renderer = require("src.renderers.projectile")
local pickup_renderer = require("src.renderers.pickup")
local wreckage_renderer = require("src.renderers.wreckage")

local highlight_primary = { 0.35, 0.92, 1.0, 0.65 }
local highlight_secondary = { 0.2, 0.7, 0.95, 0.25 }
local lock_primary = { 1.0, 0.3, 0.25, 0.85 }
local lock_secondary = { 1.0, 0.1, 0.05, 0.5 }

local render_constants = constants.render or {}

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

local function compute_polygon_radius(points)
    local max_radius = 0
    if type(points) ~= "table" then
        return max_radius
    end

    for i = 1, #points, 2 do
        local x = points[i] or 0
        local y = points[i + 1] or 0
        local radius = vector.length(x, y)
        if radius > max_radius then
            max_radius = radius
        end
    end

    return max_radius
end

local function resolve_drawable_radius(drawable)
    if type(drawable) ~= "table" then
        return nil
    end

    if type(drawable.radius) == "number" and drawable.radius > 0 then
        return drawable.radius
    end

    if type(drawable.size) == "number" and drawable.size > 0 then
        return drawable.size
    end

    if type(drawable.polygon) == "table" then
        local radius = compute_polygon_radius(drawable.polygon)
        if radius > 0 then
            return radius
        end
    end

    if type(drawable.shape) == "table" then
        local radius = compute_polygon_radius(drawable.shape)
        if radius > 0 then
            return radius
        end
    end

    if type(drawable.width) == "number" and drawable.width > 0 then
        return drawable.width
    end

    if type(drawable.height) == "number" and drawable.height > 0 then
        return drawable.height
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
        radius = resolve_drawable_radius(drawable)
    end

    if type(radius) ~= "number" or radius <= 0 then
        radius = 32
    end

    return radius
end

local function get_camera(context)
    if not context then
        return nil
    end

    if context.camera then
        return context.camera
    end

    local state = context.state
    if state and state.camera then
        return state.camera
    end

    return nil
end

local function compute_cull_radius(entity)
    if not entity then
        return 0
    end

    if type(entity.cullRadius) == "number" and entity.cullRadius >= 0 then
        return entity.cullRadius
    end

    local drawable = entity.drawable
    if drawable and type(drawable.cullRadius) == "number" and drawable.cullRadius >= 0 then
        return drawable.cullRadius
    end

    return compute_highlight_radius(entity)
end

local function is_entity_visible(entity, context)
    local cam = get_camera(context)
    if not cam then
        return true
    end

    local position = entity.position
    if not (position and position.x and position.y) then
        return true
    end

    local margin = render_constants.entity_cull_margin or 0
    local radius = compute_cull_radius(entity)
    local cam_width = cam.width or 0
    local cam_height = cam.height or 0

    local left = (cam.x or 0) - margin - radius
    local right = (cam.x or 0) + cam_width + margin + radius
    local top = (cam.y or 0) - margin - radius
    local bottom = (cam.y or 0) + cam_height + margin + radius

    local x = position.x
    local y = position.y

    return x >= left and x <= right and y >= top and y <= bottom
end

local function should_skip_render(entity, context)
    if not entity then
        return false
    end

    if entity.disableRenderCulling or entity.alwaysVisible then
        return false
    end

    local drawable = entity.drawable
    if drawable then
        if drawable.disableRenderCulling or drawable.alwaysVisible then
            return false
        end
    end

    return not is_entity_visible(entity, context)
end

local function draw_highlight(entity, cache)
    if not cache then
        return
    end

    local hovered_entity = cache.hoveredEntity
    local active_entity = cache.activeEntity
    local is_hovered = hovered_entity == entity
    local is_active = active_entity == entity

    if not (is_hovered or is_active) then
        return
    end

    local position = entity.position
    if not (position and position.x and position.y) then
        return
    end

    if is_active then
        local active_radius = cache.activeRadius
            or compute_highlight_radius(entity) * 1.15

        if active_radius and active_radius > 0 then
            love.graphics.push("all")
            love.graphics.setLineWidth(3)
            love.graphics.setColor(lock_primary)
            love.graphics.circle("line", position.x, position.y, active_radius + 4)

            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(lock_secondary)
            love.graphics.circle("line", position.x, position.y, active_radius + 7)
            love.graphics.pop()
        end
    end

    if not is_hovered then
        return
    end

    local drawable = entity.drawable
    local polygon = drawable and type(drawable.polygon) == "table" and #drawable.polygon >= 6 and drawable.polygon
        or drawable and type(drawable.shape) == "table" and #drawable.shape >= 6 and drawable.shape

    if polygon then
        love.graphics.push("all")
        love.graphics.translate(position.x, position.y)
        love.graphics.rotate(entity.rotation or 0)

        love.graphics.setLineWidth(2)
        love.graphics.setColor(highlight_primary)
        love.graphics.push()
        love.graphics.scale(1.04, 1.04)
        love.graphics.polygon("line", polygon)
        love.graphics.pop()

        love.graphics.setLineWidth(1)
        love.graphics.setColor(highlight_secondary)
        love.graphics.push()
        love.graphics.scale(1.08, 1.08)
        love.graphics.polygon("line", polygon)
        love.graphics.pop()

        love.graphics.pop()
        return
    end

    local radius = cache.hoveredRadius or cache.hoverRadius or compute_highlight_radius(entity)
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
            if should_skip_render(entity, context) then
                return
            end

            local cache = get_target_cache(context)
            local drawable = entity.drawable or {}
            if entity.station or drawable.type == "station" then
                station_renderer.draw(entity, context)
            elseif drawable.type == "ship" then
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
