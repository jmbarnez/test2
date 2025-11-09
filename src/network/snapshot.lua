local ShipRuntime = require("src.ships.runtime")
local PlayerManager = require("src.player.manager")
local Entities = require("src.states.gameplay.entities")

local Snapshot = {}

local function collect_players(state)
    return PlayerManager.collectAllPlayers(state)
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
            if localShip and localShip.playerId == playerId then
                entity = localShip
            end
        end

        if not entity and state.player and state.player.playerId == playerId then
            entity = state.player
        end

        if not entity then
            local spawnConfig = {
                playerId = playerId,
            }

            if playerSnapshot.blueprint and playerSnapshot.blueprint.id then
                spawnConfig.shipId = playerSnapshot.blueprint.id
            end

            if playerSnapshot.level then
                spawnConfig.level = playerSnapshot.level
            end

            local ok, spawned = pcall(Entities.spawnPlayer, state, spawnConfig)
            if ok and spawned then
                state.players = state.players or {}
                state.players[playerId] = spawned
                entity = spawned
            end
        end

        if entity then
            local localShip = PlayerManager.getCurrentShip(state)
            local isLocalPlayer = false

            if localShip then
                isLocalPlayer = (entity == localShip)
                    or (localShip.playerId and localShip.playerId == playerId)
                    or (state.localPlayerId and state.localPlayerId == playerId)
            end

            if isLocalPlayer then
                goto continue
            end

            local hadNetworkState = entity.networkState ~= nil
            local currentPosition = entity.position and { x = entity.position.x, y = entity.position.y } or nil
            local currentRotation = entity.rotation
            local currentVelocity = entity.velocity and { x = entity.velocity.x, y = entity.velocity.y } or nil

            ShipRuntime.applySnapshot(entity, playerSnapshot)

            entity.networkState = entity.networkState or {}
            local netState = entity.networkState
            local targetPos = entity.position or { x = 0, y = 0 }
            netState.targetX = targetPos.x
            netState.targetY = targetPos.y
            netState.targetRotation = entity.rotation or 0
            if entity.velocity then
                netState.targetVX = entity.velocity.x or 0
                netState.targetVY = entity.velocity.y or 0
            else
                netState.targetVX = playerSnapshot.velocity and playerSnapshot.velocity.x or 0
                netState.targetVY = playerSnapshot.velocity and playerSnapshot.velocity.y or 0
            end
            netState.receivedAt = love.timer and love.timer.getTime and love.timer.getTime() or 0
            netState.initialized = netState.initialized or false

            if hadNetworkState or netState.initialized then
                if currentPosition and entity.position then
                    entity.position.x = currentPosition.x
                    entity.position.y = currentPosition.y
                end
                if currentRotation ~= nil then
                    entity.rotation = currentRotation
                end
                if entity.velocity and currentVelocity then
                    entity.velocity.x = currentVelocity.x
                    entity.velocity.y = currentVelocity.y
                end
                if entity.body and not entity.body:isDestroyed() and currentPosition then
                    entity.body:setPosition(currentPosition.x, currentPosition.y)
                    if currentRotation ~= nil then
                        entity.body:setAngle(currentRotation)
                    end
                    if currentVelocity then
                        entity.body:setLinearVelocity(currentVelocity.x, currentVelocity.y)
                    end
                end
            else
                netState.initialized = true
            end
        end

        ::continue::
    end
end

return Snapshot
