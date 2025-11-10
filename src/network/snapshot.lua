local ShipRuntime = require("src.ships.runtime")
local PlayerManager = require("src.player.manager")
local Entities = require("src.states.gameplay.entities")
local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local Prediction = require("src.network.prediction")

local Snapshot = {}

local function collect_players(state)
    return PlayerManager.collectAllPlayers(state)
end

local function reconcile_local_player(entity, snapshot)
    if not entity or not snapshot then
        return
    end

    local position = snapshot.position
    local velocity = snapshot.velocity
    local rotation = snapshot.rotation

    local body = entity.body
    if body and not body:isDestroyed() and position then
        local currentX, currentY = body:getPosition()
        local targetX = position.x or currentX
        local targetY = position.y or currentY
        local dx = targetX - currentX
        local dy = targetY - currentY

        local distanceSq = dx * dx + dy * dy
        local THRESHOLD = constants.network.reconciliation_threshold * constants.network.reconciliation_threshold  -- pixels squared

        if distanceSq > THRESHOLD then
            body:setPosition(targetX, targetY)
            if velocity then
                body:setLinearVelocity(velocity.x or 0, velocity.y or 0)
            end
        end

        entity.position = entity.position or {}
        entity.position.x, entity.position.y = body:getPosition()
    elseif position then
        entity.position = entity.position or {}
        entity.position.x = position.x
        entity.position.y = position.y
    end

    if rotation ~= nil then
        entity.rotation = rotation
        if body and not body:isDestroyed() then
            body:setAngle(rotation)
        end
    end

    if velocity then
        entity.velocity = entity.velocity or {}
        entity.velocity.x = velocity.x or 0
        entity.velocity.y = velocity.y or 0
    end
end

function Snapshot.capture(state)
    if not state then
        return nil
    end

    local snapshot = {
        tick = state.snapshotTick or 0,
        timestamp = love.timer and love.timer.getTime and love.timer.getTime() or nil,
        players = {},
        enemies = {},
        asteroids = {},
        projectiles = {},
    }

    local players = collect_players(state)
    for playerId, entity in pairs(players) do
        local serialized = ShipRuntime.serialize(entity)
        if serialized then
            serialized.playerId = playerId
            if state.playerInputTicks and state.playerInputTicks[playerId] then
                serialized.lastInputTick = state.playerInputTicks[playerId]
            end
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

    -- Capture world entities in a single pass (optimization)
    local world = state.world
    local enemyCount = 0
    local asteroidCount = 0
    local projectileCount = 0
    
    if world and world.entities then
        for i = 1, #world.entities do
            local e = world.entities[i]
            
            -- Check for enemy ships
            if e and e.enemy and e.blueprint and e.blueprint.category == "ships" then
                local serialized = ShipRuntime.serialize(e)
                if serialized then
                    serialized.entityId = ensure_entity_id(e)
                    serialized.faction = serialized.faction or "enemy"
                    snapshot.enemies[serialized.entityId] = serialized
                    enemyCount = enemyCount + 1
                end
            -- Check for asteroids
            elseif e and e.blueprint and e.blueprint.category == "asteroids" then
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
            -- Check for projectiles
            elseif e and e.projectile and e.position then
                local body = e.body
                local vx, vy = 0, 0
                if body and not body:isDestroyed() then
                    vx, vy = body:getLinearVelocity()
                end
                
                local id = ensure_entity_id(e)
                snapshot.projectiles[id] = {
                    entityId = id,
                    position = { x = e.position.x, y = e.position.y },
                    velocity = { x = vx, y = vy },
                    rotation = e.rotation or 0,
                    damage = e.projectile.damage or 0,
                    lifetime = e.projectile.lifetime or 0,
                    drawable = e.drawable and {
                        size = e.drawable.size,
                        color = e.drawable.color,
                        glowColor = e.drawable.glowColor,
                        shape = e.drawable.shape,
                        type = e.drawable.type,
                    } or nil,
                    faction = e.faction,
                    playerProjectile = e.playerProjectile,
                    enemyProjectile = e.enemyProjectile,
                }
                projectileCount = projectileCount + 1
            end
        end
    end
    

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

