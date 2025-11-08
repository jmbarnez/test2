local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")

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

function Entities.spawnPlayer(state, shipId, overrides)
    local chosenShipId = shipId or STARTER_SHIP_ID
    local player = Entities.createShip(state, chosenShipId, overrides)
    state.player = state.world:add(player)
    return state.player
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
