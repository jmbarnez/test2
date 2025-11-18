local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")
local Items = require("src.items.registry")
local table_util = require("src.util.table")

---@diagnostic disable-next-line: undefined-global
local love = love
local math = math

local Spawning = {}

local STARTER_SHIP_ID = constants.player.starter_ship_id
local DEFAULT_STATION_BUFFER = 260
local FALLBACK_PLAYER_OFFSET = 600

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

local function find_station_anchor(state)
    if not state then
        return nil
    end

    local stations = state.stationEntities
    if type(stations) ~= "table" or #stations == 0 then
        return nil
    end

    local referenceX, referenceY

    if state.playerShip and state.playerShip.position then
        referenceX = state.playerShip.position.x
        referenceY = state.playerShip.position.y
    elseif state.camera then
        referenceX = state.camera.x or 0
        referenceY = state.camera.y or 0
    end

    if not (referenceX and referenceY) then
        return stations[1]
    end

    local closestStation
    local closestDistSq

    for i = 1, #stations do
        local station = stations[i]
        local pos = station and station.position
        if pos then
            local dx = (pos.x or 0) - referenceX
            local dy = (pos.y or 0) - referenceY
            local distSq = dx * dx + dy * dy

            if not closestDistSq or distSq < closestDistSq then
                closestDistSq = distSq
                closestStation = station
            end
        end
    end

    return closestStation or stations[1]
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

function Spawning.createShip(context, shipId, overrides)
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

