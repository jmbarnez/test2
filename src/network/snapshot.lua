local ShipRuntime = require("src.ships.runtime")
local PlayerManager = require("src.player.manager")
local Entities = require("src.states.gameplay.entities")
local Prediction = require("src.network.prediction")
local JitterBuffer = require("src.network.jitter_buffer")
local loader = require("src.blueprints.loader")

local Snapshot = {}

local function collect_players(state)
    return PlayerManager.collectAllPlayers(state)
end

function Snapshot.capture(state)
    if not state then
        return nil
    end
    
    print("[DEBUG] Snapshot.capture called")

    local snapshot = {
        tick = state.snapshotTick or 0,
        timestamp = love.timer and love.timer.getTime and love.timer.getTime() or nil,
        players = {},
        enemies = {},
        asteroids = {},
    }

    local players = collect_players(state)
    for playerId, entity in pairs(players) do
        local serialized = ShipRuntime.serialize(entity)
        if serialized then
            serialized.playerId = playerId
            snapshot.players[playerId] = serialized
        end
    end

    -- Assign stable IDs to world entities
    state.netEntityIds = state.netEntityIds or { seq = 0, map = setmetatable({}, { __mode = "k" }), rev = {} }
    local function ensure_entity_id(entity)
        if entity.entityId or entity.id then
            return entity.entityId or entity.id
        end
        local map = state.netEntityIds.map
        local id = map[entity]
        if not id then
            state.netEntityIds.seq = (state.netEntityIds.seq or 0) + 1
            id = string.format("e_%06d", state.netEntityIds.seq)
            map[entity] = id
            state.netEntityIds.rev[id] = entity
            entity.entityId = id
        end
        return id
    end

    -- Capture enemies (ships with enemy flag)
    local world = state.world
    local enemyCount = 0
    local asteroidCount = 0
    
    if world and world.entities then
        for i = 1, #world.entities do
            local e = world.entities[i]
            if e and e.enemy and e.blueprint and e.blueprint.category == "ships" then
                local serialized = ShipRuntime.serialize(e)
                if serialized then
                    serialized.entityId = ensure_entity_id(e)
                    serialized.faction = serialized.faction or "enemy"
                    snapshot.enemies[serialized.entityId] = serialized
                    enemyCount = enemyCount + 1
                end
            end
        end
    end

    -- Capture asteroids (by blueprint category)
    if world and world.entities then
        for i = 1, #world.entities do
            local e = world.entities[i]
            if e and e.blueprint and e.blueprint.category == "asteroids" then
                local body = e.body
                local vx, vy = 0, 0
                local ang
                if body and not body:isDestroyed() then
                    vx, vy = body:getLinearVelocity()
                    ang = body:getAngularVelocity()
                end
                local id = ensure_entity_id(e)
                snapshot.asteroids[id] = {
                    entityId = id,
                    blueprint = { category = "asteroids", id = e.blueprint.id },
                    position = { x = (e.position and e.position.x) or (body and body:getX()) or 0, y = (e.position and e.position.y) or (body and body:getY()) or 0 },
                    rotation = e.rotation or (body and body:getAngle()) or 0,
                    velocity = { x = vx, y = vy },
                    angularVelocity = ang,
                }
                asteroidCount = asteroidCount + 1
            end
        end
    end
    
    print(string.format("[CAPTURE] Captured %d enemies, %d asteroids", enemyCount, asteroidCount))

    return snapshot
end

local function find_player_entity(state, playerId)
    if state.players and state.players[playerId] then
        return state.players[playerId]
    end

    local localShip = PlayerManager.getCurrentShip(state)
    if localShip and localShip.playerId == playerId then
        return localShip
    end

    if state.player and state.player.playerId == playerId then
        return state.player
    end

    return nil
end

local function spawn_remote_player(state, playerId, playerSnapshot)
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
        return spawned
    end

    return nil
end

local function is_local_player(state, entity, playerId)
    local localShip = PlayerManager.getCurrentShip(state)
    if not localShip then
        return false
    end

    return (entity == localShip)
        or (localShip.playerId and localShip.playerId == playerId)
        or (state.localPlayerId and state.localPlayerId == playerId)
end

