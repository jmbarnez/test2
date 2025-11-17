local tiny = require("libs.tiny")
local BehaviorRegistry = require("src.abilities.behavior_registry")
local ability_common = require("src.util.ability_common")
local constants = require("src.constants.game")

-- Register fallback behaviors for backward compatibility
local base_afterburner = require("src.abilities.behaviors.base_afterburner")
local base_dash = require("src.abilities.behaviors.base_dash")
local base_temporal_field = require("src.abilities.behaviors.base_temporal_field")
local base_overdrive = require("src.abilities.behaviors.base_overdrive")

BehaviorRegistry.registerFallback("afterburner", {
    update = base_afterburner.update,
    activate = base_afterburner.activate,
    deactivate = base_afterburner.deactivate,
})

BehaviorRegistry.registerFallback("dash", {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
})

BehaviorRegistry.registerFallback("temporal_field", {
    update = base_temporal_field.update,
    activate = base_temporal_field.activate,
    deactivate = base_temporal_field.deactivate,
})

BehaviorRegistry.registerFallback("overdrive", {
    update = base_overdrive.update,
    activate = base_overdrive.activate,
    deactivate = base_overdrive.deactivate,
})

-- Legacy handlers kept for backward compatibility (will be removed in future)
local ability_handlers = {}
local resolve_context_state = ability_common.resolve_context_state
local update_afterburner_zoom

local function drain_energy(entity, cost)
    return ability_common.drain_energy(entity, cost)
end

ability_handlers.afterburner = function(context, entity, body, ability, state)
    if not (body and not body:isDestroyed()) then
        return false
    end

    if state._afterburnerActive then
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

    local maxSpeedMultiplier = ability.maxSpeedMultiplier or ability.speedMultiplier or 1
    if stats and stats.max_speed and maxSpeedMultiplier ~= 1 then
        apply_stat_multiplier(stats, "max_speed", maxSpeedMultiplier)
    elseif maxSpeedMultiplier ~= 1 then
        apply_entity_multiplier("max_speed", maxSpeedMultiplier)
    end

    local accelerationMultiplier = ability.accelerationMultiplier or thrustMultiplier
    if accelerationMultiplier ~= 1 then
        if stats and stats.max_acceleration then
            apply_stat_multiplier(stats, "max_acceleration", accelerationMultiplier)
        else
            apply_entity_multiplier("max_acceleration", accelerationMultiplier)
        end
    end

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

    local damping = ability.linearDamping
    if damping ~= nil then
        stash.body.linearDamping = stash.body.linearDamping or body:getLinearDamping()
        body:setLinearDamping(damping)
    elseif ability.dampingMultiplier and ability.dampingMultiplier ~= 1 then
        stash.body.linearDamping = stash.body.linearDamping or body:getLinearDamping()
        body:setLinearDamping(stash.body.linearDamping * ability.dampingMultiplier)
    end

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

    AudioManager.play_sfx(ability.sfx or "sfx:laser_turret_fire", {
        pitch = ability.sfxPitch or 0.95,
        volume = ability.sfxVolume or 0.85,
    })

    state._afterburnerActive = true
    state._afterburnerOriginal = stash
    entity._afterburnerActive = true

    state._restoreFn = function(restoreContext, restoreEntity, restoreBody, _, restoreState)
        restoreState._afterburnerActive = nil
        restoreState._restoreFn = nil

        local original = restoreState._afterburnerOriginal
        restoreState._afterburnerOriginal = nil

        if restoreEntity then
            if original and original.stats and restoreEntity.stats then
                for key, value in pairs(original.stats) do
                    restoreEntity.stats[key] = value
                end
            end

            if original and original.entity then
                for key, value in pairs(original.entity) do
                    restoreEntity[key] = value
                end
            end

            restoreEntity._afterburnerActive = nil
        end

        if restoreBody and not restoreBody:isDestroyed() then
            if original and original.body and original.body.linearDamping ~= nil then
                restoreBody:setLinearDamping(original.body.linearDamping)
            end
        end

        local resolvedState = resolve_context_state(restoreContext)
        if resolvedState then
            local engine = resolvedState.engineTrail
            if engine and original and original.engineTrail and original.engineTrail.clearOverride and engine.clearColorOverride then
                engine:clearColorOverride()
            end

            if original and original.camera and resolvedState._afterburnerZoomOwner == restoreEntity then
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

                    restoreState._afterburnerZoomData = {
                        target = original.camera.previousZoom or (camera.zoom or 1),
                        speed = returnSpeed,
                        epsilon = zoomEpsilon,
                        minZoom = minZoom,
                        maxZoom = maxZoom,
                        clearOnReach = true,
                    }
                end
                resolvedState._afterburnerZoomOwner = nil
            elseif resolvedState._afterburnerZoomOwner == restoreEntity then
                resolvedState._afterburnerZoomOwner = nil
            end
        end
    end

    local duration = ability.duration or 0
    state.activeTimer = duration

    return true
