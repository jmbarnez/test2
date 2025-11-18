--- Save/Load system for Novus
-- Handles game state serialization, persistence, and restoration
-- Uses JSON for save file format and love.filesystem for file I/O

local json = require("libs.json")
local table_util = require("src.util.table")
local ShipRuntime = require("src.ships.runtime")
local Modules = require("src.ships.modules")
local Items = require("src.items.registry")
local PlayerManager = require("src.player.manager")
local EntitySerializer = require("src.util.entity_serializer")
local EntityIds = require("src.util.entity_ids")
local QuestTracker = require("src.quests.tracker")
local loader = require("src.blueprints.loader")
local ComponentRegistry = require("src.util.component_registry")

---@diagnostic disable-next-line: undefined-global
local love = love

--[[
    SaveLoad orchestrates all long-term persistence for Novus.  Besides the
    traditional player snapshot, it now captures the deterministic universe
    seed, every ECS entity via EntitySerializer, and the quest/UI state.  The
    helpers below deliberately mirror the structure of the runtime so the
    restore path can rebuild complex entities (ships, stations, pickups, etc.)
    without bespoke glue per system.  The optional debugDumpWorld utility lets
    us dump a raw entity snapshot for troubleshooting or regression tests.
]]
local SaveLoad = {}

local SAVE_FILE_NAME = "savegame.json"
local SAVE_VERSION = 1

