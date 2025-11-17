---Base behavior for afterburner-type abilities
---Provides boost to movement stats while active
local AudioManager = require("src.audio.manager")
local constants = require("src.constants.game")

local base_afterburner = {}

local AFTERBURNER_TRAIL_COLORS = {
    0.35, 0.65, 1.0, 1.0,
    0.3, 0.58, 0.98, 0.9,
    0.22, 0.48, 0.92, 0.75,
    0.16, 0.38, 0.85, 0.58,
    0.12, 0.3, 0.75, 0.38,
    0.1, 0.24, 0.65, 0.22,
}

local AFTERBURNER_TRAIL_DRAW_COLOR = { 0.32, 0.72, 1.0, 1.0 }

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

---Apply stat multipliers when afterburner activates
---@param entity table The entity
---@param body table The physics body
---@param ability table The ability configuration
---@param state table The ability state
function base_afterburner.activate(context, entity, body, ability, state)
    if not (body and not body:isDestroyed()) then
        return false
    end

    if state._afterburnerActive then
        -- Already active, just extend duration
        local duration = ability.duration or 0
        if duration > 0 then
            state.activeTimer = math.max(state.activeTimer or 0, duration)
        end
        return true
    end

    local stats = entity and entity.stats
    local stash = {
        stats = {},
        entity = {},
        body = {},
    }

    local function apply_stat_multiplier(targetTable, key, multiplier)
        if not (targetTable and multiplier and multiplier ~= 1 and targetTable[key]) then
            return
        end

        stash.stats[key] = stash.stats[key] or targetTable[key]
        targetTable[key] = targetTable[key] * multiplier
    end

    local function apply_entity_multiplier(key, multiplier)
        if not (multiplier and multiplier ~= 1 and entity and entity[key]) then
            return
        end

        stash.entity[key] = stash.entity[key] or entity[key]
        entity[key] = entity[key] * multiplier
    end

    -- Apply thrust multipliers
    local thrustMultiplier = ability.thrustMultiplier or 1
    if thrustMultiplier ~= 1 then
        if stats then
            apply_stat_multiplier(stats, "main_thrust", thrustMultiplier)
            apply_stat_multiplier(stats, "strafe_thrust", ability.strafeMultiplier or thrustMultiplier)
            apply_stat_multiplier(stats, "reverse_thrust", ability.reverseMultiplier or thrustMultiplier)
            apply_stat_multiplier(stats, "thrust_force", ability.thrustForceMultiplier or thrustMultiplier)
        end
        if not (stats and stats.main_thrust) then
            apply_entity_multiplier("maxThrust", thrustMultiplier)
        end
    end

    -- Apply speed multipliers
    local maxSpeedMultiplier = ability.maxSpeedMultiplier or ability.speedMultiplier or 1
    if stats and stats.max_speed and maxSpeedMultiplier ~= 1 then
        apply_stat_multiplier(stats, "max_speed", maxSpeedMultiplier)
    elseif maxSpeedMultiplier ~= 1 then
        apply_entity_multiplier("max_speed", maxSpeedMultiplier)
    end

    -- Apply acceleration multipliers
    local accelerationMultiplier = ability.accelerationMultiplier or thrustMultiplier
    if accelerationMultiplier ~= 1 then
        if stats and stats.max_acceleration then
            apply_stat_multiplier(stats, "max_acceleration", accelerationMultiplier)
        else
            apply_entity_multiplier("max_acceleration", accelerationMultiplier)
        end
    end

    -- Apply visual effects
    local ctxState = resolve_context_state(context)
    local engineTrail = ctxState and ctxState.engineTrail
    if engineTrail then
        local overrideColors = ability.trailColors or AFTERBURNER_TRAIL_COLORS
        local drawColor = ability.trailDrawColor or AFTERBURNER_TRAIL_DRAW_COLOR

        if engineTrail.applyColorOverride then
            engineTrail:applyColorOverride(overrideColors, drawColor)
            stash.engineTrail = stash.engineTrail or {}
            stash.engineTrail.clearOverride = true
        end

        if engineTrail.emitBurst and ability.trailBurstParticles and ability.trailBurstStrength then
            engineTrail:emitBurst(ability.trailBurstParticles, ability.trailBurstStrength)
        end

        if engineTrail.forceActivate then
            local forcedDuration = (ability.trailDuration or ability.duration or 0.6) + (ability.trailFade or 0.15)
            local forcedStrength = ability.trailStrength or 1.3
            engineTrail:forceActivate(forcedDuration, forcedStrength)
        end
    end

    -- Apply camera zoom
    local viewConfig = constants.view or {}
    if ctxState and ctxState.camera then
        local camera = ctxState.camera
        local previousZoom = camera.zoom or 1
        local targetZoom = previousZoom
        
        if ability.zoomTarget then
            targetZoom = ability.zoomTarget
        else
            if ability.zoomMultiplier and ability.zoomMultiplier ~= 1 then
                targetZoom = targetZoom * ability.zoomMultiplier
            end
            if ability.zoomChange and ability.zoomChange ~= 0 then
                targetZoom = targetZoom + ability.zoomChange
            end
        end

        local minZoom = ability.minZoom or viewConfig.min_zoom or 0.3
        local maxZoom = ability.maxZoom or viewConfig.max_zoom or 2.5
        targetZoom = math.max(minZoom, math.min(maxZoom, targetZoom))

        if math.abs(targetZoom - previousZoom) > 1e-4 then
            local zoomSpeed = ability.zoomLerpSpeed or ability.zoomSmoothSpeed or 6
            local returnSpeed = ability.zoomReturnSpeed or zoomSpeed
            local zoomEpsilon = ability.zoomEpsilon or 1e-3

            stash.camera = {
                previousZoom = previousZoom,
                appliedZoom = targetZoom,
                zoomSpeed = zoomSpeed,
                returnSpeed = returnSpeed,
                zoomEpsilon = zoomEpsilon,
                minZoom = minZoom,
                maxZoom = maxZoom,
            }

            state._afterburnerZoomData = {
                target = targetZoom,
                speed = zoomSpeed,
                epsilon = zoomEpsilon,
                minZoom = minZoom,
                maxZoom = maxZoom,
                clearOnReach = true,
            }

            ctxState._afterburnerZoomOwner = entity
        end
    end

    -- Apply linear damping
    local damping = ability.linearDamping
    if damping ~= nil then
        stash.body.linearDamping = stash.body.linearDamping or body:getLinearDamping()
        body:setLinearDamping(damping)
    elseif ability.dampingMultiplier and ability.dampingMultiplier ~= 1 then
        stash.body.linearDamping = stash.body.linearDamping or body:getLinearDamping()
        body:setLinearDamping(stash.body.linearDamping * ability.dampingMultiplier)
    end

    -- Apply forces/impulses
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

    if ability.forwardVelocity and ability.forwardVelocity > 0 then
        local angle = body:getAngle() - math.pi * 0.5
        local dirX = math.cos(angle)
        local dirY = math.sin(angle)
        body:setLinearVelocity(dirX * ability.forwardVelocity, dirY * ability.forwardVelocity)
    end

    -- Play sound
    AudioManager.play_sfx(ability.sfx or "sfx:laser_turret_fire", {
        pitch = ability.sfxPitch or 0.95,
        volume = ability.sfxVolume or 0.85,
    })

    state._afterburnerActive = true
    state._afterburnerOriginal = stash
    entity._afterburnerActive = true

    local duration = ability.duration or 0
    state.activeTimer = duration

    return true