end
ability_handlers.temporal_field = function(context, entity, body, ability, state)
    if not (body and not body:isDestroyed()) then
        return false
    end

    local duration = ability.duration or 0
    if duration <= 0 then
        return false
    end

    local field = entity._temporalField
    if not field then
        field = {
            owner = entity,
        }
        entity._temporalField = field
    end

    field.active = true
    field.radius = ability.radius or field.radius or 0
    field.slowFactor = ability.projectileSlowFactor or field.slowFactor or 1
    field.cooldownReduction = ability.cooldownReductionRate or field.cooldownReduction or 0

    local x, y = body:getPosition()
    field.x = x
    field.y = y

    state.activeTimer = duration
    state._temporalFieldRemaining = duration

    if not state._sfxPlayed then
        AudioManager.play_sfx(ability.sfx or "sfx:laser_turret_fire", {
            pitch = ability.sfxPitch or 0.7,
            volume = ability.sfxVolume or 0.6,
        })
        state._sfxPlayed = true
    end

    state._restoreFn = function(_, restoreEntity, _, _, restoreState)
        if restoreEntity and restoreEntity._temporalField then
            restoreEntity._temporalField.active = false
        end
        restoreState._sfxPlayed = nil
        restoreState._temporalFieldRemaining = nil
        restoreState._restoreFn = nil
    end

    return true
end

local DASH_TRAIL_COLORS = {
    1.0, 0.95, 0.35, 1.0,
    1.0, 0.82, 0.22, 0.85,
    1.0, 0.68, 0.12, 0.65,
    1.0, 0.55, 0.06, 0.42,
    1.0, 0.45, 0.02, 0.22,
    1.0, 0.38, 0.01, 0.08,
}

local DASH_TRAIL_DRAW_COLOR = { 1.0, 0.92, 0.35, 1.0 }

local AFTERBURNER_TRAIL_COLORS = {
    0.35, 0.65, 1.0, 1.0,
    0.3, 0.58, 0.98, 0.9,
    0.22, 0.48, 0.92, 0.75,
    0.16, 0.38, 0.85, 0.58,
    0.12, 0.3, 0.75, 0.38,
    0.1, 0.24, 0.65, 0.22,
}

local AFTERBURNER_TRAIL_DRAW_COLOR = { 0.32, 0.72, 1.0, 1.0 }

resolve_context_state = function(context)
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

update_afterburner_zoom = function(context, ability, state, dt)
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

ability_handlers.dash = function(context, entity, body, ability, state)
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

local function is_ability_key_down(context, entity, ability)
    return ability_common.is_ability_key_down(context, entity, ability)
end

---@class AbilityModulesSystemContext
---@field state table|nil            # Gameplay state providing engineTrail and playerIntents
---@field intentHolder table|nil     # Optional explicit holder with playerIntents