local function initialize_network_state(entity, playerSnapshot, isLocal)
    entity.networkState = entity.networkState or {}
    local netState = entity.networkState

    if playerSnapshot.position then
        entity.position = entity.position or {}
        entity.position.x = playerSnapshot.position.x
        entity.position.y = playerSnapshot.position.y
        netState.targetX = playerSnapshot.position.x
        netState.targetY = playerSnapshot.position.y
    end

    if playerSnapshot.rotation ~= nil and not isLocal then
        entity.rotation = playerSnapshot.rotation
        netState.targetRotation = playerSnapshot.rotation
    end

    if playerSnapshot.velocity then
        entity.velocity = entity.velocity or {}
        entity.velocity.x = playerSnapshot.velocity.x or 0
        entity.velocity.y = playerSnapshot.velocity.y or 0
        netState.targetVX = playerSnapshot.velocity.x or 0
        netState.targetVY = playerSnapshot.velocity.y or 0
    else
        netState.targetVX = 0
        netState.targetVY = 0
    end

    if entity.body and not entity.body:isDestroyed() then
        if playerSnapshot.position then
            entity.body:setPosition(playerSnapshot.position.x, playerSnapshot.position.y)
        end
        if playerSnapshot.rotation ~= nil then
            entity.body:setAngle(playerSnapshot.rotation)
        end
        -- Don't set velocity on network-corrected bodies - let physics corrections handle it
        if not entity.networkCorrected and playerSnapshot.velocity then
            entity.body:setLinearVelocity(playerSnapshot.velocity.x or 0, playerSnapshot.velocity.y or 0)
        end
    end

    netState.initialized = true
end

local function update_network_state(entity, playerSnapshot, isLocal)
    entity.networkState = entity.networkState or {}
    local netState = entity.networkState

    if playerSnapshot.position then
        netState.targetX = playerSnapshot.position.x
        netState.targetY = playerSnapshot.position.y
    end

    if playerSnapshot.rotation ~= nil and not isLocal then
        netState.targetRotation = playerSnapshot.rotation
    end

    if playerSnapshot.velocity then
        netState.targetVX = playerSnapshot.velocity.x or 0
        netState.targetVY = playerSnapshot.velocity.y or 0
    else
        netState.targetVX = 0
        netState.targetVY = 0
    end

    netState.receivedAt = love.timer and love.timer.getTime and love.timer.getTime() or 0
end