end

---Restore original stats when afterburner deactivates
---@param context table System context
---@param entity table The entity
---@param body table The physics body
---@param state table The ability state
function base_afterburner.deactivate(context, entity, body, ability, state)
    state._afterburnerActive = nil

    local original = state._afterburnerOriginal
    state._afterburnerOriginal = nil

    if entity then
        if original and original.stats and entity.stats then
            for key, value in pairs(original.stats) do
                entity.stats[key] = value
            end
        end

        if original and original.entity then
            for key, value in pairs(original.entity) do
                entity[key] = value
            end
        end

        entity._afterburnerActive = nil
    end

    if body and not body:isDestroyed() then
        if original and original.body and original.body.linearDamping ~= nil then
            body:setLinearDamping(original.body.linearDamping)
        end
    end

    local resolvedState = resolve_context_state(context)
    if resolvedState then
        local engine = resolvedState.engineTrail
        if engine and original and original.engineTrail and original.engineTrail.clearOverride and engine.clearColorOverride then
            engine:clearColorOverride()
        end

        if original and original.camera and resolvedState._afterburnerZoomOwner == entity then
            local camera = resolvedState.camera
            if camera then
                local viewConfig = constants.view or {}
                local minZoom = original.camera.minZoom or viewConfig.min_zoom or 0.3
                local maxZoom = original.camera.maxZoom or viewConfig.max_zoom or 2.5
                if minZoom > maxZoom then
                    minZoom, maxZoom = maxZoom, minZoom
                end

                local returnSpeed = original.camera.returnSpeed or original.camera.zoomSpeed or 6
                local zoomEpsilon = original.camera.zoomEpsilon or 1e-3

                state._afterburnerZoomData = {
                    target = original.camera.previousZoom or (camera.zoom or 1),
                    speed = returnSpeed,
                    epsilon = zoomEpsilon,
                    minZoom = minZoom,
                    maxZoom = maxZoom,
                    clearOnReach = true,
                }
            end
            resolvedState._afterburnerZoomOwner = nil
        elseif resolvedState._afterburnerZoomOwner == entity then
            resolvedState._afterburnerZoomOwner = nil
        end
    end
