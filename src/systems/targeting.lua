local tiny = require("libs.tiny")
local vector = require("src.util.vector")
local PlayerManager = require("src.player.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local function screen_to_world(x, y, camera)
    if not camera then
        return x, y
    end

    local zoom = camera.zoom or 1
    if zoom == 0 then
        return camera.x or 0, camera.y or 0
    end

    local world_x = x / zoom + (camera.x or 0)
    local world_y = y / zoom + (camera.y or 0)
    return world_x, world_y
end

local function get_hover_radius(entity)
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
        end
    end

    if type(radius) ~= "number" or radius <= 0 then
        radius = 48
    end

    return math.max(24, radius)
end

local function is_valid_target(entity)
    if not entity then
        return false
    end

    if entity.pendingDestroy then
        return false
    end

    if entity.player then
        return false
    end

    local pos = entity.position
    if not (pos and type(pos.x) == "number" and type(pos.y) == "number") then
        return false
    end

    local health = entity.health
    if not (type(health) == "table" and type(health.max) == "number" and health.max > 0) then
        return false
    end

    if type(health.current) == "number" and health.current <= 0 then
        return false
    end

    return true
end

return function(context)
    context = context or {}

    return tiny.system {
        update = function()
            local state = context.state or context
            if not (state and state.world and state.world.entities) then
                return
            end

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

            local mx, my = love.mouse.getPosition()
            local camera = state.camera or context.camera
            local world_x, world_y = screen_to_world(mx, my, camera)

            local player = PlayerManager.getCurrentShip(state)
            local player_entity = player

            local entities = state.world.entities
            local best_entity
            local best_dist_sq = math.huge
            local best_radius = 0

            for i = 1, #entities do
                local entity = entities[i]
                if entity ~= player_entity and is_valid_target(entity) then
                    local pos = entity.position
                    local radius = get_hover_radius(entity) * 1.15
                    local dx = world_x - pos.x
                    local dy = world_y - pos.y
                    local dist_sq = dx * dx + dy * dy
                    if dist_sq <= radius * radius and dist_sq < best_dist_sq then
                        best_entity = entity
                        best_dist_sq = dist_sq
                        best_radius = radius
                    end
                end
            end

            state.targetingCache = state.targetingCache or {}
            local cache = state.targetingCache

            if best_entity then
                cache.entity = best_entity
                cache.cursorWorldX = world_x
                cache.cursorWorldY = world_y
                cache.distanceToCursorSq = best_dist_sq
                cache.hoverRadius = best_radius
            else
                cache.entity = nil
                cache.cursorWorldX = world_x
                cache.cursorWorldY = world_y
                cache.distanceToCursorSq = nil
                cache.hoverRadius = nil
            end
        end,
    }
end
