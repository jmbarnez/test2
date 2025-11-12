local tiny = require("libs.tiny")
local vector = require("src.util.vector")
local PlayerManager = require("src.player.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

-- Constants
local DEFAULT_RADIUS = 48
local MIN_RADIUS = 24
local HOVER_RADIUS_MULTIPLIER = 1.15

local function screen_to_world(x, y, camera)
    if not camera then
        return x, y
    end

    local zoom = camera.zoom or 1
    if zoom == 0 then
        return camera.x or 0, camera.y or 0
    end

    return x / zoom + (camera.x or 0), y / zoom + (camera.y or 0)
end

local function get_hover_radius(entity)
    if not entity then
        return 0
    end

    -- Check for explicit radius properties
    local radius = entity.hoverRadius or entity.targetRadius or entity.mountRadius

    -- Fallback to drawable properties
    if not radius and entity.drawable and type(entity.drawable) == "table" then
        local drawable = entity.drawable
        radius = drawable.radius or drawable.size or drawable.width
    end

    -- Ensure valid radius
    if type(radius) ~= "number" or radius <= 0 then
        radius = DEFAULT_RADIUS
    end

    return math.max(MIN_RADIUS, radius)
end

local function is_targetable(entity)
    if not entity then
        return false
    end

    if entity.enemy then
        return true
    end

    if entity.station or entity.type == "station" then
        return true
    end

    if entity.asteroid or entity.type == "asteroid" then
        return true
    end

    if entity.targetable ~= nil then
        return not not entity.targetable
    end

    return false
end

local function is_valid_target(entity)
    if not entity or entity.pendingDestroy or entity.player then
        return false
    end

    -- Validate position
    local pos = entity.position
    if not (pos and type(pos.x) == "number" and type(pos.y) == "number") then
        return false
    end

    -- Validate health
    local health = entity.health
    if not (health and type(health.max) == "number" and health.max > 0) then
        return false
    end

    if type(health.current) == "number" and health.current <= 0 then
        return false
    end

    return true
end

local function find_closest_target(entities, world_x, world_y, player_entity)
    local best_entity, best_dist_sq, best_radius = nil, math.huge, 0

    for i = 1, #entities do
        local entity = entities[i]
        if entity ~= player_entity and is_targetable(entity) and is_valid_target(entity) then
            local pos = entity.position
            local radius = get_hover_radius(entity) * HOVER_RADIUS_MULTIPLIER
            local dx, dy = world_x - pos.x, world_y - pos.y
            local dist_sq = dx * dx + dy * dy

            if dist_sq <= radius * radius and dist_sq < best_dist_sq then
                best_entity, best_dist_sq, best_radius = entity, dist_sq, radius
            end
        end
    end

    return best_entity, best_dist_sq, best_radius
end

local function update_targeting_cache(cache, world_x, world_y, best_entity, best_dist_sq, best_radius, active_target)
    cache.cursorWorldX = world_x
    cache.cursorWorldY = world_y
    cache.distanceToCursorSq = best_entity and best_dist_sq or nil
    cache.hoveredEntity = best_entity
    cache.hoveredRadius = best_entity and best_radius or nil

    if active_target then
        cache.activeEntity = active_target
        cache.activeRadius = active_target == best_entity and best_radius 
            or get_hover_radius(active_target) * HOVER_RADIUS_MULTIPLIER
    else
        cache.activeEntity = nil
        cache.activeRadius = nil
    end

    cache.entity = cache.activeEntity or best_entity
    cache.highlightMode = nil
    cache.highlightRadius = nil
    cache.hoverRadius = cache.activeEntity and cache.activeRadius or cache.hoveredRadius
end

return function(context)
    context = context or {}

    return tiny.system {
        update = function()
            local state = context.state or context
            if not (state and state.world and state.world.entities) then
                return
            end

            -- Early exit if UI has mouse captured
            local ui_input = context.uiInput or state.uiInput
            if ui_input and ui_input.mouseCaptured then
                if state.targetingCache then
                    state.targetingCache.entity = nil
                end
                return
            end

            if not love.mouse then
                return
            end

            state.targetingCache = state.targetingCache or {}
            local cache = state.targetingCache

            -- Validate and clean up active target
            local active_target = state.activeTarget
            if active_target and not is_valid_target(active_target) then
                if cache.activeEntity == active_target then
                    cache.activeEntity = nil
                end
                state.activeTarget = nil
                active_target = nil
            end

            -- Get world coordinates
            local mx, my = love.mouse.getPosition()
            local camera = state.camera or context.camera
            local world_x, world_y = screen_to_world(mx, my, camera)

            -- Find closest valid target
            local player_entity = PlayerManager.getCurrentShip(state)
            local best_entity, best_dist_sq, best_radius = find_closest_target(
                state.world.entities, world_x, world_y, player_entity
            )

            -- Update cache with results
            update_targeting_cache(cache, world_x, world_y, best_entity, best_dist_sq, best_radius, active_target)
        end,
    }
end