local function is_local_player(state, playerId)
    return state.localPlayerId and state.localPlayerId == playerId
end

local function initialize_interpolation(entity, snapshot)
    entity.netInterp = entity.netInterp or {}
    local interp = entity.netInterp
    
    -- Set initial position directly
    if snapshot.position then
        entity.position = entity.position or {}
        entity.position.x = snapshot.position.x
        entity.position.y = snapshot.position.y
        interp.targetX = snapshot.position.x
        interp.targetY = snapshot.position.y
    end
    
    if snapshot.rotation ~= nil then
        entity.rotation = snapshot.rotation
        interp.targetRotation = snapshot.rotation
    end
    
    if snapshot.velocity then
        entity.velocity = entity.velocity or {}
        entity.velocity.x = snapshot.velocity.x or 0
        entity.velocity.y = snapshot.velocity.y or 0
    end
    
    -- Sync physics body - keep dynamic for collisions
    if entity.body and not entity.body:isDestroyed() then
        entity.body:setType("dynamic")
        
        -- Lock rotation for ships - only player input should rotate
        if entity.blueprint and entity.blueprint.category == "ships" then
            entity.body:setFixedRotation(true)
        end
        
        if snapshot.position then
            entity.body:setPosition(snapshot.position.x, snapshot.position.y)
        end
        if snapshot.rotation ~= nil then
            entity.body:setAngle(snapshot.rotation)
        end
        if snapshot.velocity then
            entity.body:setLinearVelocity(snapshot.velocity.x or 0, snapshot.velocity.y or 0)
        end
    end
    
    interp.initialized = true
end

