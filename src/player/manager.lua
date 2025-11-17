-- PlayerManager: Coordinating facade for player management subsystems
-- Delegates to specialized modules for registry, currency, and skills
-- Maintains backward compatibility while providing a cleaner internal structure

local PlayerWeapons = require("src.player.weapons")
local PlayerRegistry = require("src.player.registry")
local PlayerCurrency = require("src.player.currency")
local PlayerSkills = require("src.player.skills")

---@diagnostic disable-next-line: undefined-global
local love = love

local PlayerManager = {}

--- Resolves state reference from various context types
---@param context table The context object
---@return table|nil The state reference
local function resolve_state_reference(context)
    if not context then
        return nil
    end

    if type(context.state) == "table" then
        return context.state
    end

    return context
end

--- Ensures a pilot record exists for a player
---@param state table The game state
---@param playerId string|nil The player ID
---@return table|nil The pilot data
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

    PlayerSkills.ensureSkillTree(pilot)

    return pilot
end

--- Gets the pilot data for the current player
---@param state table The game state
---@return table|nil The pilot data
function PlayerManager.getPilot(state)
    if not state then
        return nil
    end
    return state.playerPilot
end

-- ============================================================================
-- CURRENCY MANAGEMENT (delegates to PlayerCurrency)
-- ============================================================================

function PlayerManager.getCurrency(context)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    local ship = PlayerRegistry.getCurrentShip(state)
    return PlayerCurrency.get(state, ship)
end

function PlayerManager.setCurrency(context, amount)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    local ship = PlayerRegistry.getCurrentShip(state)
    return PlayerCurrency.set(state, amount, ship)
end

function PlayerManager.adjustCurrency(context, delta)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    local ship = PlayerRegistry.getCurrentShip(state)
    return PlayerCurrency.adjust(state, delta, ship)
end

function PlayerManager.syncCurrency(context)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    local ship = PlayerRegistry.getCurrentShip(state)
    return PlayerCurrency.sync(state, ship)
end

-- ============================================================================
-- SKILL MANAGEMENT (delegates to PlayerSkills)
-- ============================================================================

function PlayerManager.addSkillXP(state, categoryId, skillId, amount, playerId)
    amount = tonumber(amount) or 0
    if not (state and categoryId and skillId) or amount <= 0 then
        return false
    end

    local resolvedPlayerId = playerId or state.localPlayerId
    local pilot = PlayerManager.ensurePilot(state, resolvedPlayerId)
    if not pilot then
        return false
    end

    return PlayerSkills.addXP(pilot, categoryId, skillId, amount)
end

function PlayerManager.applyLevel(state, levelData, playerId)
    local pilot = PlayerManager.ensurePilot(state, playerId)
    if not pilot then
        return nil
    end

    return PlayerSkills.applyLevel(pilot, levelData)
end

-- ============================================================================
-- PLAYER REGISTRY (delegates to PlayerRegistry)
-- ============================================================================

function PlayerManager.getCurrentShip(state)
    return PlayerRegistry.getCurrentShip(state)
end

function PlayerManager.getLocalPlayer(state)
    return PlayerRegistry.getLocalPlayer(state)
end

function PlayerManager.resolveLocalPlayer(context)
    return PlayerRegistry.resolveLocalPlayer(context)
end

function PlayerManager.collectAllPlayers(state)
    return PlayerRegistry.collectAllPlayers(state)
end

function PlayerManager.getPlayerById(state, playerId)
    return PlayerRegistry.getPlayerById(state, playerId)
end

-- ============================================================================
-- SHIP ATTACHMENT & LIFECYCLE
-- ============================================================================

--- Attaches a ship entity to a player
---@param state table The game state
---@param shipEntity table The ship entity to attach
---@param levelData number|table|nil Optional level data
---@param playerId string|nil Optional player ID
---@return table The ship entity
function PlayerManager.attachShip(state, shipEntity, levelData, playerId)
    if not (state and shipEntity) then
        return shipEntity
    end

    -- Register the ship in the player registry
    local resolvedPlayerId = PlayerRegistry.register(state, shipEntity, playerId)

    -- Determine if this is the local player
    local existingLocalShip = PlayerRegistry.getCurrentShip(state)
    local hasLocalId = state.localPlayerId ~= nil
    local isLocalPlayer = (existingLocalShip == shipEntity)
        or (hasLocalId and state.localPlayerId == resolvedPlayerId)
        or (not hasLocalId and existingLocalShip == nil)

    if isLocalPlayer then
        state.localPlayerId = resolvedPlayerId

        -- Create/update pilot and attach to ship
        local pilot = PlayerManager.applyLevel(state, levelData, resolvedPlayerId)
        shipEntity.level = nil
        shipEntity.pilot = pilot

        if pilot then
            pilot.playerId = resolvedPlayerId
            pilot.currentShip = shipEntity
        end

        state.playerShip = shipEntity
        state.player = shipEntity

        -- Initialize currency
        PlayerCurrency.initializeForEntity(state, shipEntity, true)
    else
        -- Remote player - store level data on entity
        shipEntity.pilot = nil
        if levelData then
            local table_util = require("src.util.table")
            shipEntity.level = table_util.deep_copy(levelData)
        end
    end

    -- Initialize weapon systems
    if shipEntity then
        PlayerWeapons.initialize(shipEntity)
    end

    -- Initialize hotbar
    if shipEntity then
        local HotbarManager = require("src.player.hotbar")
        HotbarManager.initialize(shipEntity)
        -- Autopopulate hotbar with cargo items
        HotbarManager.autopopulate(shipEntity)
    end

    return shipEntity
end

--- Clears/detaches a ship entity from the player
---@param state table The game state
---@param shipEntity table|nil Optional specific ship to clear
function PlayerManager.clearShip(state, shipEntity)
    if not state then
        return
    end

    PlayerRegistry.unregister(state, shipEntity)
end

return PlayerManager
