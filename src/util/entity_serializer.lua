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

local function copy_position(entity)
    local px, py

    if entity.position then
        px = entity.position.x or px
        py = entity.position.y or py
    end

    local body = entity.body
    if body and not body:isDestroyed() then
        px = body:getX()
        py = body:getY()
    end

    if px or py then
        return { x = px or 0, y = py or 0 }
    end

    return nil
end

local function copy_velocity(entity)
    local vx, vy

    if entity.velocity then
        vx = entity.velocity.x or vx
        vy = entity.velocity.y or vy
    end

    local body = entity.body
    if body and not body:isDestroyed() then
        local bodyVx, bodyVy = body:getLinearVelocity()
        vx = bodyVx
        vy = bodyVy
    end

    if vx or vy then
        return { x = vx or 0, y = vy or 0 }
    end

    return nil
end

local function copy_angular_velocity(entity)
    if entity.angularVelocity then
        return entity.angularVelocity
    end

    if entity.body and not entity.body:isDestroyed() then
        return entity.body:getAngularVelocity()
    end

    return nil
end

local function copy_health(entity)
    if type(entity.health) ~= "table" then
        return nil
    end

    return prune_empty({
        current = entity.health.current,
        max = entity.health.max,
        regen = entity.health.regen,
        showTimer = entity.health.showTimer,
    })
end

local function copy_shield(entity)
    if type(entity.shield) ~= "table" then
        return nil
    end

    return prune_empty({
        current = entity.shield.current,
        max = entity.shield.max,
        regen = entity.shield.regen,
        percent = entity.shield.percent,
        isDepleted = entity.shield.isDepleted,
    })
end

local function copy_energy(entity)
    if type(entity.energy) ~= "table" then
        return nil
    end

    return prune_empty({
        current = entity.energy.current,
        max = entity.energy.max,
    })
end

local function copy_thrust(entity)
    if entity.currentThrust or entity.maxThrust or entity.isThrusting then
        return prune_empty({
            current = entity.currentThrust,
            max = entity.maxThrust,
            isThrusting = not not entity.isThrusting,
        })
    end

    return nil
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
        position = copy_position(entity),
        velocity = copy_velocity(entity),
        rotation = entity.rotation,
    })
end

local function serialize_generic_entity(entity)
    -- Use component registry for generic serialization
    -- This eliminates the need to manually list every component
    return ComponentRegistry.serializeEntity(entity)
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

function EntitySerializer.serialize_entity(state, entity)
    if should_skip_entity(entity) then
        return nil
    end

    local blueprint = entity.blueprint
    local archetype = resolve_archetype(entity, blueprint)

    local payload
    if blueprint and blueprint.category == "ships" then
        payload = serialize_ship_entity(entity)
    elseif entity.pickup then
        payload = serialize_pickup(entity)
    else
        payload = serialize_generic_entity(entity)
    end

    payload = payload or {}

    if not payload.position then
        payload.position = copy_position(entity)
    end
    if not payload.velocity then
        payload.velocity = copy_velocity(entity)
    end
    if payload.rotation == nil then
        payload.rotation = entity.rotation
    end

    payload = prune_empty(payload)

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
