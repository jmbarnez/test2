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

    local pilot = PlayerManager.applyLevel(state, levelData, playerId)

    shipEntity.player = true
    shipEntity.level = nil
    shipEntity.pilot = pilot


    if not playerId then
        if shipEntity.playerId then
            playerId = shipEntity.playerId
        elseif pilot and pilot.playerId then
            playerId = pilot.playerId
        else
            playerId = "player"
        end
    end

    shipEntity.playerId = playerId

    if pilot and playerId and not pilot.playerId then
        pilot.playerId = playerId
    end

    if pilot then
        pilot.currentShip = shipEntity
    end

    state.playerShip = shipEntity
    state.player = shipEntity

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
    else
        state.playerShip = nil
        state.player = nil
    end
end

return PlayerManager