end

---Update camera zoom animation
---@param context table System context
---@param ability table The ability configuration
---@param state table The ability state
---@param dt number Delta time
function base_afterburner.updateZoom(context, ability, state, dt)
    local zoomData = state._afterburnerZoomData
    if not zoomData then
        return
    end

    local ctxState = resolve_context_state(context)
    local camera = ctxState and ctxState.camera
    if not camera then
        state._afterburnerZoomData = nil
        return
    end

    local target = zoomData.target
    if target == nil then
        state._afterburnerZoomData = nil
        return
    end

    local viewConfig = constants.view or {}
    local minZoom = zoomData.minZoom or ability.minZoom or viewConfig.min_zoom or 0.3
    local maxZoom = zoomData.maxZoom or ability.maxZoom or viewConfig.max_zoom or 2.5
    if minZoom > maxZoom then
        minZoom, maxZoom = maxZoom, minZoom
    end

    local speed = zoomData.speed or ability.zoomLerpSpeed or 6
    local epsilon = zoomData.epsilon or ability.zoomEpsilon or 1e-3
    local clampedTarget = math.max(minZoom, math.min(maxZoom, target))
    local currentZoom = camera.zoom or 1

    if not speed or speed <= 0 then
        if math.abs(clampedTarget - currentZoom) > 1e-4 then
            camera.zoom = clampedTarget
            if type(ctxState.updateCamera) == "function" then
                ctxState:updateCamera()
            end
        end
        if zoomData.clearOnReach ~= false then
            state._afterburnerZoomData = nil
        end
        return
    end

    local delta = clampedTarget - currentZoom
    if math.abs(delta) <= epsilon then
        if math.abs(clampedTarget - currentZoom) > 1e-4 then
            camera.zoom = clampedTarget
            if type(ctxState.updateCamera) == "function" then
                ctxState:updateCamera()
            end
        end
        if zoomData.clearOnReach ~= false then
            state._afterburnerZoomData = nil
        end
        return
    end

    local dtValue = math.max(dt or 0, 0)
    local factor = 1 - math.exp(-dtValue * speed)
    if factor <= 0 then
        return
    end

    local newZoom = currentZoom + delta * factor
    if math.abs(clampedTarget - newZoom) <= epsilon then
        newZoom = clampedTarget
    else
        newZoom = math.max(minZoom, math.min(maxZoom, newZoom))
    end

    if math.abs(newZoom - currentZoom) > 1e-4 then
        camera.zoom = newZoom
        if type(ctxState.updateCamera) == "function" then
            ctxState:updateCamera()
        end
    end

    if math.abs(newZoom - clampedTarget) <= epsilon and zoomData.clearOnReach ~= false then
        state._afterburnerZoomData = nil
    end
end

---Standard update for afterburner abilities
---@param entity table The entity
---@param ability table The ability configuration
---@param state table The ability state
---@param dt number Delta time
---@param context table System context
function base_afterburner.update(context, entity, ability, state, dt)
    base_afterburner.updateZoom(context, ability, state, dt)
end

return base_afterburner
