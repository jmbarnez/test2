---Base behavior for overdrive ability
---Provides a short thrust burst followed by an extended max speed boost
local AudioManager = require("src.audio.manager")
local constants = require("src.constants.game")

local base_overdrive = {}

local DEFAULT_THRUST_MULTIPLIER = 2.2
local DEFAULT_STRAFE_MULTIPLIER = 1.7
local DEFAULT_REVERSE_MULTIPLIER = 1.4
local DEFAULT_ACCELERATION_MULTIPLIER = 1.8
local DEFAULT_MAX_SPEED_MULTIPLIER = 1.6

local function resolve_context_state(context)
    if not context then
        return nil
    end

    if type(context.resolveState) == "function" then
        local ok, state = pcall(context.resolveState, context)
        if ok and type(state) == "table" then
            return state
        end
    end

    if type(context.state) == "table" then
        return context.state
    end

    return nil
end

local function ensure_stash(state)
    local stash = state._overdriveStash
    if not stash then
        stash = {
            stats = {},
            entity = {},
            body = {},
            engineTrail = {},
        }
        state._overdriveStash = stash
    end
    return stash
end

local function apply_stat_multiplier(stash, targetTable, key, multiplier)
    if not (targetTable and multiplier and multiplier ~= 1 and targetTable[key]) then
        return
    end

    if stash.stats[key] == nil then
        stash.stats[key] = targetTable[key]
    end
    targetTable[key] = targetTable[key] * multiplier
end

local function apply_entity_multiplier(stash, entity, key, multiplier)
    if not (entity and multiplier and multiplier ~= 1 and entity[key]) then
        return
    end

    if stash.entity[key] == nil then
        stash.entity[key] = entity[key]
    end
    entity[key] = entity[key] * multiplier
end

local function apply_body_linear_damping(stash, body, ability)
    if not (body and ability) then
        return
    end

    if ability.linearDamping then
        if stash.body.linearDamping == nil then
            stash.body.linearDamping = body:getLinearDamping()
        end
        body:setLinearDamping(ability.linearDamping)
    elseif ability.dampingMultiplier and ability.dampingMultiplier ~= 1 then
        if stash.body.linearDamping == nil then
            stash.body.linearDamping = body:getLinearDamping()
        end
        body:setLinearDamping(stash.body.linearDamping * ability.dampingMultiplier)
    end
end

local function restore_thrust_modifiers(entity, state)
    local stash = state._overdriveStash
    if not stash or stash.thrustRestored then
        return
    end

    local stats = entity and entity.stats
    if stash.stats then
        for key, value in pairs(stash.stats) do
            if stats and stats[key] ~= nil then
                stats[key] = value
            elseif entity and entity[key] ~= nil then
                entity[key] = value
            end
        end
    end

    stash.stats = {}
    stash.thrustRestored = true
end

local function restore_speed_modifiers(entity, state)
    local stash = state._overdriveStash
    if not stash or stash.speedRestored then
        return
    end

    if stash.entity then
        for key, value in pairs(stash.entity) do
            if entity and entity[key] ~= nil then
                entity[key] = value
            end
        end
    end

    local stats = entity and entity.stats
    if stats and stash.stats then
        if stash.stats.max_speed ~= nil then
            stats.max_speed = stash.stats.max_speed
        end
    end

    stash.speedRestored = true
end

local function restore_body(body, state)
    local stash = state._overdriveStash
    if not stash then
        return
    end

    if body and not body:isDestroyed() and stash.body.linearDamping ~= nil then
        body:setLinearDamping(stash.body.linearDamping)
        stash.body.linearDamping = nil
    end
end

local function restore_engine_trail(context, entity, state)
    local stash = state._overdriveStash
    if not stash or not stash.engineTrail or not stash.engineTrail.override then
        return
    end

    local ctxState = resolve_context_state(context)
    local engineTrail = ctxState and ctxState.engineTrail
    if engineTrail and engineTrail.clearColorOverride then
        engineTrail:clearColorOverride()
    end

    stash.engineTrail.override = nil
end

