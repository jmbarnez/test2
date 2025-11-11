local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")
local Items = require("src.items.registry")
local damage_numbers = require("src.systems.damage_numbers")

---@diagnostic disable-next-line: undefined-global
local love = love

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

local function clone_vector(vec)
    if type(vec) ~= "table" then
        return { x = 0, y = 0 }
    end

    return {
        x = vec.x or 0,
        y = vec.y or 0,
    }
end

local DEFAULT_STATION_BUFFER = 260
local FALLBACK_PLAYER_OFFSET = 600

local function find_station_anchor(state)
    if not state then
        return nil
    end

    local stations = state.stationEntities
    if type(stations) == "table" then
        for i = 1, #stations do
            local station = stations[i]
            if station and station.position then
                return station
            end
        end
    end

    return nil
end

local function resolve_player_spawn_position(state)
    local station = find_station_anchor(state)
    if station then
        local pos = station.position or { x = 0, y = 0 }
        local baseRadius = station.mountRadius
            or (station.drawable and station.drawable.radius)
            or station.radius
            or 0

        local clearance = baseRadius + DEFAULT_STATION_BUFFER
        local angle = station.rotation or 0

        local dx = math.cos(angle) * clearance
        local dy = math.sin(angle) * clearance

        return {
            x = (pos.x or 0) + dx,
            y = (pos.y or 0) + dy,
        }
    end

    local bounds = state and state.worldBounds
    if bounds then
        return {
            x = (bounds.x or 0) + (bounds.width or 0) * 0.5 + FALLBACK_PLAYER_OFFSET,
            y = (bounds.y or 0) + (bounds.height or 0) * 0.5,
        }
    end

    return nil
end

function Entities.createShip(context, shipId, overrides)
    local instantiateContext = clone_overrides(overrides) or {}
    instantiateContext.physicsWorld = context.physicsWorld
    instantiateContext.worldBounds = context.worldBounds

    return loader.instantiate("ships", shipId, instantiateContext)
end

local function resolve_station_context(state, spec)
    local instantiateContext = {
        physicsWorld = state.physicsWorld,
        worldBounds = state.worldBounds,
    }

    local offsetX, offsetY = 0, 0
    if type(spec) == "table" then
        local offset = spec.offset
        if type(offset) == "table" then
            offsetX = offset.x or 0
            offsetY = offset.y or 0
        end

        if spec.position then
            local basePosition = clone_vector(spec.position)
            instantiateContext.position = {
                x = basePosition.x + offsetX,
                y = basePosition.y + offsetY,
            }
            offsetX, offsetY = 0, 0
        end

        if spec.rotation ~= nil then
            instantiateContext.rotation = spec.rotation
        end

        if spec.context then
            for key, value in pairs(spec.context) do
                if instantiateContext[key] == nil then
                    instantiateContext[key] = value
                end
            end
        end
    end

    if not instantiateContext.position then
        local bounds = state.worldBounds
        if bounds then
            instantiateContext.position = {
                x = (bounds.x or 0) + (bounds.width or 0) * 0.5 + offsetX,
                y = (bounds.y or 0) + (bounds.height or 0) * 0.5 + offsetY,
            }
        else
            instantiateContext.position = { x = offsetX, y = offsetY }
        end
    end

    return instantiateContext
end

local function resolve_station_id(spec)
    if type(spec) == "table" then
        return spec.id or spec.stationId or spec.blueprint or spec[1]
    end
    return spec
end