local function resolve_warpgate_context(state, spec)
    local instantiateContext = {
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

local function resolve_warpgate_id(spec)
    if type(spec) == "table" then
        return spec.id or spec.warpgateId or spec.blueprint or spec[1]
    end
    return spec
end

function Spawning.spawnStation(state, spec)
    if not (state and state.world and state.physicsWorld) then
        print("[ENTITIES] spawnStation failed - missing state/world/physicsWorld")
        return nil
    end

    local stationId = resolve_station_id(spec) or "hub_station"
    local instantiateContext = resolve_station_context(state, spec)
    
    print("[ENTITIES] spawnStation - id:", stationId, "position:", instantiateContext.position)

    local ok, station = pcall(loader.instantiate, "stations", stationId, instantiateContext)
    if not ok then
        print(string.format("[entities] Failed to spawn station '%s': %s", tostring(stationId), tostring(station)))
        return nil
    end

    station.position = station.position or clone_vector(instantiateContext.position)

    local world = state.world
    local stationEntity = world:add(station)
    
    print("[ENTITIES] Added station to world, entity:", stationEntity)

    state.stationEntities = state.stationEntities or {}
    local beforeCount = #state.stationEntities
    state.stationEntities[#state.stationEntities + 1] = stationEntity
    local afterCount = #state.stationEntities
    
    print("[ENTITIES] stationEntities count before:", beforeCount, "after:", afterCount)

    return stationEntity
end

function Spawning.spawnStations(state, configs)
    if not (state and state.world) or not configs then
        print("[ENTITIES] spawnStations failed - state:", state, "world:", state and state.world, "configs:", configs)
        return nil
    end

    state.stationEntities = {}
    print("[ENTITIES] Initializing stationEntities array, config type:", type(configs))

    if type(configs) ~= "table" then
        print("[ENTITIES] Single station config")
        return Spawning.spawnStation(state, configs)
    end

    local lastSpawned
    if configs[1] ~= nil then
        print("[ENTITIES] Array-style config with", #configs, "stations")
        for index = 1, #configs do
            print("[ENTITIES] Spawning station", index, "config:", configs[index])
            lastSpawned = Spawning.spawnStation(state, configs[index]) or lastSpawned
        end
    else
        print("[ENTITIES] Map-style config")
        for key, spec in pairs(configs) do
            print("[ENTITIES] Spawning station", key, "config:", spec)
            lastSpawned = Spawning.spawnStation(state, spec) or lastSpawned
        end
    end

    print("[ENTITIES] Finished spawning. Total stations:", #state.stationEntities)
    return lastSpawned
end

function Spawning.spawnWarpgate(state, spec)
    if not (state and state.world) then
        print("[ENTITIES] spawnWarpgate failed - missing state/world")
        return nil
    end

    local gateId = resolve_warpgate_id(spec) or "warpgate_alpha"
    local instantiateContext = resolve_warpgate_context(state, spec)

    print("[ENTITIES] spawnWarpgate - id:", gateId, "position:", instantiateContext.position)

    local ok, warpgate = pcall(loader.instantiate, "warpgates", gateId, instantiateContext)
    if not ok then
        print(string.format("[entities] Failed to spawn warpgate '%s': %s", tostring(gateId), tostring(warpgate)))
        return nil
    end

    warpgate.position = warpgate.position or clone_vector(instantiateContext.position)

    local world = state.world
    local gateEntity = world:add(warpgate)

    state.warpgateEntities = state.warpgateEntities or {}
    state.warpgateEntities[#state.warpgateEntities + 1] = gateEntity

    return gateEntity
end

function Spawning.spawnWarpgates(state, configs)
    if not (state and state.world) or not configs then
        print("[ENTITIES] spawnWarpgates failed - state/world missing or no configs")
        return nil
    end

    state.warpgateEntities = {}

    if type(configs) ~= "table" then
        return Spawning.spawnWarpgate(state, configs)
    end

    local lastSpawned
    if configs[1] ~= nil then
        for index = 1, #configs do
            lastSpawned = Spawning.spawnWarpgate(state, configs[index]) or lastSpawned
        end
    else
        for _, spec in pairs(configs) do
            lastSpawned = Spawning.spawnWarpgate(state, spec) or lastSpawned
        end
    end

    print("[ENTITIES] Finished spawning warpgates:", #state.warpgateEntities)
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

function Spawning.spawnPlayer(state, shipIdOrConfig, overrides)
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

    local playerShip = Spawning.createShip(state, chosenShipId, instantiateOverrides)
    local world = state.world
    if not world or not playerShip then
        return nil
    end

    local shipEntity = world:add(playerShip)

    local playerId = (config and config.playerId) or "player"
    PlayerManager.attachShip(state, shipEntity, levelData, playerId)

    return shipEntity
end

function Spawning.spawnLootPickup(state, drop)
    if not (state and state.world and drop and drop.position) then
        return nil
    end

    local baseItem = drop.item
    if not baseItem and drop.id then
        local instantiated = Items.instantiate(drop.id, {
            quantity = drop.quantity,
            name = drop.name,
        })
        if instantiated then
            baseItem = instantiated
        end
    end

    if not baseItem then
        return nil
    end

    local totalQuantity = drop.quantity or baseItem.quantity or 1
    if type(totalQuantity) ~= "number" then
        totalQuantity = 1
    end

    totalQuantity = math.floor(totalQuantity)
    if totalQuantity < 1 then
        return nil
    end

    local templateItem = table_util.deep_copy(baseItem)
    if not templateItem then
        return nil
    end
    templateItem.quantity = 1

    local position = drop.position
    local centerX = position and position.x or 0
    local centerY = position and position.y or 0
    local baseVelocity = drop.velocity
    local speedMultiplier = drop.speedMultiplier or 1

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

    local function resolve_burst_speed()
        local minSpeed = drop.unitBurstSpeedMin or drop.burstSpeedMin or drop.burstSpeed or 38
        local maxSpeed = drop.unitBurstSpeedMax or drop.burstSpeedMax or drop.burstSpeed or 62

        if minSpeed < 0 then
            minSpeed = 0
        end
        if maxSpeed < minSpeed then
            maxSpeed = minSpeed
        end

        if love and love.math and love.math.random then
            if maxSpeed > minSpeed then
                return love.math.random() * (maxSpeed - minSpeed) + minSpeed
            end
            return minSpeed
        end

        if maxSpeed > minSpeed then
            return (minSpeed + maxSpeed) * 0.5
        end
        return minSpeed
    end

    local function resolve_velocity(px, py)
        local vx = baseVelocity and baseVelocity.x or 0
        local vy = baseVelocity and baseVelocity.y or 0

        local dx = (px or centerX) - centerX
        local dy = (py or centerY) - centerY
        local dist = math.sqrt(dx * dx + dy * dy)

        local dirX, dirY
        if dist > 0.0001 then
            dirX, dirY = dx / dist, dy / dist
        else
            local angle = love and love.math and love.math.random()
                and love.math.random() * math.pi * 2
                or 0
            dirX, dirY = math.cos(angle), math.sin(angle)
        end

        local burstSpeed = resolve_burst_speed()
        vx = vx + dirX * burstSpeed
        vy = vy + dirY * burstSpeed

        if love and love.math and love.math.random then
            local wobble = (love.math.random() - 0.5) * 8
            local wobbleAngle = love.math.random() * math.pi * 2
            vx = vx + math.cos(wobbleAngle) * wobble
            vy = vy + math.sin(wobbleAngle) * wobble
        end

        return {
            x = vx * speedMultiplier,
            y = vy * speedMultiplier,
        }
    end

    local function spawn_single_pickup(item_instance)
        if not item_instance then
            return nil
        end

        item_instance.quantity = 1

        local px = position.x or 0
        local py = position.y or 0

        if totalQuantity > 1 then
            local radius = drop.unitScatterRadius
                or drop.singleScatterRadius
                or 10

            if radius and radius > 0 and love and love.math and love.math.random then
                local angle = love.math.random() * math.pi * 2
                local dist = love.math.random() * radius
                px = px + math.cos(angle) * dist
                py = py + math.sin(angle) * dist
            end
        end

        local entity = {
            pickup = {
                item = item_instance,
                itemId = item_instance.id,
                quantity = 1,
                collectRadius = drop.collectRadius or 48,
                lifetime = drop.lifetime or 45,
                age = 0,
                source = drop.source,
            },
            position = {
                x = px,
                y = py,
            },
            velocity = resolve_velocity(px, py),
            drawable = {
                type = "pickup",
                icon = item_instance.icon,
                size = scaled_size(drop.size or 28) or 28,
                spinSpeed = drop.spinSpeed or 0.6,
                bobAmplitude = drop.bobAmplitude or 4,
            },
            rotation = drop.initialRotation or 0,
        }

        return state.world:add(entity)
    end

    local lastEntity
    for _ = 1, totalQuantity do
        local itemCopy = table_util.deep_copy(templateItem)
        lastEntity = spawn_single_pickup(itemCopy)
    end

    return lastEntity
end

return Spawning
