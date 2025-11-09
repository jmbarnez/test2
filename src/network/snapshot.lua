local ShipRuntime = require("src.ships.runtime")
local PlayerManager = require("src.player.manager")

local Snapshot = {}

local function collect_players(state)
    local players = {}

    if state.players then
        for playerId, entity in pairs(state.players) do
            if entity then
                players[playerId] = entity
            end
        end
    end

    local localShip = PlayerManager.getCurrentShip(state)
    if localShip then
        players[localShip.playerId or "player"] = localShip
    elseif state.player then
        players[state.player.playerId or "player"] = state.player
    end

    return players
end

function Snapshot.capture(state)
    if not state then
        return nil
    end

    local snapshot = {
        tick = state.snapshotTick or 0,
        timestamp = love.timer and love.timer.getTime and love.timer.getTime() or nil,
        players = {},
    }

    local players = collect_players(state)
    for playerId, entity in pairs(players) do
        local serialized = ShipRuntime.serialize(entity)
        if serialized then
            serialized.playerId = playerId
            snapshot.players[playerId] = serialized
        end
    end

    return snapshot
end

function Snapshot.apply(state, snapshot)
    if not (state and snapshot and snapshot.players) then
        return
    end

    if snapshot.tick then
        state.snapshotTick = snapshot.tick
    end

    for playerId, playerSnapshot in pairs(snapshot.players) do
        local entity
        if state.players then
            entity = state.players[playerId]
        end

        if not entity then
            local localShip = PlayerManager.getCurrentShip(state)
            if localShip and (localShip.playerId == playerId or playerId == "player") then
                entity = localShip
            end
        end

        if not entity and state.player and (state.player.playerId == playerId or playerId == "player") then
            entity = state.player
        end

        if entity then
            ShipRuntime.applySnapshot(entity, playerSnapshot)
        end
    end
end

return Snapshot
