local table_util = require("src.util.table")
local loader = require("src.blueprints.loader")

local warpgate_factory = {}

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
    entity.cullRadius = entity.cullRadius or radius * 1.4

    entity.disableRenderCulling = entity.disableRenderCulling ~= false and true

    return entity
end

loader.register_factory("warpgates", warpgate_factory)

return warpgate_factory