local function handle_physics_body(state, entity)
    if not entity then return end
    
    -- Everyone gets full dynamic physics for proper interactions
    if entity.body and not entity.body:isDestroyed() then
        entity.body:setType("dynamic")
        entity.body:setLinearDamping(0)
        -- Keep original angular damping from blueprint (don't override)
        
        -- Ensure fixtures are not sensors for full physics
        local fixtures = { entity.body:getFixtures() }
        for i = 1, #fixtures do
            local fixture = fixtures[i]
            if fixture and fixture:isSensor() then
                fixture:setSensor(false)
            end
        end
        
        -- Mark remote players as network-corrected (but still physical)
        if not state.networkServer then
            entity.networkCorrected = true
        end
    end
end

local function get_or_create_entity_by_id(state, id)
    state.entitiesById = state.entitiesById or {}
    return state.entitiesById[id]
end

local function register_entity_by_id(state, id, entity)
    state.entitiesById = state.entitiesById or {}
    state.entitiesById[id] = entity
end

local function remove_entity(state, entity)
    if not (state and entity) then return end
    if state.world then
        pcall(function() state.world:remove(entity) end)
    end
    if entity.body and not entity.body:isDestroyed() then
        pcall(function() entity.body:destroy() end)
    end
end

function Snapshot.apply(state, snapshot)
    if not (state and snapshot and snapshot.players) then
        return
    end
    
    print("[DEBUG] Snapshot.apply called")

    if snapshot.tick then
        state.snapshotTick = snapshot.tick
    end

    -- On pure clients, clear existing locally-generated world on first snapshot
    if not state.networkServer and not state.worldSynced then
        Entities.clearNonLocalEntities(state)
        state.worldSynced = true
    end

    for playerId, playerSnapshot in pairs(snapshot.players) do
        local entity = find_player_entity(state, playerId)

        if not entity then
            entity = spawn_remote_player(state, playerId, playerSnapshot)
        end

        if not entity then
            goto continue
        end

        if is_local_player(state, entity, playerId) then
            -- Skip direct corrections for local player when prediction is enabled
            -- Reconciliation happens in NetworkManager instead
            if not Prediction.shouldApplyServerCorrection(state, playerId) then
                goto continue
            end
        end

        -- Initialize jitter buffer for remote players
        if not entity.jitterBuffer then
            entity.jitterBuffer = JitterBuffer.new()
        end
        
        -- Add snapshot to jitter buffer for smooth playback
        local currentTime = love.timer.getTime()
        JitterBuffer.addSnapshot(entity.jitterBuffer, playerSnapshot, currentTime)
        
        -- Get interpolated snapshot from buffer
        local bufferedSnapshot = JitterBuffer.getInterpolatedSnapshot(entity.jitterBuffer, currentTime)
        if bufferedSnapshot then
            ShipRuntime.applySnapshot(entity, bufferedSnapshot)
            
            if not entity.networkState or not entity.networkState.initialized then
                initialize_network_state(entity, bufferedSnapshot, is_local_player(state, entity, playerId))
            else
                update_network_state(entity, bufferedSnapshot, is_local_player(state, entity, playerId))
            end
        else
            -- Fallback to direct application if buffer not ready
            ShipRuntime.applySnapshot(entity, playerSnapshot)
            
            if not entity.networkState or not entity.networkState.initialized then
                initialize_network_state(entity, playerSnapshot, is_local_player(state, entity, playerId))
            else
                update_network_state(entity, playerSnapshot, is_local_player(state, entity, playerId))
            end
        end

        handle_physics_body(state, entity)

        ::continue::
    end

    -- Track seen sets to remove missing entities
    local seenEnemies = {}
    local seenAsteroids = {}

    -- Enemies
    if snapshot.enemies then
        local enemyCount = 0
        for _ in pairs(snapshot.enemies) do enemyCount = enemyCount + 1 end
        print(string.format("[WORLD SYNC] Applying %d enemies", enemyCount))
        
        for id, enemySnap in pairs(snapshot.enemies) do
            seenEnemies[id] = true
            local entity = get_or_create_entity_by_id(state, id)
            if not entity then
                -- Instantiate enemy ship by blueprint id
                if enemySnap.blueprint and enemySnap.blueprint.id then
                    print(string.format("[WORLD SYNC] Creating enemy %s (%s)", id, enemySnap.blueprint.id))
                    local ok, created = pcall(loader.instantiate, "ships", enemySnap.blueprint.id, {
                        physicsWorld = state.physicsWorld,
                        worldBounds = state.worldBounds,
                    })
                    if ok and created then
                        created.enemy = true
                        created.faction = enemySnap.faction or created.faction or "enemy"
                        if state.world then
                            state.world:add(created)
                        end
                        register_entity_by_id(state, id, created)
                        entity = created
                        print(string.format("[WORLD SYNC] Successfully created enemy %s", id))
                    else
                        print(string.format("[WORLD SYNC] Failed to create enemy %s: %s", id, tostring(created)))
                    end
                end
            end
            if entity then
                ShipRuntime.applySnapshot(entity, enemySnap)
                if not entity.networkState or not entity.networkState.initialized then
                    initialize_network_state(entity, enemySnap)
                else
                    update_network_state(entity, enemySnap)
                end
                handle_physics_body(state, entity)
            end
        end
    end

    -- Asteroids
    if snapshot.asteroids then
        local asteroidCount = 0
        for _ in pairs(snapshot.asteroids) do asteroidCount = asteroidCount + 1 end
        print(string.format("[WORLD SYNC] Applying %d asteroids", asteroidCount))
        
        for id, aSnap in pairs(snapshot.asteroids) do
            seenAsteroids[id] = true
            local entity = get_or_create_entity_by_id(state, id)
            if not entity then
                if aSnap.blueprint and aSnap.blueprint.id then
                    print(string.format("[WORLD SYNC] Creating asteroid %s (%s)", id, aSnap.blueprint.id))
                    local ok, created = pcall(loader.instantiate, "asteroids", aSnap.blueprint.id, {
                        physicsWorld = state.physicsWorld,
                        worldBounds = state.worldBounds,
                    })
                    if ok and created then
                        if state.world then
                            state.world:add(created)
                        end
                        register_entity_by_id(state, id, created)
                        entity = created
                        print(string.format("[WORLD SYNC] Successfully created asteroid %s", id))
                    else
                        print(string.format("[WORLD SYNC] Failed to create asteroid %s: %s", id, tostring(created)))
                    end
                end
            end
            if entity then
                entity.position = entity.position or {}
                if aSnap.position then
                    entity.position.x = aSnap.position.x or entity.position.x or 0
                    entity.position.y = aSnap.position.y or entity.position.y or 0
                end
                if aSnap.rotation ~= nil then
                    entity.rotation = aSnap.rotation
                end
                if aSnap.velocity then
                    entity.velocity = entity.velocity or {}
                    entity.velocity.x = aSnap.velocity.x or 0
                    entity.velocity.y = aSnap.velocity.y or 0
                end
                -- Initialize/update network targets for interpolation
                entity.networkState = entity.networkState or {}
                local net = entity.networkState
                net.targetX = (aSnap.position and aSnap.position.x) or entity.position.x
                net.targetY = (aSnap.position and aSnap.position.y) or entity.position.y
                net.targetRotation = aSnap.rotation or (entity.rotation or 0)
                net.targetVX = (aSnap.velocity and aSnap.velocity.x) or 0
                net.targetVY = (aSnap.velocity and aSnap.velocity.y) or 0
                net.initialized = true
                net.receivedAt = love.timer and love.timer.getTime and love.timer.getTime() or 0
                handle_physics_body(state, entity)
            end
        end
    end

    -- Remove entities not present in snapshot (clients only)
    if not state.networkServer and state.entitiesById then
        for id, entity in pairs(state.entitiesById) do
            if entity and entity.enemy and not seenEnemies[id] then
                remove_entity(state, entity)
                state.entitiesById[id] = nil
            elseif entity and entity.blueprint and entity.blueprint.category == "asteroids" and not seenAsteroids[id] then
                remove_entity(state, entity)
                state.entitiesById[id] = nil
            end
        end
    end
end

return Snapshot
