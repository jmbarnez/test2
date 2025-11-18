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
local HASH_ALGORITHM = "sha256"

local function is_array(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local count = 0
    for key in pairs(tbl) do
        if type(key) ~= "number" or key <= 0 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end

    return count == #tbl
end

local function sort_keys(keys)
    local type_order = {
        string = 1,
        number = 2,
        boolean = 3,
    }

    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then
            return (type_order[ta] or 99) < (type_order[tb] or 99)
        end

        if ta == "string" then
            return a < b
        elseif ta == "number" then
            return a < b
        elseif ta == "boolean" then
            return (a and 1 or 0) > (b and 1 or 0)
        end

        return tostring(a) < tostring(b)
    end)

    return keys
end

local function append_key_signature(key, buffer)
    local keyType = type(key)
    if keyType == "string" then
        buffer[#buffer + 1] = "ks:" .. #key .. ":" .. key .. ";"
    elseif keyType == "number" then
        buffer[#buffer + 1] = "kn:" .. string.format("%.17g", key) .. ";"
    elseif keyType == "boolean" then
        buffer[#buffer + 1] = key and "kb:1;" or "kb:0;"
    else
        buffer[#buffer + 1] = "ku:" .. tostring(key) .. ";"
    end
end

local function append_value_signature(value, buffer, seen)
    local valueType = type(value)

    if valueType == "nil" then
        buffer[#buffer + 1] = "v:nil;"
    elseif valueType == "boolean" then
        buffer[#buffer + 1] = value and "v:b:1;" or "v:b:0;"
    elseif valueType == "number" then
        buffer[#buffer + 1] = "v:n:" .. string.format("%.17g", value) .. ";"
    elseif valueType == "string" then
        buffer[#buffer + 1] = "v:s:" .. #value .. ":" .. value .. ";"
    elseif valueType == "table" then
        if seen[value] then
            error("Cannot compute checksum for cyclic tables")
        end

        seen[value] = true

        if is_array(value) then
            buffer[#buffer + 1] = "v:a:" .. #value .. ":["
            for index = 1, #value do
                append_value_signature(value[index], buffer, seen)
            end
            buffer[#buffer + 1] = "];"
        else
            local keys = {}
            for key in pairs(value) do
                keys[#keys + 1] = key
            end

            sort_keys(keys)

            buffer[#buffer + 1] = "v:t:" .. #keys .. ":{"
            for i = 1, #keys do
                local key = keys[i]
                append_key_signature(key, buffer)
                append_value_signature(value[key], buffer, seen)
            end
            buffer[#buffer + 1] = "};"
        end

        seen[value] = nil
    else
        buffer[#buffer + 1] = "v:u:" .. tostring(value) .. ";"
    end
end

local function compute_checksum(payload)
    if not (love and love.data and love.data.hash) then
        return nil, "love.data.hash is unavailable"
    end

    local buffer = {}
    local ok, err = pcall(function()
        append_value_signature(payload, buffer, {})
    end)

    if not ok then
        return nil, err
    end

    local signature = table.concat(buffer, "")
    local hashOk, hashValue = pcall(love.data.hash, HASH_ALGORITHM, signature)
    if not hashOk then
        return nil, hashValue
    end

    return hashValue
end

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

    -- For procedural entities, use the full blueprint directly instead of loading from file
    local entity, entityOrError
    if blueprint._procedural then
        -- Procedural blueprint - get factory and instantiate directly
        local category = blueprint.category
        local factoryModule = category == "ships" and require("src.entities.ship_factory") or nil
        
        if factoryModule and factoryModule.instantiate then
            local ok, result = pcall(factoryModule.instantiate, blueprint, context)
            if ok then
                entity = result
                -- Ensure the full blueprint is attached to the entity
                entity.blueprint = blueprint
            else
                entityOrError = result
            end
        else
            entityOrError = string.format("No factory found for procedural category '%s'", tostring(category))
        end
    else
        -- File-based blueprint - load normally
        local ok, result = pcall(loader.instantiate, blueprint.category, blueprint.id, context)
        if ok then
            entity = result
        else
            entityOrError = result
        end
    end

    if not entity then
        return nil, false
    end

    local snapshotId = snapshot.id
    if type(snapshotId) == "string" and snapshotId ~= "" then
        EntityIds.assign(entity, snapshotId)
    else
        EntityIds.ensure(entity)
    end
    -- Ensure the entity has the full blueprint with all metadata (including _procedural)
    if not entity.blueprint then
        entity.blueprint = blueprint
    elseif blueprint._procedural or blueprint._seed or blueprint._size_class then
        -- If restoring a procedural entity, ensure metadata is preserved
        entity.blueprint._procedural = blueprint._procedural
        entity.blueprint._seed = blueprint._seed
        entity.blueprint._size_class = blueprint._size_class
    end
    apply_snapshot_payload(entity, snapshot)

    return entity, false
end

local function restore_world_entities(state, snapshots)
    if not (state and state.world and type(snapshots) == "table") then
        return
    end

    state.stationEntities = nil
    local restoredCount = 0

    for index = 1, #snapshots do
        local snapshot = snapshots[index]
        local entity, alreadyAdded = instantiate_entity_from_snapshot(state, snapshot)
        if entity then
            if not alreadyAdded then
                state.world:add(entity)
            end
            restoredCount = restoredCount + 1

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
function SaveLoad.serialize(state, options)
    if type(state) ~= "table" then
        return nil
    end

    local player = PlayerManager and PlayerManager.getCurrentShip(state)
        or state.player
        or state.playerShip
        or (state.pilot and state.pilot.ship)

    if not player then
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

    local worldOptions = options or {}
    local worldEntities = EntitySerializer.serialize_world(state, worldOptions)
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
    state.saveProgress = state.saveProgress or {
        isSaving = false,
        current = 0,
        total = 0,
        status = "",
        error = false,
        completedAt = nil,
    }

    local progressState = state.saveProgress
    progressState.isSaving = true
    progressState.error = false
    progressState.current = 0
    local world = state.world
    if world and world.entities then
        progressState.total = #world.entities
    else
        progressState.total = 0
    end
    progressState.status = "Preparing..."
    progressState.completedAt = nil

    local function on_progress(current, total)
        progressState.current = current
        progressState.total = total
        local percent
        if total and total > 0 then
            percent = math.floor((current / total) * 100)
        end

        if percent then
            progressState.status = string.format("Saving... %d%% (%d / %d)", percent, current, total)
        else
            progressState.status = string.format("Saving... %d", current)
        end
    end

    local function yield_func()
        if love and love.timer and love.timer.sleep then
            love.timer.sleep(0)
        end
    end

    local saveData = SaveLoad.serialize(state, {
        on_progress = on_progress,
        yield_func = yield_func,
        yield_interval = 0.05,
    })
    if not saveData then
        progressState.status = "Failed"
        progressState.isSaving = false
        return false, "Failed to serialize game state"
    end

    local checksum, checksumError = compute_checksum(saveData)
    if not checksum then
        local errorMsg = "Failed to compute checksum: " .. tostring(checksumError)
        progressState.status = "Checksum Failed"
        progressState.isSaving = false
        progressState.error = true
        progressState.completedAt = love and love.timer and love.timer.getTime and love.timer.getTime() or nil
        return false, errorMsg
    end

    local envelope = {
        version = SAVE_VERSION,
        checksum = checksum,
        algorithm = HASH_ALGORITHM,
        data = saveData,
    }

    local ok, jsonString = pcall(json.encode, envelope)
    if not ok then
        local errorMsg = "Failed to encode save data: " .. tostring(jsonString)
        progressState.status = "Encode Failed"
        progressState.isSaving = false
        progressState.error = true
        progressState.completedAt = love and love.timer and love.timer.getTime and love.timer.getTime() or nil
        return false, errorMsg
    end

    local writeOk, writeError = pcall(love.filesystem.write, SAVE_FILE_NAME, jsonString)
    if not writeOk then
        local errorMsg = "Failed to write save file: " .. tostring(writeError)
        print("[SaveLoad] ERROR: " .. errorMsg)
        progressState.status = "Save Failed"
        progressState.isSaving = false
        progressState.error = true
        progressState.completedAt = love and love.timer and love.timer.getTime and love.timer.getTime() or nil
        return false, errorMsg
    end

    progressState.current = progressState.total
    progressState.status = "Game Saved"
    progressState.isSaving = false
    progressState.error = false
    progressState.completedAt = love and love.timer and love.timer.getTime and love.timer.getTime() or nil
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

    local decodeOk, decoded = pcall(json.decode, contents)
    if not decodeOk then
        return nil, "Failed to decode save file: " .. tostring(decoded)
    end

    if type(decoded) ~= "table" then
        return nil, "Invalid save data format"
    end

    local saveData = decoded
    local isWrapped = type(decoded.data) == "table" and type(decoded.checksum) == "string"

    if isWrapped then
        saveData = decoded.data

        if decoded.version and decoded.version ~= SAVE_VERSION then
            return nil, string.format(
                "Incompatible save version (expected %d, got %s)",
                SAVE_VERSION,
                tostring(decoded.version)
            )
        end

        local expectedChecksum = decoded.checksum
        local computedChecksum, checksumError = compute_checksum(saveData)
        if not computedChecksum then
            return nil, "Failed to validate save file checksum: " .. tostring(checksumError)
        end

        if computedChecksum ~= expectedChecksum then
            return nil, "Save file integrity check failed (checksum mismatch)"
        end
    end

    if saveData.version ~= SAVE_VERSION then
        return nil, string.format(
            "Incompatible save version (expected %d, got %s)",
            SAVE_VERSION,
            tostring(saveData.version)
        )
    end

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
        print("[SaveLoad] Restoring player ship...")
        local player = restore_player_ship(state, playerData.ship)
        if not player then
            print("[SaveLoad] ERROR: Failed to restore player ship!")
            return false, "Failed to restore player ship"
        end
        print("[SaveLoad] Player ship restored successfully")

        -- Mark as player entity
        player.player = true
        player.playerId = 1

        -- Add to ECS world (will be flushed later)
        if state.world and state.world.add then
            state.world:add(player)
            print("[SaveLoad] Player added to world, will flush later")
            -- Store player temporarily so we can attach it after flush
            state._restoredPlayer = player
        else
            print("[SaveLoad] ERROR: Cannot add player to world!")
        end
    else
        print("[SaveLoad] WARNING: No player ship data in save file!")
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

    return true
end

--- Loads a saved game into the current state
---@param state table The gameplay state
---@param saveData table|nil Preloaded save data to use instead of reading from disk
---@param skipClear boolean|nil If true, skip clearing existing entities (used during fresh state entry)
---@return boolean success
---@return string|nil error
function SaveLoad.loadGame(state, saveData, skipClear)
    state.skipProceduralSpawns = true
    local loadError
    if not saveData then
        saveData, loadError = SaveLoad.loadSaveData()
        if not saveData then
            state.skipProceduralSpawns = nil
            return false, loadError
        end
    end

    -- Only clear entities if not already cleared (e.g., during mid-game reload vs. initial entry)
    if not skipClear then
        -- Clear existing entities before loading
        local Entities = require("src.states.gameplay.entities")
        if state.world then
            Entities.destroyWorldEntities(state.world)
        end

        -- Clear player state
        local PlayerManager = require("src.player.manager")
        PlayerManager.clearShip(state)
    end

    -- Restore game state
    local restoreOk, restoreError = SaveLoad.restoreGameState(state, saveData)
    if not restoreOk then
        state.skipProceduralSpawns = nil
        return false, restoreError
    end

    -- Flush any pending entity additions to ensure they're immediately in the world
    -- This MUST happen before attaching the player, so entities are actually in the world
    if state.world and state.world._flush then
        print("[SaveLoad] Flushing world...")
        state.world:_flush()
        print(string.format("[SaveLoad] World flushed. Total entities: %d", #state.world.entities))
    end
    
    -- NOW attach the player to the manager AFTER it's in the world
    if state._restoredPlayer then
        local player = state._restoredPlayer
        state._restoredPlayer = nil
        print("[SaveLoad] Attaching player to manager...")
        local PlayerManager = require("src.player.manager")
        PlayerManager.ensurePilot(state)
        PlayerManager.attachShip(state, player)
        print("[SaveLoad] Player attached successfully")
    else
        print("[SaveLoad] WARNING: No _restoredPlayer found after world flush!")
    end
    
    -- Verify player is in the world AFTER flushing and attaching
    local PlayerManager = require("src.player.manager")
    local player = PlayerManager.getCurrentShip(state)
    print(string.format("[SaveLoad] Final check - player exists: %s", tostring(player ~= nil)))

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

    -- Keep skipProceduralSpawns = true so spawners won't run on first update
    -- It will be cleared after the game is fully loaded
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