local function update_interpolation(entity, snapshot)
    entity.netInterp = entity.netInterp or {}
    local interp = entity.netInterp
    
    -- Set new interpolation targets
    if snapshot.position then
        interp.targetX = snapshot.position.x
        interp.targetY = snapshot.position.y
    end
    
    if snapshot.rotation ~= nil then
        interp.targetRotation = snapshot.rotation
    end
    
    if snapshot.velocity then
        entity.velocity = entity.velocity or {}
        entity.velocity.x = snapshot.velocity.x or 0
        entity.velocity.y = snapshot.velocity.y or 0
    end
    
    interp.lastUpdate = love.timer.getTime()
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

        local isLocal = is_local_player(state, playerId)

        if isLocal and not state.networkServer then
            if constants.network.client_prediction_enabled then
                local corrected = Prediction.reconcile(state, entity, playerSnapshot)
                if not corrected then
                    -- fall back to basic reconciliation if within thresholds
                    reconcile_local_player(entity, playerSnapshot)
                end
            else
                reconcile_local_player(entity, playerSnapshot)
            end
            goto continue
        end

        -- Skip snapshots for local player on the server/host
        if isLocal then
            goto continue
        end

        -- Apply snapshot to remote player
        ShipRuntime.applySnapshot(entity, playerSnapshot)
        
        -- Set up interpolation
        if not entity.netInterp or not entity.netInterp.initialized then
            initialize_interpolation(entity, playerSnapshot)
        else
            update_interpolation(entity, playerSnapshot)
        end

        ::continue::
    end

    -- Track seen sets to remove missing entities
    local seenEnemies = {}
    local seenAsteroids = {}
    local seenProjectiles = {}

    -- Enemies
    if snapshot.enemies then
        for id, enemySnap in pairs(snapshot.enemies) do
            seenEnemies[id] = true
            local entity = get_or_create_entity_by_id(state, id)
            if not entity then
                -- Instantiate enemy ship by blueprint id
                if enemySnap.blueprint and enemySnap.blueprint.id then
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
                    end
                end
            end
            if entity then
                ShipRuntime.applySnapshot(entity, enemySnap)
                if not entity.netInterp or not entity.netInterp.initialized then
                    initialize_interpolation(entity, enemySnap)
                else
                    update_interpolation(entity, enemySnap)
                end
            end
        end
    end

    -- Asteroids
    if snapshot.asteroids then
        for id, aSnap in pairs(snapshot.asteroids) do
            seenAsteroids[id] = true
            local entity = get_or_create_entity_by_id(state, id)
            if not entity then
                if aSnap.blueprint and aSnap.blueprint.id then
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
                
                -- Set up interpolation for asteroids too
                if not entity.netInterp or not entity.netInterp.initialized then
                    initialize_interpolation(entity, aSnap)
                else
                    update_interpolation(entity, aSnap)
                end
            end
        end
    end

    -- Projectiles (clients only - server is authoritative)
    if snapshot.projectiles and not state.networkServer then
        for id, pSnap in pairs(snapshot.projectiles) do
            seenProjectiles[id] = true
            local entity = get_or_create_entity_by_id(state, id)
            
            if not entity then
                local drawableSnapshot = pSnap.drawable or {}
                -- Create new projectile
                local projectile = {
                    entityId = id,
                    position = { x = pSnap.position.x, y = pSnap.position.y },
                    velocity = { x = pSnap.velocity.x or 0, y = pSnap.velocity.y or 0 },
                    rotation = pSnap.rotation or 0,
                    projectile = {
                        damage = pSnap.damage or 0,
                        lifetime = pSnap.lifetime or 0,
                    },
                    drawable = {
                        type = drawableSnapshot.type or "projectile",
                        size = drawableSnapshot.size or 6,
                        color = drawableSnapshot.color,
                        glowColor = drawableSnapshot.glowColor,
                        shape = drawableSnapshot.shape,
                    },
                    faction = pSnap.faction,
                    playerProjectile = pSnap.playerProjectile,
                    enemyProjectile = pSnap.enemyProjectile,
                }
                
                -- Create physics body
                if state.physicsWorld then
                    local body = love.physics.newBody(state.physicsWorld, pSnap.position.x, pSnap.position.y, "dynamic")
                    body:setBullet(true)
                    body:setLinearVelocity(pSnap.velocity.x or 0, pSnap.velocity.y or 0)
                    body:setAngle(pSnap.rotation or 0)
                    
                    local radius = (pSnap.drawable and pSnap.drawable.size or 6) * 0.5
                    local shape = love.physics.newCircleShape(radius)
                    local fixture = love.physics.newFixture(body, shape)
                    fixture:setSensor(true)
                    fixture:setUserData({
                        entity = projectile,
                        type = "projectile",
                        collider = "projectile"
                    })
                    
                    projectile.body = body
                    projectile.fixture = fixture
                end
                
                if state.world then
                    state.world:add(projectile)
                end
                register_entity_by_id(state, id, projectile)
            else
                -- Update existing projectile - use interpolation for smooth movement
                if entity.projectile then
                    entity.projectile.lifetime = pSnap.lifetime
                    entity.projectile.damage = pSnap.damage or entity.projectile.damage
                end

                local drawableSnapshot = pSnap.drawable or {}
                entity.drawable = entity.drawable or {}
                entity.drawable.type = drawableSnapshot.type or entity.drawable.type or "projectile"
                entity.drawable.size = drawableSnapshot.size or entity.drawable.size or 6
                entity.drawable.color = drawableSnapshot.color or entity.drawable.color
                entity.drawable.glowColor = drawableSnapshot.glowColor or entity.drawable.glowColor
                entity.drawable.shape = drawableSnapshot.shape or entity.drawable.shape

                -- Use interpolation for projectiles too (smoother movement, less jitter)
                if not entity.netInterp or not entity.netInterp.initialized then
                    initialize_interpolation(entity, pSnap)
                else
                    update_interpolation(entity, pSnap)
                end
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
            elseif entity and entity.projectile and not seenProjectiles[id] then
                remove_entity(state, entity)
                state.entitiesById[id] = nil
            end
        end
    end
end

return Snapshot
