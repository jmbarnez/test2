local table_util = require("src.util.table")
local loader = require("src.blueprints.loader")

local warpgate_factory = {}

local function compute_polygon_radius(points)
    local maxRadius = 0
    if type(points) ~= "table" then
        return maxRadius
    end

    for i = 1, #points, 2 do
        local x = points[i] or 0
        local y = points[i + 1] or 0
        local radius = math.sqrt(x * x + y * y)
        if radius > maxRadius then
            maxRadius = radius
        end
    end

    return maxRadius
end

local function resolve_base_polygon(drawable)
    if type(drawable) ~= "table" then
        return nil
    end

    if type(drawable.polygon) == "table" and #drawable.polygon >= 6 then
        return drawable.polygon
    end

    local parts = drawable.parts
    if type(parts) ~= "table" then
        return nil
    end

    for i = 1, #parts do
        local part = parts[i]
        if part and (part.type == nil or part.type == "polygon") and type(part.points) == "table" and #part.points >= 6 then
            return part.points
        end
    end

    return nil
end

local function clone_vector(vec)
    if type(vec) ~= "table" then
        return { x = 0, y = 0 }
    end

    return {
        x = vec.x or 0,
        y = vec.y or 0,
    }
end

local function apply_context_overrides(entity, context)
    if not context then
        return
    end

    if context.position then
        entity.position = clone_vector(context.position)
    end

    if context.rotation ~= nil then
        entity.rotation = context.rotation
    end
end

local RESERVED_CONTEXT_KEYS = {
    position = true,
    rotation = true,
    context = true,
    overrides = true,
    worldBounds = true,
}

local function resolve_override_source(context)
    if type(context) ~= "table" then
        return nil
    end

    if type(context.overrides) == "table" then
        return context.overrides
    end

    if type(context.context) == "table" then
        return context.context
    end

    return context
end

local function apply_blueprint_overrides(entity, context)
    local overrides = resolve_override_source(context)
    if not overrides then
        return
    end

    for key, value in pairs(overrides) do
        if not RESERVED_CONTEXT_KEYS[key] then
            entity[key] = table_util.deep_copy(value)
        end
    end
end

function warpgate_factory.instantiate(blueprint, context)
    assert(type(blueprint) == "table", "warpgate blueprint must be a table")

    local entity = table_util.deep_copy(blueprint.components or {})
    entity.blueprint = {
        category = blueprint.category,
        id = blueprint.id,
        name = blueprint.name,
    }

    entity.warpgate = entity.warpgate or {}
    entity.nonPhysical = true
    entity.type = entity.type or "warpgate"
    entity.targetable = true

    entity.position = clone_vector(entity.position)
    entity.velocity = clone_vector(entity.velocity)
    entity.rotation = entity.rotation or 0

    local health = entity.health
    if type(health) ~= "table" then
        health = {
            current = math.huge,
            max = math.huge,
            showTimer = 0,
        }
        entity.health = health
    else
        health.current = health.current or health.max or math.huge
        health.max = health.max or math.huge
        health.showTimer = health.showTimer or 0
    end

    if type(health.shield) ~= "table" then
        health.shield = {
            current = 0,
            max = 0,
        }
    else
        health.shield.current = health.shield.current or 0
        health.shield.max = health.shield.max or 0
    end

    apply_blueprint_overrides(entity, context)
    apply_context_overrides(entity, context)

    entity.drawable = entity.drawable or {}
    entity.drawable.type = entity.drawable.type or "warpgate"

    entity.body = nil
    entity.fixture = nil
    entity.colliders = nil
    entity.physics = nil

    local radius = entity.mountRadius or entity.portalRadius or 120
    entity.mountRadius = radius
    entity.hoverRadius = entity.hoverRadius or radius
    entity.targetRadius = entity.targetRadius or radius
    local basePolygon = resolve_base_polygon(entity.drawable)
    if basePolygon then
        entity.drawable.polygon = entity.drawable.polygon or basePolygon
        local polygonRadius = compute_polygon_radius(basePolygon)
        if polygonRadius and polygonRadius > 0 then
            entity.targetRadius = math.max(entity.targetRadius or 0, polygonRadius)
            entity.hoverRadius = math.max(entity.hoverRadius or 0, polygonRadius)
        end
    end
    entity.cullRadius = entity.cullRadius or radius * 1.4

    entity.disableRenderCulling = entity.disableRenderCulling ~= false and true

    return entity
end

loader.register_factory("warpgates", warpgate_factory)

return warpgate_factory
