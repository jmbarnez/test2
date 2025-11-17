---Base behavior for dash-type abilities
---Provides instant impulse/velocity in forward direction
local AudioManager = require("src.audio.manager")

local base_dash = {}

local DASH_TRAIL_COLORS = {
    1.0, 0.95, 0.35, 1.0,
    1.0, 0.82, 0.22, 0.85,
    1.0, 0.68, 0.12, 0.65,
    1.0, 0.55, 0.06, 0.42,
    1.0, 0.45, 0.02, 0.22,
    1.0, 0.38, 0.01, 0.08,
}

local DASH_TRAIL_DRAW_COLOR = { 1.0, 0.92, 0.35, 1.0 }

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

---Activate dash ability
---@param context table System context
---@param entity table The entity
---@param body table The physics body
---@param ability table The ability configuration
---@param state table The ability state
---@return boolean Success
function base_dash.activate(context, entity, body, ability, state)
    if not (body and not body:isDestroyed()) then
        return false
    end

    local angle = body:getAngle() - math.pi * 0.5
    local dirX = math.cos(angle)
    local dirY = math.sin(angle)

    local impulse = ability.impulse or ability.force or 700
    if ability.useMass ~= false then
        impulse = impulse * math.max(body:getMass(), 1)
    end

    body:applyLinearImpulse(dirX * impulse, dirY * impulse)

    local overrideSpeed = ability.speed or ability.velocity
    if overrideSpeed and overrideSpeed > 0 then
        body:setLinearVelocity(dirX * overrideSpeed, dirY * overrideSpeed)
    end

    -- Temporary physics tweaks during dash
    state._dash_prevDamping = state._dash_prevDamping or body:getLinearDamping()
    local dashDamping = ability.dashDamping
    if dashDamping == nil then dashDamping = 0.2 end
    body:setLinearDamping(dashDamping)

    state._dash_prevBullet = (state._dash_prevBullet == nil) and body:isBullet() or state._dash_prevBullet
    body:setBullet(true)
    state._dash_restore = true

    if entity then
        entity._dashActive = true
    end

    -- Nice feedback: SFX + engine burst if available
    AudioManager.play_sfx("sfx:laser_turret_fire", { pitch = 1.15, volume = 0.9 })
    
    local ctxState = resolve_context_state(context)
    local engineTrail = ctxState and ctxState.engineTrail
    if engineTrail then
        if engineTrail.emitBurst then
            engineTrail:emitBurst(160, 1.3)
        end
        if engineTrail.applyColorOverride then
            engineTrail:applyColorOverride(DASH_TRAIL_COLORS, DASH_TRAIL_DRAW_COLOR)
        end
        if engineTrail.forceActivate then
            local forcedDuration = (ability.trailDuration or ability.duration or 0.2) + (ability.trailFade or 0.08)
            local forcedStrength = ability.trailStrength or 1.05
            engineTrail:forceActivate(forcedDuration, forcedStrength)
        end
    end

    state.activeTimer = ability.duration or 0
    return true
end

---Deactivate dash ability and restore physics
---@param context table System context
---@param entity table The entity
---@param body table The physics body
---@param ability table The ability configuration
---@param state table The ability state
function base_dash.deactivate(context, entity, body, ability, state)
    if body and not body:isDestroyed() then
        if state._dash_prevDamping ~= nil then
            body:setLinearDamping(state._dash_prevDamping)
        end
        if state._dash_prevBullet ~= nil then
            body:setBullet(state._dash_prevBullet)
        end
    end
    
    if entity then
        entity._dashActive = nil
    end

    local ctxState = resolve_context_state(context)
    local engineTrail = ctxState and ctxState.engineTrail
    if engineTrail and engineTrail.clearColorOverride then
        engineTrail:clearColorOverride()
    end

    state._dash_prevDamping = nil
    state._dash_prevBullet = nil
    state._dash_restore = nil
end

---Standard update for dash abilities
---@param context table System context
---@param entity table The entity
---@param ability table The ability configuration
---@param state table The ability state
---@param dt number Delta time
function base_dash.update(context, entity, ability, state, dt)
    -- Dash abilities don't need continuous updates
    -- All logic happens in activate/deactivate
end

return base_dash