function base_overdrive.activate(context, entity, body, ability, state)
    if not (body and not body:isDestroyed()) then
        return false
    end

    if state._overdriveActive then
        base_overdrive.deactivate(context, entity, body, ability, state)
    end

    local thrustDuration = ability.thrustDuration or ability.burstDuration or ability.duration or 0.75
    local speedDuration = ability.maxSpeedDuration or ability.speedDuration or math.max(thrustDuration * 2, 2.0)

    local stats = entity and entity.stats
    local stash = ensure_stash(state)

    local thrustMultiplier = ability.thrustMultiplier or DEFAULT_THRUST_MULTIPLIER
    local strafeMultiplier = ability.strafeMultiplier or ability.thrustMultiplier or DEFAULT_STRAFE_MULTIPLIER
    local reverseMultiplier = ability.reverseMultiplier or 1.0 + (thrustMultiplier - 1) * 0.6
    reverseMultiplier = reverseMultiplier > 0 and reverseMultiplier or DEFAULT_REVERSE_MULTIPLIER
    local accelerationMultiplier = ability.accelerationMultiplier or DEFAULT_ACCELERATION_MULTIPLIER
    local maxSpeedMultiplier = ability.maxSpeedMultiplier or DEFAULT_MAX_SPEED_MULTIPLIER

    -- Apply thrust-oriented multipliers
    if stats then
        apply_stat_multiplier(stash, stats, "main_thrust", thrustMultiplier)
        apply_stat_multiplier(stash, stats, "strafe_thrust", strafeMultiplier)
        apply_stat_multiplier(stash, stats, "reverse_thrust", reverseMultiplier)
        apply_stat_multiplier(stash, stats, "thrust_force", ability.thrustForceMultiplier or thrustMultiplier)
    else
        apply_entity_multiplier(stash, entity, "maxThrust", thrustMultiplier)
        apply_entity_multiplier(stash, entity, "strafeThrust", strafeMultiplier)
        apply_entity_multiplier(stash, entity, "reverseThrust", reverseMultiplier)
    end

    if stats and stats.max_acceleration then
        apply_stat_multiplier(stash, stats, "max_acceleration", accelerationMultiplier)
    else
        apply_entity_multiplier(stash, entity, "max_acceleration", accelerationMultiplier)
    end

    -- Apply max speed multiplier separately
    if stats and stats.max_speed then
        if stash.stats.max_speed == nil then
            stash.stats.max_speed = stats.max_speed
        end
        stats.max_speed = stats.max_speed * maxSpeedMultiplier
    else
        apply_entity_multiplier(stash, entity, "max_speed", maxSpeedMultiplier)
    end

    -- Optional linear damping tweak
    apply_body_linear_damping(stash, body, ability)

    -- Visual engine trail override
    local ctxState = resolve_context_state(context)
    local engineTrail = ctxState and ctxState.engineTrail
    if engineTrail and engineTrail.applyColorOverride then
        local colors = ability.trailColors or {
            0.95, 0.3, 0.1, 1.0,
            0.95, 0.5, 0.15, 0.9,
            0.95, 0.7, 0.22, 0.75,
            1.0, 0.85, 0.4, 0.55,
        }
        local drawColor = ability.trailDrawColor or { 1.0, 0.7, 0.25, 1.0 }
        engineTrail:applyColorOverride(colors, drawColor)
        stash.engineTrail.override = true

        if engineTrail.emitBurst and ability.trailBurstParticles and ability.trailBurstStrength then
            engineTrail:emitBurst(ability.trailBurstParticles, ability.trailBurstStrength)
        end

        if engineTrail.forceActivate then
            local forcedDuration = (speedDuration or 1.2) + (ability.trailFade or 0.35)
            local forcedStrength = ability.trailStrength or 1.7
            engineTrail:forceActivate(forcedDuration, forcedStrength)
        end
    end

    -- Apply impulse for immediate burst
    local forwardImpulse = ability.forwardImpulse or ability.impulse
    if forwardImpulse and forwardImpulse ~= 0 then
        local angle = body:getAngle() - math.pi * 0.5
        local dirX = math.cos(angle)
        local dirY = math.sin(angle)
        body:applyLinearImpulse(dirX * forwardImpulse, dirY * forwardImpulse)
    end

    local forwardForce = ability.forwardForce
    if forwardForce and forwardForce ~= 0 then
        local angle = body:getAngle() - math.pi * 0.5
        local dirX = math.cos(angle)
        local dirY = math.sin(angle)
        body:applyForce(dirX * forwardForce, dirY * forwardForce)
    end

    -- Audio cue
    AudioManager.play_sfx(ability.sfx or "sfx:engine_afterburn", {
        pitch = ability.sfxPitch or 1.2,
        volume = ability.sfxVolume or 1.0,
    })

    state._overdriveActive = true
    state._overdriveThrustRemaining = thrustDuration
    state._overdriveSpeedRemaining = speedDuration
    state._overdriveThrustMultiplier = thrustMultiplier
    state._overdriveMaxSpeedMultiplier = maxSpeedMultiplier
    state._restoreFn = base_overdrive.deactivate

    state.activeTimer = speedDuration

    return true
end

function base_overdrive.update(context, entity, ability, state, dt)
    if not state._overdriveActive then
        return
    end

    dt = dt or 0
    local body = entity and entity.body

    if state._overdriveThrustRemaining then
        state._overdriveThrustRemaining = state._overdriveThrustRemaining - dt
        if state._overdriveThrustRemaining <= 0 then
            restore_thrust_modifiers(entity, state)
            state._overdriveThrustRemaining = nil
        end
    end

    if state._overdriveSpeedRemaining then
        state._overdriveSpeedRemaining = state._overdriveSpeedRemaining - dt
        if state._overdriveSpeedRemaining <= 0 then
            base_overdrive.deactivate(context, entity, body, ability, state)
            return
        else
            state.activeTimer = math.max(state._overdriveSpeedRemaining, 0)
        end
    end

    -- Keep engine trail alive if requested
    local ctxState = resolve_context_state(context)
    if ctxState and ctxState.engineTrail and ctxState.engineTrail.forceActivate and ability.trailKeepAlive then
        ctxState.engineTrail:forceActivate(dt * 1.1, ability.trailKeepAlive)
    end
end

function base_overdrive.deactivate(context, entity, body, ability, state)
    if not state._overdriveActive then
        return
    end

    body = body or (entity and entity.body)

    restore_thrust_modifiers(entity, state)
    restore_speed_modifiers(entity, state)
    restore_body(body, state)
    restore_engine_trail(context, entity, state)

    state._overdriveActive = nil
    state._overdriveThrustRemaining = nil
    state._overdriveSpeedRemaining = nil
    state._restoreFn = nil

    -- Reset stash for future activations
    state._overdriveStash = nil
    state.activeTimer = 0
end

return base_overdrive
