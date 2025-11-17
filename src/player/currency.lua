-- PlayerCurrency: Manages player currency/credits
-- Handles wallet balance tracking, modifications, and entity synchronization

local constants = require("src.constants.game")

local PlayerCurrency = {}

local STARTING_CURRENCY = (constants.player and constants.player.starting_currency) or 0

local ui_constants = (constants.ui and constants.ui.currency_panel) or {}
local GAIN_VISIBLE_DURATION = ui_constants.gain_visible_duration or 2.6
local GAIN_ANIM_DURATION = ui_constants.gain_anim_duration or 0.45

---@diagnostic disable-next-line: undefined-global
local love = love

local function get_time()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function ensure_gain_state(state)
    if not state then
        return nil
    end

    local container = state.currencyGain
    if type(container) ~= "table" then
        container = {}
        state.currencyGain = container
    end

    if container.active ~= nil and type(container.active) ~= "table" then
        container.active = nil
    end

    return container
end

local function record_gain(state, delta, balance)
    if not (state and delta and delta > 0) then
        return
    end

    local container = ensure_gain_state(state)
    if not container then
        return
    end

    local now = get_time()
    local visibleDuration = GAIN_VISIBLE_DURATION
    local animDuration = GAIN_ANIM_DURATION

    local entry = container.active
    if type(entry) ~= "table" then
        entry = nil
    end

    if entry then
        local expiresAt = tonumber(entry.expiresAt or 0) or 0
        if expiresAt > 0 and now >= expiresAt then
            entry = nil
        end
    end

    if not entry then
        entry = {
            amount = 0,
            createdAt = now,
            sequence = (container.sequence or 0) + 1,
        }
        container.sequence = entry.sequence
        container.active = entry
    end

    entry.amount = (entry.amount or 0) + delta
    entry.lastAmount = delta
    entry.balance = balance
    entry.animStart = now
    entry.animDuration = animDuration
    entry.visibleDuration = visibleDuration
    entry.expiresAt = now + visibleDuration
    entry.updatedAt = now
end

--- Extracts currency value from an entity's wallet
---@param entity table|nil The entity to extract from
---@return number|nil The currency amount, or nil if not found
local function extract_currency_from_entity(entity)
    if not entity then
        return nil
    end

    local wallet = entity.wallet
    if type(wallet) == "table" then
        if type(wallet.balance) == "number" then
            return wallet.balance
        end
    elseif type(wallet) == "number" then
        return wallet
    end

    return nil
end

--- Applies the state's currency value to an entity's wallet
---@param state table The game state
---@param entity table The entity to update
local function apply_currency_to_entity(state, entity)
    if not (state and entity) then
        return
    end

    local currency = state.playerCurrency

    local wallet = entity.wallet
    if type(wallet) ~= "table" then
        wallet = {}
        entity.wallet = wallet
    end

    wallet.balance = currency
end

--- Ensures player currency is initialized in state
---@param state table The game state
---@param entity table|nil Optional entity to extract currency from
---@param defaultValue number|nil Optional default currency value
local function ensure_player_currency(state, entity, defaultValue)
    if not state then
        return
    end

    if state.playerCurrency == nil then
        local derived = extract_currency_from_entity(entity)
            or defaultValue
        if derived == nil then
            derived = STARTING_CURRENCY
        end
        state.playerCurrency = derived
    end

    if entity then
        apply_currency_to_entity(state, entity)
    end
end

--- Gets the current currency amount
---@param state table The game state
---@param playerShip table|nil Optional player ship entity for fallback
---@return number|nil The current currency amount
function PlayerCurrency.get(state, playerShip)
    if not state then
        return nil
    end

    if state.playerCurrency == nil then
        if playerShip then
            ensure_player_currency(state, playerShip, nil)
        end
    end

    return state.playerCurrency
end

--- Sets the player's currency to a specific amount
---@param state table The game state
---@param amount number The new currency amount
---@param playerShip table|nil Optional player ship to sync with
---@return number|nil The new currency amount
function PlayerCurrency.set(state, amount, playerShip)
    if not state then
        return nil
    end

    local numericAmount = tonumber(amount)
    if not numericAmount then
        return state.playerCurrency
    end

    state.playerCurrency = numericAmount
    if playerShip then
        apply_currency_to_entity(state, playerShip)
    end

    return numericAmount
end

--- Adjusts the player's currency by a delta amount
---@param state table The game state
---@param delta number The amount to add (positive) or subtract (negative)
---@param playerShip table|nil Optional player ship to sync with
---@return number|nil The new currency amount
function PlayerCurrency.adjust(state, delta, playerShip)
    if not state then
        return nil
    end

    local change = tonumber(delta)
    if not change then
        return state.playerCurrency
    end

    if state.playerCurrency == nil and playerShip then
        ensure_player_currency(state, playerShip, nil)
    end

    local current = state.playerCurrency or 0
    local newTotal = PlayerCurrency.set(state, current + change, playerShip)

    if change > 0 then
        record_gain(state, change, newTotal)
    end

    return newTotal
end

--- Synchronizes currency between state and entity
---@param state table The game state
---@param playerShip table|nil Optional player ship to sync with
---@return number|nil The current currency amount
function PlayerCurrency.sync(state, playerShip)
    if not state then
        return nil
    end

    ensure_player_currency(state, playerShip, nil)
    return state.playerCurrency
end

--- Initializes currency for a new entity
---@param state table The game state
---@param entity table The entity to initialize
---@param isLocalPlayer boolean Whether this is the local player
function PlayerCurrency.initializeForEntity(state, entity, isLocalPlayer)
    if not (state and entity) then
        return
    end

    if isLocalPlayer then
        ensure_player_currency(state, entity, STARTING_CURRENCY)
    end
end

--- Gets the active currency gain entry if still visible
---@param state table The game state or context
---@return table|nil gainEntry
function PlayerCurrency.getActiveGain(state)
    local container = state and state.currencyGain
    if type(container) ~= "table" then
        return nil
    end

    local entry = container.active
    if type(entry) ~= "table" then
        container.active = nil
        return nil
    end

    local now = get_time()
    local expiresAt = tonumber(entry.expiresAt or 0) or 0
    if expiresAt > 0 and now >= expiresAt then
        container.active = nil
        return nil
    end

    return entry
end

return PlayerCurrency
