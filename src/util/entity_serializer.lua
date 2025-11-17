local table_util = require("src.util.table")
local ShipRuntime = require("src.ships.runtime")
local ComponentRegistry = require("src.util.component_registry")

---@diagnostic disable-next-line: undefined-global
local love = love

local EntitySerializer = {}

local nextEntityId = 1

local function sanitize_id_fragment(fragment)
    if type(fragment) ~= "string" then
        fragment = tostring(fragment or "entity")
    end
    fragment = fragment:gsub("[^%w_]+", "-")
    if fragment == "" then
        fragment = "entity"
    end
    return fragment
end

local function copy_serializable(value, seen)
    local valueType = type(value)
    if valueType == "nil" or valueType == "number" or valueType == "string" or valueType == "boolean" then
        return value
    end

    if valueType ~= "table" then
        return nil
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local result = {}
    seen[value] = result

    for key, innerValue in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            local copied = copy_serializable(innerValue, seen)
            if copied ~= nil then
                result[key] = copied
            end
        end
    end

    if next(result) == nil then
        return {}
    end

    return result
end

local function prune_empty(tbl, seen)
    if type(tbl) ~= "table" then
        return tbl
    end

    seen = seen or {}
    if seen[tbl] then
        return tbl
    end
    seen[tbl] = true

    for key, value in pairs(tbl) do
        if value == nil then
            tbl[key] = nil
        elseif type(value) == "table" then
            prune_empty(value, seen)
            if next(value) == nil then
                tbl[key] = nil
            end
        end
    end

    seen[tbl] = nil
    return tbl
end

local function serialize_cargo_items(cargo)
    if type(cargo) ~= "table" or type(cargo.items) ~= "table" then
        return nil
    end

    local items = {}
    for index = 1, #cargo.items do
        local item = cargo.items[index]
        if type(item) == "table" and item.id then
            items[#items + 1] = prune_empty({
                id = item.id,
                name = item.name,
                quantity = item.quantity or 1,
                volume = item.volume,
                icon = item.icon,
                installed = item.installed,
                moduleSlotId = item.moduleSlotId,
            })
        end
    end

    if #items == 0 then
        return nil
    end

    return items
end

local function serialize_ship_entity(entity)
    local snapshot = ShipRuntime.serialize(entity)
    if not snapshot then
        return nil
    end

    if entity.cargo then
        snapshot.cargo = snapshot.cargo or {}
        snapshot.cargo.items = serialize_cargo_items(entity.cargo)
    end

    return prune_empty(snapshot)
end

local function serialize_pickup(entity)
    local pickup = entity.pickup
    if type(pickup) ~= "table" then
        return nil
    end

    return prune_empty({
        pickup = copy_serializable(pickup),
    })
end

local function should_skip_entity(entity)
    if not entity then
        return true
    end

    if entity.player or entity.localPlayer or entity.isLocalPlayer then
        return true
    end

    if entity.disableSave or entity.persist == false or entity._noSave or entity._skipSave then
        return true
    end

    if entity.projectile or entity.bullet or entity.explosive or entity.particle then
        return true
    end

    if entity.debug or entity.debugOnly then
        return true
    end

    return false
end

local function resolve_archetype(entity, blueprint)
    if entity.pickup then
        return "pickup"
    end

    if entity.asteroid or entity.armorType == "rock" then
        return "asteroid"
    end

    if entity.station then
        return "station"
    end

    if entity.enemy then
        return "enemy"
    end

    if blueprint and blueprint.category then
        return blueprint.category
    end

    if entity.quest then
        return "quest-entity"
    end

    return entity.type or "entity"
end

local function resolve_entity_id(state, entity, blueprint, archetype)
    if type(entity.entityId) == "string" and entity.entityId ~= "" then
        return entity.entityId
    end

    if type(entity.id) == "string" and entity.id ~= "" then
        return entity.id
    end

    if type(entity._saveId) == "string" then
        return entity._saveId
    end

    state = state or {}
    state._entitySaveIds = state._entitySaveIds or {}

    local knownId = state._entitySaveIds[entity]
    if knownId then
        return knownId
    end

    local fragment
    if blueprint and blueprint.id then
        fragment = blueprint.id
    else
        fragment = archetype
    end

    fragment = sanitize_id_fragment(fragment)
    local generated = string.format("%s_%05d", fragment, nextEntityId)
    nextEntityId = nextEntityId + 1

    state._entitySaveIds[entity] = generated
    entity._saveId = generated

    return generated
end

local function build_component_payload(entity, blueprint)
    local payload = ComponentRegistry.serializeEntity(entity) or {}

    if entity.pickup then
        local pickupData = serialize_pickup(entity)
        if pickupData then
            payload = table_util.deep_merge(payload, pickupData)
        end
    end

    if blueprint and blueprint.category == "ships" then
        local shipData = serialize_ship_entity(entity)
        if shipData then
            payload = table_util.deep_merge(payload, shipData)
        end
    end

    return prune_empty(payload)
end

function EntitySerializer.serialize_entity(state, entity)
    if should_skip_entity(entity) then
        return nil
    end

    local blueprint = entity.blueprint
    local archetype = resolve_archetype(entity, blueprint)

    local payload = build_component_payload(entity, blueprint)

    if not payload or next(payload) == nil then
        return nil
    end

    local snapshot = {
        id = resolve_entity_id(state, entity, blueprint, archetype),
        archetype = archetype,
        blueprint = blueprint and {
            category = blueprint.category,
            id = blueprint.id,
        } or nil,
        data = payload,
    }

    return prune_empty(snapshot)
end

function EntitySerializer.serialize_world(state)
    if not (state and state.world and state.world.entities) then
        return {}
    end

    local results = {}
    for index = 1, #state.world.entities do
        local entity = state.world.entities[index]
        local serialized = EntitySerializer.serialize_entity(state, entity)
        if serialized then
            results[#results + 1] = serialized
        end
    end

    return results
end

return EntitySerializer
