-- PlayerRegistry: Manages player entity tracking, registration, and lookup
-- Handles the mapping between player IDs and their ship entities
-- Provides consolidated player resolution logic

local PlayerRegistry = {}

--- Resolves which player ID to use, with fallback chain
---@param state table The game state
---@param playerId string|nil Optional explicit player ID
---@return string|nil The resolved player ID
local function resolve_player_id(state, playerId)
    if playerId then
        return playerId
    end

    if state and state.localPlayerId then
        return state.localPlayerId
    end

    return nil
end

--- Ensures the players table exists in state
---@param state table The game state
local function ensure_players_table(state)
    if not state then
        return
    end
    
    state.players = state.players or {}
end

--- Gets the current ship for the local player
---@param state table The game state
---@return table|nil The player's ship entity
function PlayerRegistry.getCurrentShip(state)
    if not state then
        return nil
    end

    local pilot = state.playerPilot
    if pilot and pilot.currentShip then
        return pilot.currentShip
    end

    return state.playerShip or state.player
end

--- Registers a ship entity for a specific player ID
---@param state table The game state
---@param shipEntity table The ship entity to register
---@param playerId string|nil The player ID (defaults to entity's or local player ID)
---@return string|nil The resolved player ID
function PlayerRegistry.register(state, shipEntity, playerId)
    if not (state and shipEntity) then
        return nil
    end

    ensure_players_table(state)

    local resolvedPlayerId = playerId
        or shipEntity.playerId
        or state.localPlayerId
        or "player"

    shipEntity.playerId = resolvedPlayerId

    -- Remove duplicate registrations under different IDs
    for id, entity in pairs(state.players) do
        if entity == shipEntity and id ~= resolvedPlayerId then
            state.players[id] = nil
        end
    end
    
    state.players[resolvedPlayerId] = shipEntity
    shipEntity.player = true

    return resolvedPlayerId
end

--- Unregisters a ship entity
---@param state table The game state
---@param shipEntity table|nil The ship entity to unregister (nil = all)
function PlayerRegistry.unregister(state, shipEntity)
    if not state then
        return
    end

    local pilot = state.playerPilot
    local currentShip = pilot and pilot.currentShip or state.playerShip or state.player

    local target = shipEntity or currentShip
    
    if pilot and (not shipEntity or pilot.currentShip == shipEntity) then
        pilot.currentShip = nil
    end

    if target then
        if target.pilot == pilot then
            target.pilot = nil
        end
        if state.playerShip == target then
            state.playerShip = nil
        end
        if state.player == target then
            state.player = nil
        end
        if state.players then
            for id, entity in pairs(state.players) do
                if entity == target then
                    state.players[id] = nil
                end
            end
        end
    else
        -- Clear all player references
        state.playerShip = nil
        state.player = nil
        state.players = nil
    end
end

--- Gets the local player's ship entity with fallback logic
---@param state table The game state
---@return table|nil The local player's ship entity
function PlayerRegistry.getLocalPlayer(state)
    if not state then
        return nil
    end

    -- Primary: Use current ship from pilot
    local ship = PlayerRegistry.getCurrentShip(state)
    if ship then
        -- Ensure state.player is synchronized
        state.player = ship
        return ship
    end

    -- Fallback 1: Check players table with localPlayerId
    if state.players and state.localPlayerId then
        local localPlayer = state.players[state.localPlayerId]
        if localPlayer then
            return localPlayer
        end
    end

    -- Fallback 2: Find any player in players table
    if state.players then
        for _, entity in pairs(state.players) do
            if entity then
                return entity
            end
        end
    end

    return nil
end

--- Resolves the local player from various context types
---@param context table The context (state, gameplay state, or system context)
---@return table|nil The local player's ship entity
function PlayerRegistry.resolveLocalPlayer(context)
    if not context then
        return nil
    end

    -- Direct player reference
    if context.player then
        return context.player
    end

    -- Context has getLocalPlayer method (like gameplay state)
    if type(context.getLocalPlayer) == "function" then
        return context:getLocalPlayer()
    end

    -- Context has a state property
    local state = context.state or context
    if state then
        return PlayerRegistry.getLocalPlayer(state)
    end

    return nil
end

--- Gets a player entity by their ID
---@param state table The game state
---@param playerId string The player ID to look up
---@return table|nil The player's ship entity
function PlayerRegistry.getPlayerById(state, playerId)
    if not (state and playerId) then
        return nil
    end

    -- Check players table first
    if state.players and state.players[playerId] then
        return state.players[playerId]
    end

    -- Check if it's the local player
    local localPlayer = PlayerRegistry.getLocalPlayer(state)
    if localPlayer and localPlayer.playerId == playerId then
        return localPlayer
    end

    return nil
end

--- Collects all registered player entities
---@param state table The game state
---@return table A table mapping player IDs to ship entities
function PlayerRegistry.collectAllPlayers(state)
    local players = {}
    
    if not state then
        return players
    end

    -- Collect from players table
    if state.players then
        for playerId, entity in pairs(state.players) do
            if entity and entity.playerId then
                players[playerId] = entity
            end
        end
    end

    -- Ensure local player is included
    local localShip = PlayerRegistry.getCurrentShip(state)
    if localShip and localShip.playerId then
        players[localShip.playerId] = localShip
    elseif state.player and state.player.playerId then
        players[state.player.playerId] = state.player
    end

    return players
end

--- Checks if an entity is the local player
---@param state table The game state
---@param entity table The entity to check
---@return boolean True if the entity is the local player
function PlayerRegistry.isLocalPlayer(state, entity)
    if not (state and entity) then
        return false
    end

    local localPlayer = PlayerRegistry.getLocalPlayer(state)
    return localPlayer == entity
end

return PlayerRegistry
