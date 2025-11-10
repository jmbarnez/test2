local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")
local Items = require("src.items.registry")

---@diagnostic disable-next-line: undefined-global
local love = love

local Entities = {}

local STARTER_SHIP_ID = constants.player.starter_ship_id

local function clone_overrides(overrides)
    if not overrides then
        return nil
    end

    local copy = {}
    for key, value in pairs(overrides) do
        copy[key] = value
    end

    return copy
end

function Entities.createShip(context, shipId, overrides)
    local instantiateContext = clone_overrides(overrides) or {}
    instantiateContext.physicsWorld = context.physicsWorld
    instantiateContext.worldBounds = context.worldBounds

    return loader.instantiate("ships", shipId, instantiateContext)
end

local function looks_like_spawn_config(value)
    if type(value) ~= "table" then
        return false
    end

    return value.playerId ~= nil
        or value.shipId ~= nil
        or value.ship ~= nil
        or value.id ~= nil
        or value.overrides ~= nil
        or value.level ~= nil
        or value.controlProfile ~= nil
end

function Entities.spawnPlayer(state, shipIdOrConfig, overrides)
    local config

    if type(shipIdOrConfig) == "table" and overrides == nil and looks_like_spawn_config(shipIdOrConfig) then
        config = clone_overrides(shipIdOrConfig)
    else
        config = {
            shipId = shipIdOrConfig,
            overrides = overrides,
        }
    end

    local chosenShipId = (config and config.shipId) or STARTER_SHIP_ID
    local instantiateOverrides = config and config.overrides and clone_overrides(config.overrides) or nil

    local levelData
    if instantiateOverrides and instantiateOverrides.level then
        levelData = clone_overrides(instantiateOverrides.level)
        instantiateOverrides.level = nil
    elseif config and config.level ~= nil then
        if type(config.level) == "table" then
            levelData = clone_overrides(config.level)
        elseif type(config.level) == "number" then
            levelData = { current = config.level }
        end
    end

    local playerShip = Entities.createShip(state, chosenShipId, instantiateOverrides)
    local shipEntity = state.world:add(playerShip)

    local playerId = config.playerId or "player"
    PlayerManager.attachShip(state, shipEntity, levelData, playerId)

    return shipEntity
end

function Entities.damage(entity, amount)
    if not entity or not entity.health then
        return
    end

    entity.health.current = math.max(0, (entity.health.current or entity.health.max or 0) - amount)

    if entity.healthBar then
        entity.health.showTimer = entity.healthBar.showDuration or 0
    end

    if entity.health.current <= 0 then
        entity.pendingDestroy = true
    end
end

function Entities.updateHealthTimers(world, dt)
    if not world or dt <= 0 then
        return
    end

    local entities = world.entities
    for i = 1, #entities do
        local entity = entities[i]
        local health = entity.health
        if health and health.showTimer and health.showTimer > 0 then
            health.showTimer = math.max(0, health.showTimer - dt)
        end
    end
end

function Entities.destroyWorldEntities(world)
    if not world then
        return
    end

    for i = 1, #world.entities do
        local entity = world.entities[i]
        if entity.body and not entity.body:isDestroyed() then
            entity.body:destroy()
        end
    end

    world:clear()
end

function Entities.clearNonLocalEntities(state)
    if not (state and state.world) then
        return
    end

    local world = state.world
    local localShip = PlayerManager.getCurrentShip(state)
    local keepers = {}
    if localShip then
        keepers[localShip] = true
    end
    if state.players then
        for _, pentity in pairs(state.players) do
            if pentity then
                keepers[pentity] = true
            end
        end
    end

    local toRemove = {}
    local entities = world.entities or {}
    for i = 1, #entities do
        local entity = entities[i]
        if entity and not keepers[entity] then
            toRemove[#toRemove + 1] = entity
        end
    end

    for i = 1, #toRemove do
        local entity = toRemove[i]
        if entity.body and not entity.body:isDestroyed() then
            entity.body:destroy()
        end
        world:remove(entity)
    end

    if state.entitiesById then
        for id, entity in pairs(state.entitiesById) do
            if not keepers[entity] then
                state.entitiesById[id] = nil
            end
        end
    end

    if state.players then
        for playerId, entity in pairs(state.players) do
            -- preserve all players (local and remote) on first sync
            -- pruning of missing players is handled by Snapshot.apply later
        end
    end
end

function Entities.spawnLootPickup(state, drop)
    if not (state and state.world and drop and drop.position) then
        return nil
    end

    local item = drop.item
    if not item and drop.id then
        local instantiated = Items.instantiate(drop.id, {
            quantity = drop.quantity,
            name = drop.name,
        })
        if instantiated then
            item = instantiated
        end
    end

    if not item then
        return nil
    end

    local quantity = drop.quantity or item.quantity or 1
    item.quantity = quantity

    local position = drop.position
    local velocity = drop.velocity or {}

    if not (velocity.x or velocity.y) then
        velocity = {
            x = (love and love.math and (love.math.random() - 0.5) or 0) * 20,
            y = (love and love.math and (love.math.random() - 0.5) or 0) * 20,
        }
    end

    local entity = {
        pickup = {
            item = item,
            itemId = item.id,
            quantity = quantity,
            collectRadius = drop.collectRadius or 48,
            lifetime = drop.lifetime or 45,
            age = 0,
            source = drop.source,
        },
        position = {
            x = position.x or 0,
            y = position.y or 0,
        },
        velocity = {
            x = velocity.x or 0,
            y = velocity.y or 0,
        },
        drawable = {
            type = "pickup",
            icon = item.icon,
            size = drop.size or 28,
            spinSpeed = drop.spinSpeed or 0.6,
            bobAmplitude = drop.bobAmplitude or 4,
        },
        rotation = drop.initialRotation or 0,
    }

    return state.world:add(entity)
end

return Entities
