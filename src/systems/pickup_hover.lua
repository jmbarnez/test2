local tiny = require("libs.tiny")
local ItemLabel = require("src.util.item_label")

---@diagnostic disable-next-line: undefined-global
local love = love

local DEFAULT_RADIUS = 20

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

local function resolve_pickup_radius(entity)
    if not entity then
        return DEFAULT_RADIUS
    end

    local pickup = entity.pickup
    local drawable = entity.drawable

    if pickup then
        if type(pickup.hoverRadius) == "number" and pickup.hoverRadius > 0 then
            return pickup.hoverRadius
        end
        if type(pickup.collectRadius) == "number" and pickup.collectRadius > 0 then
            return math.max(8, pickup.collectRadius * 0.35)
        end
    end

    if type(drawable) == "table" then
        if type(drawable.radius) == "number" and drawable.radius > 0 then
            return drawable.radius
        end
        if type(drawable.size) == "number" and drawable.size > 0 then
            return math.max(8, drawable.size * 0.4)
        end
    end

    return DEFAULT_RADIUS
end

local function clear_hover_state(state)
    if not state then
        return
    end

    state.pickupHoverEntity = nil
    state.pickupHoverRadius = nil

    local cache = state.targetingCache
    if cache then
        if cache.pickupHoveredEntity and cache.entity == cache.pickupHoveredEntity then
            cache.entity = nil
        end
        if cache.hoveredEntity and cache.hoveredEntity.pickup then
            cache.hoveredEntity = nil
            cache.hoverRadius = nil
        end
        cache.pickupHoveredEntity = nil
        cache.pickupHoverRadius = nil
        cache.pickupInfo = nil
    end
end

local function build_pickup_info(pickup)
    if not pickup then
        return nil
    end

    local item = pickup.item
    local heading = ItemLabel.resolve(item)
    local quantity = pickup.quantity or (item and item.quantity) or 1

    local lines = {}
    if quantity and quantity > 1 then
        lines[#lines + 1] = string.format("Quantity: %d", quantity)
    end

    local value = item and (item.value or item.price or item.baseValue)
    if type(value) == "number" and value > 0 then
        local total_value = value * (quantity or 1)
        lines[#lines + 1] = string.format("Value: %d credits", total_value)
    end

    local volume = item and (item.volume or item.unitVolume)
    if type(volume) == "number" and volume > 0 then
        local total_volume = volume * (quantity or 1)
        lines[#lines + 1] = string.format("Volume: %.2f", total_volume)
    end

    local description = item and item.description

    return {
        heading = heading,
        lines = (#lines > 0) and lines or nil,
        description = description,
        quantity = quantity,
        value = value,
        volume = volume,
    }
end

local function collect_candidates(state, world_x, world_y, search_radius, out)
    local grid = state and (state.spatialGrid or (state.world and state.world.spatialGrid))
    if grid then
        local count = 0
        grid:eachCircle(world_x, world_y, search_radius, function(entity)
            count = count + 1
            out[count] = entity
        end, function(entity)
            return entity and entity.pickup and not entity.pendingDestroy
        end)
        for i = count + 1, #out do
            out[i] = nil
        end
        return out, count
    end

    local entities = state.world and state.world.entities or {}
    for i = 1, #entities do
        out[i] = entities[i]
    end
    for i = #entities + 1, #out do
        out[i] = nil
    end
    return out, #entities
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
                clear_hover_state(state)
                return
            end

            if not (love and love.mouse and love.mouse.getPosition) then
                return
            end

            local mouse_x, mouse_y = love.mouse.getPosition()
            local camera = state.camera or context.camera
            local world_x, world_y = screen_to_world(mouse_x, mouse_y, camera)

            local best_entity, best_radius, best_dist_sq
            local candidates = state._pickupCandidates or {}
            local SEARCH_RADIUS = 256
            local candidateList, count = collect_candidates(state, world_x, world_y, SEARCH_RADIUS, candidates)
            state._pickupCandidates = candidateList

            for i = 1, count do
                local entity = candidateList[i]
                local pickup = entity.pickup
                local position = entity.position

                if pickup and position and not entity.pendingDestroy then
                    local radius = resolve_pickup_radius(entity)
                    local dx = world_x - (position.x or 0)
                    local dy = world_y - (position.y or 0)
                    local dist_sq = dx * dx + dy * dy

                    if dist_sq <= radius * radius then
                        if not best_dist_sq or dist_sq < best_dist_sq then
                            best_entity = entity
                            best_radius = radius
                            best_dist_sq = dist_sq
                        end
                    end
                end
            end

            if not best_entity then
                clear_hover_state(state)
                return
            end

            state.pickupHoverEntity = best_entity
            state.pickupHoverRadius = best_radius

            state.targetingCache = state.targetingCache or {}
            local cache = state.targetingCache
            cache.pickupHoveredEntity = best_entity
            cache.pickupHoverRadius = best_radius
            cache.pickupInfo = build_pickup_info(best_entity.pickup)

            if not cache.hoveredEntity or cache.hoveredEntity.pickup then
                cache.hoveredEntity = best_entity
                cache.hoverRadius = best_radius
            end

            if not cache.entity or (cache.entity.pickup) then
                cache.entity = best_entity
            end
        end,
    }
end