local function copy_into_table(target, source)
    if type(source) ~= "table" then
        return target
    end

    target = target or {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = table_util.deep_copy(value)
        else
            target[key] = value
        end
    end
    return target
end

local function apply_body_state(entity, data)
    if not (entity and entity.body and not entity.body:isDestroyed()) then
        return
    end

    local body = entity.body
    if data.position then
        body:setPosition(data.position.x or 0, data.position.y or 0)
    end
    if data.rotation then
        body:setAngle(data.rotation)
    end
    if data.velocity then
        body:setLinearVelocity(data.velocity.x or 0, data.velocity.y or 0)
    end
    if data.angularVelocity then
        body:setAngularVelocity(data.angularVelocity)
    end
end

local function apply_snapshot_payload(entity, snapshot)
    if not (entity and snapshot) then
        return
    end

    local data = snapshot.data or {}

    -- Use component registry for generic deserialization
    -- This automatically handles all registered components
    ComponentRegistry.deserializeEntity(entity, data)

    -- Apply physics body state after component deserialization
    apply_body_state(entity, data)
end

local function instantiate_pickup_from_snapshot(state, snapshot)
    local data = snapshot.data or {}
    local pickup = data.pickup
    if not (pickup and state and state.world) then
        return nil, false
    end

    local drop = {
        id = pickup.itemId or (pickup.item and pickup.item.id),
        item = pickup.item,
        quantity = pickup.quantity,
        position = data.position,
        velocity = data.velocity,
        collectRadius = pickup.collectRadius,
        lifetime = pickup.lifetime,
    }

    local Entities = require("src.states.gameplay.entities")
    local entity = Entities.spawnLootPickup(state, drop)
    return entity, true
end

local function instantiate_entity_from_snapshot(state, snapshot)
    if not (state and snapshot) then
        return nil, false
    end

    if snapshot.archetype == "pickup" then
        return instantiate_pickup_from_snapshot(state, snapshot)
    end

    local blueprint = snapshot.blueprint
    if not blueprint then
        return nil, false
    end

    local context = {
        physicsWorld = state.physicsWorld,
        worldBounds = state.worldBounds,
        position = snapshot.data and table_util.deep_copy(snapshot.data.position or nil) or nil,
        rotation = snapshot.data and snapshot.data.rotation or nil,
    }

    local ok, entityOrError = pcall(loader.instantiate, blueprint.category, blueprint.id, context)
    if not ok then
        print(string.format("[SaveLoad] Failed to instantiate '%s/%s' from snapshot: %s", blueprint.category or "?", blueprint.id or "?", tostring(entityOrError)))
        return nil, false
    end

    local entity = entityOrError
    local snapshotId = snapshot.id
    if type(snapshotId) == "string" and snapshotId ~= "" then
        EntityIds.assign(entity, snapshotId)
    else
        EntityIds.ensure(entity)
    end
    entity.blueprint = entity.blueprint or blueprint
    apply_snapshot_payload(entity, snapshot)

    return entity, false
end

local function restore_world_entities(state, snapshots)
    if not (state and state.world and type(snapshots) == "table") then
        return
    end

    state.stationEntities = nil

    for index = 1, #snapshots do
        local snapshot = snapshots[index]
        local entity, alreadyAdded = instantiate_entity_from_snapshot(state, snapshot)
        if entity then
            if not alreadyAdded then
                state.world:add(entity)
            end

            if entity.station then
                state.stationEntities = state.stationEntities or {}
                state.stationEntities[#state.stationEntities + 1] = entity
            end
        end
    end
end

--- Serializes cargo items from an entity
---@param cargo table
---@return table|nil
local function serialize_cargo_items(cargo)
    if type(cargo) ~= "table" or type(cargo.items) ~= "table" then
        return nil
    end

    local items = {}
    for i = 1, #cargo.items do
        local item = cargo.items[i]
        if type(item) == "table" then
            items[#items + 1] = {
                id = item.id,
                name = item.name,
                quantity = item.quantity or 1,
                volume = item.volume,
                icon = item.icon,
                installed = item.installed,
                moduleSlotId = item.moduleSlotId,
            }
        end
    end

    return items
end

--- Serializes the player's ship entity
---@param entity table
---@return table|nil
local function serialize_player_ship(entity)
    if type(entity) ~= "table" then
        return nil
    end

    local snapshot = ShipRuntime.serialize(entity)
    if not snapshot then
        return nil
    end

    -- Add cargo items (not included in runtime.serialize)
    if entity.cargo then
        snapshot.cargo = snapshot.cargo or {}
        snapshot.cargo.items = serialize_cargo_items(entity.cargo)
    end

    return snapshot
end

--- Serializes the current game state
---@param state table The gameplay state
---@return table|nil
function SaveLoad.serialize(state)
    if type(state) ~= "table" then
        return nil
    end

    local player = PlayerManager and PlayerManager.getCurrentShip(state)
        or state.player
        or state.playerShip
        or (state.pilot and state.pilot.ship)

    if not player then
        print("[SaveLoad] Cannot save: no player ship found")
        return nil
    end

    local pilot = PlayerManager and PlayerManager.getPilot(state)
        or state.playerPilot
        or state.pilot

    local pilotSnapshot
    if pilot then
        pilotSnapshot = {
            name = pilot.name,
            level = table_util.deep_copy(pilot.level or {}),
            skills = table_util.deep_copy(pilot.skills or {}),
        }
    end

    local currency = state.playerCurrency
    if currency == nil and PlayerManager and PlayerManager.getCurrency then
        currency = PlayerManager.getCurrency(state)
    end

    local saveData = {
        version = SAVE_VERSION,
        timestamp = os.time(),
        sector = state.currentSectorId or "default_sector",
        universe = {
            seed = state.universeSeed,
        },
        player = {
            ship = serialize_player_ship(player),
            currency = currency or 0,
            pilot = pilotSnapshot,
        },
    }

    local worldEntities = EntitySerializer.serialize_world(state)
    if worldEntities and #worldEntities > 0 then
        saveData.world = {
            entities = worldEntities,
        }
    end

    local questData = QuestTracker.serialize(state)
    if questData then
        saveData.quests = questData
    end

    return saveData
end

--- Saves the current game state to disk
---@param state table The gameplay state
---@return boolean success
---@return string|nil error
function SaveLoad.saveGame(state)
    print("[SaveLoad] Starting save process...")
    
    print("[SaveLoad] Serializing game state...")
    local saveData = SaveLoad.serialize(state)
    if not saveData then
        return false, "Failed to serialize game state"
    end
    print("[SaveLoad] Game state serialization complete")

    print("[SaveLoad] Encoding to JSON...")
    local ok, jsonString = pcall(json.encode, saveData)
    if not ok then
        local errorMsg = "Failed to encode save data: " .. tostring(jsonString)
        print("[SaveLoad] ERROR: " .. errorMsg)
        return false, errorMsg
    end
    local sizeKB = math.floor(#jsonString / 1024)
    print(string.format("[SaveLoad] JSON encoding complete (%d KB)", sizeKB))

    print("[SaveLoad] Writing to disk...")
    local writeOk, writeError = pcall(love.filesystem.write, SAVE_FILE_NAME, jsonString)
    if not writeOk then
        local errorMsg = "Failed to write save file: " .. tostring(writeError)
        print("[SaveLoad] ERROR: " .. errorMsg)
        return false, errorMsg
    end

    print("[SaveLoad] Game saved successfully to " .. SAVE_FILE_NAME)
    return true
end

--- Checks if a save file exists
---@return boolean
function SaveLoad.saveExists()
    if not (love and love.filesystem and love.filesystem.getInfo) then
        return false
    end

    local info = love.filesystem.getInfo(SAVE_FILE_NAME)
    return info ~= nil and info.type == "file"
end

--- Loads save data from disk
---@return table|nil saveData
---@return string|nil error
function SaveLoad.loadSaveData()
    if not SaveLoad.saveExists() then
        return nil, "Save file does not exist"
    end

    local readOk, contents = pcall(love.filesystem.read, SAVE_FILE_NAME)
    if not readOk then
        return nil, "Failed to read save file: " .. tostring(contents)
    end

    local decodeOk, saveData = pcall(json.decode, contents)
    if not decodeOk then
        return nil, "Failed to decode save file: " .. tostring(saveData)
    end

    if type(saveData) ~= "table" then
        return nil, "Invalid save data format"
    end

    if saveData.version ~= SAVE_VERSION then
        return nil, string.format("Incompatible save version (expected %d, got %s)", 
            SAVE_VERSION, tostring(saveData.version))
    end

    print("[SaveLoad] Save data loaded successfully")
    return saveData
end

--- Restores cargo items to an entity
---@param entity table
---@param itemsData table
local function restore_cargo_items(entity, itemsData)
    if type(entity.cargo) ~= "table" or type(itemsData) ~= "table" then
        return
    end

    entity.cargo.items = {}
    
    for i = 1, #itemsData do
        local itemData = itemsData[i]
        if type(itemData) == "table" and itemData.id then
            local item = Items.instantiate(itemData.id, {
                quantity = itemData.quantity,
                installed = itemData.installed,
                moduleSlotId = itemData.moduleSlotId,
            })
            
            if item then
                -- Restore additional properties
                item.name = itemData.name or item.name
                item.volume = itemData.volume or item.volume
                item.icon = itemData.icon or item.icon
                entity.cargo.items[#entity.cargo.items + 1] = item
            end
        end
    end

    entity.cargo.dirty = true
end

--- Restores the player's ship from save data
---@param state table The gameplay state
---@param shipSnapshot table
---@return table|nil entity
local function restore_player_ship(state, shipSnapshot)
    if type(shipSnapshot) ~= "table" or not shipSnapshot.blueprint then
        return nil
    end

    local blueprint = shipSnapshot.blueprint
    
    -- Create context for ship instantiation
    local context = {
        physicsWorld = state.physicsWorld,
        worldBounds = state.worldBounds,
        position = shipSnapshot.position,
        rotation = shipSnapshot.rotation,
    }

    -- Instantiate ship from blueprint
    local entity = loader.instantiate(blueprint.category, blueprint.id, context)
    if not entity then
        return nil
    end

    -- Restore cargo items BEFORE applying snapshot (modules need items in cargo)
    if shipSnapshot.cargo and shipSnapshot.cargo.items then
        restore_cargo_items(entity, shipSnapshot.cargo.items)
    end

    -- Apply saved state
    ShipRuntime.applySnapshot(entity, shipSnapshot)

    -- Update physics body position and velocity
    if entity.body and not entity.body:isDestroyed() then
        if shipSnapshot.position then
            entity.body:setPosition(shipSnapshot.position.x, shipSnapshot.position.y)
        end
        if shipSnapshot.rotation then
            entity.body:setAngle(shipSnapshot.rotation)
        end
        if shipSnapshot.velocity then
            entity.body:setLinearVelocity(shipSnapshot.velocity.x or 0, shipSnapshot.velocity.y or 0)
        end
        if shipSnapshot.angularVelocity then
            entity.body:setAngularVelocity(shipSnapshot.angularVelocity)
        end
    end

    return entity
end

--- Restores the game state from save data
---@param state table The gameplay state
---@param saveData table
---@return boolean success
---@return string|nil error
function SaveLoad.restoreGameState(state, saveData)
    if type(state) ~= "table" or type(saveData) ~= "table" then
        return false, "Invalid state or save data"
    end

    local playerData = saveData.player
    if type(playerData) ~= "table" then
        return false, "Invalid player data in save file"
    end

    -- Restore player ship
    if playerData.ship then
        local player = restore_player_ship(state, playerData.ship)
        if not player then
            return false, "Failed to restore player ship"
        end

        -- Mark as player entity
        player.player = true
        player.playerId = 1

        -- Add to ECS world
        if state.world and state.world.add then
            state.world:add(player)
        end

        -- Register with player manager
        local PlayerManager = require("src.player.manager")
        PlayerManager.ensurePilot(state)
        PlayerManager.attachShip(state, player)
    end

    -- Restore pilot data
    if playerData.pilot then
        state.pilot = state.pilot or {}
        state.pilot.name = playerData.pilot.name or state.pilot.name
        
        if playerData.pilot.level then
            state.pilot.level = table_util.deep_copy(playerData.pilot.level)
        end
        
        if playerData.pilot.skills then
            state.pilot.skills = table_util.deep_copy(playerData.pilot.skills)
            local PlayerSkills = require("src.player.skills")
            PlayerSkills.ensureSkillTree(state.pilot)
        end
    end

    -- Restore currency
    if playerData.currency then
        state.playerCurrency = playerData.currency
    end
    local PlayerCurrency = require("src.player.currency")
    if PlayerCurrency and PlayerCurrency.sync then
        local ship = PlayerManager and PlayerManager.getCurrentShip and PlayerManager.getCurrentShip(state)
        PlayerCurrency.sync(state, ship)
    end

    if saveData.universe and saveData.universe.seed then
        state.universeSeed = saveData.universe.seed
    end

    if saveData.world and saveData.world.entities then
        restore_world_entities(state, saveData.world.entities)
    end

    if saveData.quests then
        QuestTracker.restore(state, saveData.quests)
    end

    print("[SaveLoad] Game state restored successfully")
    return true
end

--- Loads a saved game into the current state
---@param state table The gameplay state
---@param saveData table|nil Preloaded save data to use instead of reading from disk
---@return boolean success
---@return string|nil error
function SaveLoad.loadGame(state, saveData)
    state.skipProceduralSpawns = true
    local loadError
    if not saveData then
        saveData, loadError = SaveLoad.loadSaveData()
        if not saveData then
            state.skipProceduralSpawns = nil
            return false, loadError
        end
    end

    -- Clear existing entities before loading
    local Entities = require("src.states.gameplay.entities")
    if state.world then
        Entities.destroyWorldEntities(state.world)
    end

    -- Clear player state
    local PlayerManager = require("src.player.manager")
    PlayerManager.clearShip(state)

    -- Restore game state
    local restoreOk, restoreError = SaveLoad.restoreGameState(state, saveData)
    if not restoreOk then
        state.skipProceduralSpawns = nil
        return false, restoreError
    end

    -- Update camera to follow restored player
    local View = require("src.states.gameplay.view")
    View.updateCamera(state)

    -- Reattach engine trail
    if state.engineTrail then
        local player = PlayerManager.getCurrentShip(state)
        if player then
            state.engineTrail:clear()
            state.engineTrail:attachPlayer(player)
        end
    end

    state.skipProceduralSpawns = nil
    return true
end

function SaveLoad.debugDumpWorld(state)
    if not state then
        return false, "No gameplay state"
    end

    local snapshot = EntitySerializer.serialize_world(state)
    if not snapshot or #snapshot == 0 then
        return false, "World is empty"
    end

    local ok, encoded = pcall(json.encode, snapshot)
    if not ok then
        return false, "Failed to encode world snapshot"
    end

    local writeOk, err = pcall(love.filesystem.write, "world_dump.json", encoded)
    if not writeOk then
        return false, tostring(err)
    end

    return true
end

return SaveLoad