return function(context)
    context = context or {}

    return tiny.processingSystem {
        filter = function(entity)
            return entity.abilityModules ~= nil and entity.body ~= nil
        end,

        process = function(_, entity, dt)
            local abilityModules = entity.abilityModules
            if not (abilityModules and #abilityModules > 0) then
                return
            end

            local abilityState = entity._abilityState
            if not abilityState then
                return
            end

            local body = entity.body

            local temporalField = entity._temporalField
            if temporalField and temporalField.active and body and not body:isDestroyed() then
                local fx, fy = body:getPosition()
                temporalField.x = fx
                temporalField.y = fy
            end

            for index = 1, #abilityModules do
                local entry = abilityModules[index]
                local ability = entry.ability
                local key = entry.key
                local state = abilityState[key]

                if ability and state then
                    if ability.type == "afterburner" or ability.id == "afterburner" then
                        update_afterburner_zoom(context, ability, state, dt)
                    end

                    if state.cooldown and state.cooldown > 0 then
                        state.cooldown = math.max(0, state.cooldown - dt)
                        if entity._temporalField and entity._temporalField.active then
                            local reduction = entity._temporalField.cooldownReduction or 0.15
                            state.cooldown = math.max(0, state.cooldown - reduction * dt)
                        end
                    end

                    if state.activeTimer and state.activeTimer > 0 then
                        state.activeTimer = math.max(0, state.activeTimer - dt)
                        if state._temporalFieldRemaining then
                            state._temporalFieldRemaining = math.max(0, state._temporalFieldRemaining - dt)
                            if state._temporalFieldRemaining <= 0 then
                                if entity._temporalField then
                                    entity._temporalField.active = false
                                end
                                state._sfxPlayed = nil
                                state._restoreFn = nil
                                state._temporalFieldRemaining = nil
                            end
                        end

                        if state.activeTimer <= 0 and state._dash_restore then
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
                    end

                    local isDown = false
                    if entity.player then
                        isDown = is_ability_key_down(context, entity, ability)
                    elseif entity.enemy and state.aiTrigger then
                        -- AI-driven ability trigger for enemies
                        isDown = true
                        state.aiTrigger = false
                    end

                    local holdActivation = ability.continuous == true or ability.holdToActivate == true
                    state.holdActive = state.holdActive or false

                    local justPressed = isDown and not state.wasDown
                    local justReleased = (not isDown) and state.wasDown
                    state.wasDown = isDown

                    -- Try to get behavior plugin
                    local behavior = BehaviorRegistry.resolve(ability)
                    
                    -- Call behavior update
                    if behavior and behavior.update then
                        behavior.update(context, entity, ability, state, dt)
                    end

                    if holdActivation then
                        local drainPerSecond = ability.energyPerSecond or ability.energyDrain or ability.energyCost or 0
                        local energyTick = drainPerSecond * (dt or 0)

                        if isDown then
                            if drain_energy(entity, energyTick) then
                                if not state.holdActive then
                                    local activated = true
                                    
                                    -- Use behavior plugin if available
                                    if behavior and behavior.activate then
                                        activated = behavior.activate(context, entity, body, ability, state)
                                    else
                                        -- Fallback to legacy handler
                                        local handler = ability_handlers[ability.type or ability.id]
                                        if handler then
                                            activated = handler(context, entity, body, ability, state)
                                        end
                                    end

                                    if activated then
                                        state.holdActive = true
                                        state.cooldown = 0
                                        state.cooldownDuration = 0
                                        local duration = ability.duration or 0
                                        if duration > 0 then
                                            state.activeTimer = duration
                                        end
                                    end
                                else
                                    local duration = ability.duration or 0
                                    if duration > 0 then
                                        state.activeTimer = math.max(state.activeTimer or 0, duration)
                                    end
                                end
                            else
                                if state.holdActive then
                                    -- Use behavior deactivate if available
                                    if behavior and behavior.deactivate then
                                        behavior.deactivate(context, entity, body, ability, state)
                                    elseif state._restoreFn then
                                        state._restoreFn(context, entity, body, dt, state)
                                    end
                                end
                                state.holdActive = false
                                state._afterburnerActive = nil
                            end
                        elseif state.holdActive then
                            -- Use behavior deactivate if available
                            if behavior and behavior.deactivate then
                                behavior.deactivate(context, entity, body, ability, state)
                            elseif state._restoreFn then
                                state._restoreFn(context, entity, body, dt, state)
                            end
                            state.holdActive = false
                            state._afterburnerActive = nil
                        end

                        -- Skip standard triggered logic for hold abilities
                    else
                        if justPressed and (state.cooldown or 0) <= 0 then
                            if drain_energy(entity, ability.energyCost) then
                                local activated = true
                                
                                -- Use behavior plugin if available
                                if behavior and behavior.activate then
                                    activated = behavior.activate(context, entity, body, ability, state)
                                else
                                    -- Fallback to legacy handler
                                    local handler = ability_handlers[ability.type or ability.id]
                                    if handler then
                                        activated = handler(context, entity, body, ability, state)
                                    end
                                end

                                if activated then
                                    state.cooldownDuration = ability.cooldown or state.cooldownDuration or 0
                                    state.cooldown = ability.cooldown or 0
                                end
                            end
                        elseif justReleased then
                            -- Use behavior deactivate if available
                            if behavior and behavior.deactivate and ability.type ~= "temporal_field" then
                                behavior.deactivate(context, entity, body, ability, state)
                            elseif state._restoreFn and ability.type ~= "temporal_field" then
                                state._restoreFn(context, entity, body, dt, state)
                            end
                        end
                    end
                end
            end
        end,
    }
end
