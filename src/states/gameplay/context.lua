--- Gameplay context helpers for Novus.
--
-- Systems and spawners accept a context table for their dependencies, but the
-- contents of that table have historically been inconsistent. This module
-- centralizes context creation so every consumer gets a predictable contract
-- while still allowing targeted overrides.
--
-- All contexts produced here expose:
--   * state                 - the gameplay state table
--   * resolveState()        - helper returning the gameplay state
--   * resolveLocalPlayer()  - helper returning the local player entity (if any)
--   * registerPhysicsCallback(ctx, phase, handler)
--       - optional wrapper that forwards to gameplay:registerPhysicsCallback
--   * __index fallback      - missing keys fall back to the gameplay state so
--                             existing code that referenced state fields keeps
--                             working without change.
--
-- Call GameContext.compose(state, overrides?) to create a brand new context and
-- optionally mix in custom fields. Use GameContext.extend(context, overrides?)
-- to fork an existing context for another consumer.

local PlayerManager = require("src.player.manager")

local GameContext = {}

local function create_physics_delegate(state)
    if type(state.registerPhysicsCallback) ~= "function" then
        return nil
    end

    return function(_, phase, handler)
        return state:registerPhysicsCallback(phase, handler)
    end
end

local function default_resolve_state(state)
    return function()
        return state
    end
end

local function default_resolve_local_player(state)
    return function()
        return PlayerManager.resolveLocalPlayer(state)
    end
end

--- Creates a new gameplay context table with optional overrides.
---@param state table
---@param overrides table|nil
---@return table context
function GameContext.compose(state, overrides)
    assert(type(state) == "table", "GameContext.compose requires a gameplay state table")

    local context = {
        state = state,
        resolveState = default_resolve_state(state),
        resolveLocalPlayer = default_resolve_local_player(state),
    }

    local physicsDelegate = create_physics_delegate(state)
    if physicsDelegate then
        context.registerPhysicsCallback = physicsDelegate
    end

    if overrides then
        for key, value in pairs(overrides) do
            context[key] = value
        end
    end

    return setmetatable(context, {
        __index = function(_, key)
            if key == "resolveState" then
                return context.resolveState
            elseif key == "resolveLocalPlayer" then
                return context.resolveLocalPlayer
            end
            return state[key]
        end,
    })
end

--- Creates a shallow copy of an existing context with optional overrides.
---@param context table
---@param overrides table|nil
---@return table newContext
function GameContext.extend(context, overrides)
    assert(type(context) == "table", "GameContext.extend requires a context table")

    local state = context.state
    if not state and type(context.resolveState) == "function" then
        state = context.resolveState(context)
    end

    assert(type(state) == "table", "GameContext.extend requires a context with state")

    local clone = GameContext.compose(state)

    for key, value in pairs(context) do
        if key ~= "state" then
            clone[key] = value
        end
    end

    if overrides then
        for key, value in pairs(overrides) do
            clone[key] = value
        end
    end

    return clone
end

--- Safely resolves the gameplay state from any context-like table.
---@param context table|nil
---@return table|nil
function GameContext.resolveState(context)
    if not context then
        return nil
    end

    local resolver = context.resolveState
    if type(resolver) == "function" then
        local ok, state = pcall(resolver, context)
        if ok and type(state) == "table" then
            return state
        end
    end

    if type(context.state) == "table" then
        return context.state
    end

    if type(context) == "table" then
        return context
    end

    return nil
end

--- Resolves the local player entity from a context when possible.
---@param context table|nil
---@return table|nil
function GameContext.resolveLocalPlayer(context)
    if not context then
        return nil
    end

    local resolver = context.resolveLocalPlayer
    if type(resolver) == "function" then
        local ok, player = pcall(resolver, context)
        if ok then
            return player
        end
    end

    return PlayerManager.resolveLocalPlayer(context)
end

return GameContext
