--- Player Lifecycle Management
-- Handles player spawning, destruction, and respawning

local PlayerManager = require("src.player.manager")
local UIStateManager = require("src.ui.state_manager")
local Entities = require("src.states.gameplay.entities")
local View = require("src.states.gameplay.view")

local Player = {}

--- Register callbacks on a player entity
---@param state table Gameplay state
---@param player table Player entity
function Player.registerCallbacks(state, player)
    if not player then
        return
    end

    PlayerManager.attachShip(state, player)

    local previousOnDestroyed = player.onDestroyed
    player.onDestroyed = function(entity, context)
        if type(previousOnDestroyed) == "function" then
            previousOnDestroyed(entity, context)
        end
        Player.onDestroyed(state, entity)
    end
end

--- Handle player destruction
---@param state table Gameplay state
---@param entity table Destroyed player entity
function Player.onDestroyed(state, entity)
    if not entity then
        return
    end

    PlayerManager.clearShip(state, entity)

    -- Clear all enemy targeting of player
    if state.world and state.world.entities then
        local entities = state.world.entities
        for i = 1, #entities do
            local e = entities[i]
            if e and e.enemy then
                e.currentTarget = nil
                e.retaliationTarget = nil
                e.retaliationTimer = nil

                local weapon = e.weapon
                if weapon then
                    weapon.firing = false
                    weapon.targetX = nil
                    weapon.targetY = nil
                    weapon.beamTimer = nil
                end
            end
        end
    end

    -- Clear engine trail
    if state.engineTrail then
        state.engineTrail:setActive(false)
        state.engineTrail:attachPlayer(nil)
    end

    -- Show death UI
    UIStateManager.showDeathUI(state)
    UIStateManager.clearRespawnRequest(state)
    View.updateCamera(state)
end

--- Respawn the player
---@param state table Gameplay state
function Player.respawn(state)
    if not (state.world and state.physicsWorld) then
        return
    end

    local player = Entities.spawnPlayer(state)
    if not player then
        return
    end

    Player.registerCallbacks(state, player)

    if state.engineTrail then
        state.engineTrail:clear()
        state.engineTrail:attachPlayer(player)
        state.engineTrail:setActive(false)
    end

    UIStateManager.hideDeathUI(state)
    UIStateManager.clearRespawnRequest(state)
    View.updateCamera(state)
end

return Player
