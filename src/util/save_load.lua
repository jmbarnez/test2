--- Save/Load system for Novus
-- Handles game state serialization, persistence, and restoration
-- Uses JSON for save file format and love.filesystem for file I/O

local json = require("libs.json")
local table_util = require("src.util.table")
local ShipRuntime = require("src.ships.runtime")
local Modules = require("src.ships.modules")
local Items = require("src.items.registry")
local PlayerManager = require("src.player.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local SaveLoad = {}

local SAVE_FILE_NAME = "savegame.json"
local SAVE_VERSION = 1

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
        player = {
            ship = serialize_player_ship(player),
            currency = currency or 0,
            pilot = pilotSnapshot,
        },
    }

    return saveData
end

--- Saves the current game state to disk
---@param state table The gameplay state
---@return boolean success
---@return string|nil error
function SaveLoad.saveGame(state)
    local saveData = SaveLoad.serialize(state)
    if not saveData then
        return false, "Failed to serialize game state"
    end

    local ok, jsonString = pcall(json.encode, saveData)
    if not ok then
        return false, "Failed to encode save data: " .. tostring(jsonString)
    end

    local writeOk, writeError = pcall(love.filesystem.write, SAVE_FILE_NAME, jsonString)
    if not writeOk then
        return false, "Failed to write save file: " .. tostring(writeError)
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
    local loader = require("src.blueprints.loader")
    
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
        if state.world then
            state.world:addEntity(player)
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
        local PlayerCurrency = require("src.player.currency")
        PlayerCurrency.sync_to_entity(state)
    end

    print("[SaveLoad] Game state restored successfully")
    return true
end

--- Loads a saved game into the current state
---@param state table The gameplay state
---@return boolean success
---@return string|nil error
function SaveLoad.loadGame(state)
    local saveData, loadError = SaveLoad.loadSaveData()
    if not saveData then
        return false, loadError
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

    return true
end

return SaveLoad
