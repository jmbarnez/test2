local tiny = require("libs.tiny")
local BehaviorRegistry = require("src.ai.enemy_behaviors.init")
local GameContext = require("src.states.gameplay.context")
local util = require("src.ai.enemy_behaviors.util")

local function build_runtime_context(self)
    local runtime_context = self._runtimeContext
    if not runtime_context then
        runtime_context = {}
        self._runtimeContext = runtime_context
    end

    runtime_context.world = self.world
    runtime_context.physicsWorld = self.physicsWorld

    return runtime_context
end

local function ensure_behavior_state(ai, key)
    if not key then
        return nil
    end

    ai._behaviorState = ai._behaviorState or {}
    local behavior_state = ai._behaviorState[key]
    if not behavior_state then
        behavior_state = {}
        ai._behaviorState[key] = behavior_state
    end

    return behavior_state
end

local function resolve_behavior(key)
    return BehaviorRegistry:resolve(key)
end

return function(system_context)
    system_context = system_context or {}

    local baseContext = nil

    local function resolve_base_context()
        if system_context.state then
            return GameContext.extend(system_context, {
                behaviorRegistry = BehaviorRegistry,
            })
        end

        local state = GameContext.resolveState(system_context)
        if state then
            return GameContext.extend(GameContext.compose(state, system_context), {
                behaviorRegistry = BehaviorRegistry,
            })
        end

        return {
            state = system_context,
            resolveState = function()
                return system_context
            end,
            resolveLocalPlayer = function()
                return GameContext.resolveLocalPlayer(system_context)
            end,
            getLocalPlayer = function(self)
                return GameContext.resolveLocalPlayer(self or system_context)
            end,
            behaviorRegistry = BehaviorRegistry,
        }
    end

    local system = tiny.processingSystem {
        filter = tiny.requireAll("enemy", "ai"),

        onAddToWorld = function(self, world)
            self.world = world
            self.physicsWorld = system_context.physicsWorld or (world and world.physicsWorld)
        end,

        onRemoveFromWorld = function(self)
            self.world = nil
            self.physicsWorld = nil
        end,

        preProcess = function(self, dt)
            baseContext = resolve_base_context()
            self._dt = dt
            self._runtimeContext = build_runtime_context(self)
            self._runtimeContext.dt = dt
            self._runtimeContext.state = baseContext.state or baseContext
            self._runtimeContext.resolveState = baseContext.resolveState
            self._runtimeContext.resolveLocalPlayer = baseContext.resolveLocalPlayer
            self._runtimeContext.getLocalPlayer = baseContext.getLocalPlayer
            self._runtimeContext.behaviorRegistry = BehaviorRegistry
        end,

        postProcess = function(self)
            local runtime_context = self._runtimeContext
            if runtime_context then
                runtime_context.dt = nil
            end
        end,

        process = function(self, entity, dt)
            local ai = entity.ai
            if not ai then
                return
            end

            if not baseContext then
                baseContext = resolve_base_context()
            end

            if dt == nil then
                dt = self._dt
            else
                self._dt = dt
            end

            local behavior, resolved_key = resolve_behavior(ai.behavior)
            if not behavior then
                util.disable_weapon(entity)
                return
            end

            local behavior_state = ensure_behavior_state(ai, resolved_key)
            if not behavior_state then
                util.disable_weapon(entity)
                return
            end

            local runtime_context = self._runtimeContext
            if not runtime_context then
                runtime_context = build_runtime_context(self)
                self._runtimeContext = runtime_context
            end
            dt = dt or 0

            if runtime_context then
                runtime_context.behaviorKey = resolved_key
                runtime_context.state = baseContext.state or baseContext
                runtime_context.context = baseContext
                runtime_context.dt = dt
            end

            if behavior.tick then
                behavior.tick(entity, behavior_state, baseContext, runtime_context, dt)
            end
        end,
    }

    return system
end
