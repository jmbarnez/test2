local PlayerWeapons = require("src.player.weapons")
local constants = require("src.constants.game")

local STARTING_CURRENCY = (constants.player and constants.player.starting_currency) or 0

local PlayerManager = {}

local function copy_table(source)
    if type(source) ~= "table" then
        return source
    end

    local clone = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            clone[key] = copy_table(value)
        else
            clone[key] = value
        end
    end
    return clone
end

local function normalize_level(levelData)
    if type(levelData) == "number" then
        return { current = levelData }
    elseif type(levelData) == "table" then
        local clone = copy_table(levelData)
        if clone.current == nil then
            clone.current = 1
        end
        return clone
    end

    return nil
end

function PlayerManager.ensurePilot(state, playerId)
    if not state then
        return nil
    end

    local pilot = state.playerPilot
    if not pilot then
        pilot = {
            playerPilot = true,
        }
        state.playerPilot = pilot
    end

    if playerId then
        pilot.playerId = playerId
    elseif not pilot.playerId then
        pilot.playerId = "player"
    end

    if type(pilot.level) ~= "table" then
        pilot.level = { current = 1 }
    else
        pilot.level.current = pilot.level.current or 1
    end

    return pilot
end

function PlayerManager.applyLevel(state, levelData, playerId)
    local pilot = PlayerManager.ensurePilot(state, playerId)
    if not pilot then
        return nil
    end

    local normalized = normalize_level(levelData)
    if normalized then
        pilot.level = normalized
    elseif type(pilot.level) ~= "table" then
        pilot.level = { current = 1 }
    else
        pilot.level.current = pilot.level.current or 1
    end

    return pilot
end

function PlayerManager.attachShip(state, shipEntity, levelData, playerId)
    if not (state and shipEntity) then
        return shipEntity
    end

    state.players = state.players or {}

    local resolvedPlayerId = playerId
        or shipEntity.playerId
        or state.localPlayerId
        or "player"

    shipEntity.playerId = resolvedPlayerId

    for id, entity in pairs(state.players) do
        if entity == shipEntity and id ~= resolvedPlayerId then
            state.players[id] = nil
        end
    end
    state.players[resolvedPlayerId] = shipEntity

    local existingLocalShip = PlayerManager.getCurrentShip(state)
    local hasLocalId = state.localPlayerId ~= nil
    local isLocalPlayer = (existingLocalShip == shipEntity)
        or (hasLocalId and state.localPlayerId == resolvedPlayerId)
        or (not hasLocalId and existingLocalShip == nil)

    shipEntity.player = true

    if isLocalPlayer then
        state.localPlayerId = resolvedPlayerId

        local pilot = PlayerManager.applyLevel(state, levelData, resolvedPlayerId)
        shipEntity.level = nil
        shipEntity.pilot = pilot

        if pilot then
            pilot.playerId = resolvedPlayerId
            pilot.currentShip = shipEntity
        end

        state.playerShip = shipEntity
        state.player = shipEntity

        state.playerCurrency = state.playerCurrency or STARTING_CURRENCY

        if shipEntity then
            if shipEntity.currency == nil then
                shipEntity.currency = state.playerCurrency
            end
            if shipEntity.credits == nil then
                shipEntity.credits = state.playerCurrency
            end
            if shipEntity.wallet == nil and STARTING_CURRENCY > 0 then
                shipEntity.wallet = { balance = state.playerCurrency }
            elseif type(shipEntity.wallet) == "table" then
                shipEntity.wallet.balance = shipEntity.wallet.balance or state.playerCurrency
            end
        end
    else
        shipEntity.pilot = nil
        if levelData then
            shipEntity.level = copy_table(levelData)
        end
    end

    if shipEntity then
        PlayerWeapons.initialize(shipEntity)
    end

    return shipEntity
end

function PlayerManager.getPilot(state)
    if not state then
        return nil
    end
    return state.playerPilot
end

function PlayerManager.getCurrentShip(state)
    if not state then
        return nil
    end

    local pilot = state.playerPilot
    if pilot and pilot.currentShip then
        return pilot.currentShip
    end

    return state.playerShip or state.player
end

function PlayerManager.clearShip(state, shipEntity)
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
        state.playerShip = nil
        state.player = nil
        state.players = nil
    end
end

-- Consolidated player resolution methods

function PlayerManager.getLocalPlayer(state)
    if not state then
        return nil
    end

    -- Primary: Use PlayerManager's current ship
    local ship = PlayerManager.getCurrentShip(state)
    if ship then
        -- Ensure state.player is synchronized
        state.player = ship
        return ship
    end

    -- Fallback 1: Check players table with localPlayerId
    if state.players and state.localPlayerId then
        local localPlayer = state.players[state.localPlayerId]
        if localPlayer then
            PlayerManager.attachShip(state, localPlayer)
            return localPlayer
        end
    end

    -- Fallback 2: Find any player in players table
    if state.players then
        for _, entity in pairs(state.players) do
            if entity then
                PlayerManager.attachShip(state, entity)
                return entity
            end
        end
    end

    return nil
end

function PlayerManager.resolveLocalPlayer(context)
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
        return PlayerManager.getLocalPlayer(state)
    end

    return nil
end

function PlayerManager.collectAllPlayers(state)
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
    local localShip = PlayerManager.getCurrentShip(state)
    if localShip and localShip.playerId then
        players[localShip.playerId] = localShip
    elseif state.player and state.player.playerId then
        players[state.player.playerId] = state.player
    end

    return players
end

function PlayerManager.getPlayerById(state, playerId)
    if not (state and playerId) then
        return nil
    end

    -- Check players table first
    if state.players and state.players[playerId] then
        return state.players[playerId]
    end

    -- Check if it's the local player
    local localPlayer = PlayerManager.getLocalPlayer(state)
    if localPlayer and localPlayer.playerId == playerId then
        return localPlayer
    end

    return nil
end

return PlayerManager
