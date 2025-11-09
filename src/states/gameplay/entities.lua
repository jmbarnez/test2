local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")

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
    if not (state and state.world) then
        return nil
    end

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
    local displayName = config.displayName
    PlayerManager.attachShip(state, shipEntity, levelData, playerId, displayName)

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

return Entities
