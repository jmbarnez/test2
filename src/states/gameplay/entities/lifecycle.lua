local PlayerManager = require("src.player.manager")

local Lifecycle = {}

function Lifecycle.updateHealthTimers(world, dt)
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

function Lifecycle.destroyWorldEntities(world)
    if not world then
        return
    end

    for i = 1, #world.entities do
        local entity = world.entities[i]
        if entity then
            local trail = entity.engineTrail
            if trail and trail.clear then
                trail:clear()
            end
            entity.engineTrail = nil

            if entity.body and not entity.body:isDestroyed() then
                entity.body:destroy()
            end
        end
    end

    world:clear()
end

function Lifecycle.clearNonLocalEntities(state)
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
        if entity then
            local trail = entity.engineTrail
            if trail and trail.clear then
                trail:clear()
            end
            entity.engineTrail = nil

            if entity.body and not entity.body:isDestroyed() then
                entity.body:destroy()
            end
            world:remove(entity)
        end
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

return Lifecycle