function Entities.spawnStation(state, spec)
    if not (state and state.world and state.physicsWorld) then
        return nil
    end

    local stationId = resolve_station_id(spec) or "hub_station"
    local instantiateContext = resolve_station_context(state, spec)

    local ok, station = pcall(loader.instantiate, "stations", stationId, instantiateContext)
    if not ok then
        print(string.format("[entities] Failed to spawn station '%s': %s", tostring(stationId), tostring(station)))
        return nil
    end

    station.position = station.position or clone_vector(instantiateContext.position)

    local world = state.world
    local stationEntity = world:add(station)

    state.stationEntities = state.stationEntities or {}
    state.stationEntities[#state.stationEntities + 1] = stationEntity

    return stationEntity
end

function Entities.spawnStations(state, configs)
    if not (state and state.world) or not configs then
        return nil
    end

    state.stationEntities = {}

    if type(configs) ~= "table" then
        return Entities.spawnStation(state, configs)
    end

    local lastSpawned
    if configs[1] ~= nil then
        for index = 1, #configs do
            lastSpawned = Entities.spawnStation(state, configs[index]) or lastSpawned
        end
    else
        for _, spec in pairs(configs) do
            lastSpawned = Entities.spawnStation(state, spec) or lastSpawned
        end
    end

    return lastSpawned
end

local function looks_like_spawn_config(value)
    if type(value) ~= "table" then
        return false
    end

    return value.playerId ~= nil
        or value.shipId ~= nil
        or value.ship ~= nil
        or value.id ~= nil
        or value.overrides ~= nil
        or value.level ~= nil
        or value.controlProfile ~= nil
end

function Entities.spawnPlayer(state, shipIdOrConfig, overrides)
    local config

    if type(shipIdOrConfig) == "table" and overrides == nil and looks_like_spawn_config(shipIdOrConfig) then
        config = clone_overrides(shipIdOrConfig)
    else
        config = {
            shipId = shipIdOrConfig,
            overrides = overrides,
        }
    end

    local chosenShipId = (config and config.shipId) or STARTER_SHIP_ID
    local instantiateOverrides = config and config.overrides and clone_overrides(config.overrides) or nil

    if not (instantiateOverrides and instantiateOverrides.position) then
        local spawnPosition = resolve_player_spawn_position(state)
        if spawnPosition then
            instantiateOverrides = instantiateOverrides or {}
            instantiateOverrides.position = spawnPosition
        end
    end

    local levelData
    if instantiateOverrides and instantiateOverrides.level then
        levelData = clone_overrides(instantiateOverrides.level)
        instantiateOverrides.level = nil
    elseif config and config.level ~= nil then
        if type(config.level) == "table" then
            levelData = clone_overrides(config.level)
        elseif type(config.level) == "number" then
            levelData = { current = config.level }
        end
    end

    local playerShip = Entities.createShip(state, chosenShipId, instantiateOverrides)
    local world = state.world
    if not world or not playerShip then
        return nil
    end

    local shipEntity = world:add(playerShip)

    local playerId = config.playerId or "player"
    PlayerManager.attachShip(state, shipEntity, levelData, playerId)

    return shipEntity
end

function Entities.damage(entity, amount, source)
    if not entity or not entity.health then
        return
    end

    local previous = entity.health.current or entity.health.max or 0
    entity.health.current = math.max(0, previous - amount)

    if source ~= nil then
        entity.lastDamageSource = source

        local playerId = source.playerId
            or source.ownerPlayerId
            or (source.owner and source.owner.playerId)

        if not playerId and source.player then
            playerId = source.playerId or (source.player and source.player.playerId)
        end

        if not playerId and source.lastDamagePlayerId then
            playerId = source.lastDamagePlayerId
        end

        if playerId then
            entity.lastDamagePlayerId = playerId
        end
    end

    if entity.healthBar then
        entity.health.showTimer = entity.healthBar.showDuration or 0
    end

    if entity.health.current <= 0 then
        entity.pendingDestroy = true
    end

    if amount and amount > 0 then
        local contextHost = entity.damageContext
            or (source and source.damageContext)
            or (source and source.state)
            or entity.state
        damage_numbers.push(contextHost, entity, amount)
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

function Entities.clearNonLocalEntities(state)
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
        if entity.body and not entity.body:isDestroyed() then
            entity.body:destroy()
        end
        world:remove(entity)
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

function Entities.spawnLootPickup(state, drop)
    if not (state and state.world and drop and drop.position) then
        return nil
    end

    local item = drop.item
    if not item and drop.id then
        local instantiated = Items.instantiate(drop.id, {
            quantity = drop.quantity,
            name = drop.name,
        })
        if instantiated then
            item = instantiated
        end
    end

    if not item then
        return nil
    end

    local quantity = drop.quantity or item.quantity or 1
    item.quantity = quantity

    local position = drop.position
    local velocity = drop.velocity or {}

    local function scaled_size(value)
        if type(value) ~= "number" then
            return nil
        end
        local scaled = value / 3
        if scaled <= 0 then
            scaled = value
        end
        return scaled
    end

    if not (velocity.x or velocity.y) then
        velocity = {
            x = (love and love.math and (love.math.random() - 0.5) or 0) * 20,
            y = (love and love.math and (love.math.random() - 0.5) or 0) * 20,
        }
    end

    local entity = {
        pickup = {
            item = item,
            itemId = item.id,
            quantity = quantity,
            collectRadius = drop.collectRadius or 48,
            lifetime = drop.lifetime or 45,
            age = 0,
            source = drop.source,
        },
        position = {
            x = position.x or 0,
            y = position.y or 0,
        },
        velocity = {
            x = velocity.x or 0,
            y = velocity.y or 0,
        },
        drawable = {
            type = "pickup",
            icon = item.icon,
            size = scaled_size(drop.size or 28) or 28,
            spinSpeed = drop.spinSpeed or 0.6,
            bobAmplitude = drop.bobAmplitude or 4,
        },
        rotation = drop.initialRotation or 0,
    }

    return state.world:add(entity)
end

return Entities
