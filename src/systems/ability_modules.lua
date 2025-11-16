local tiny = require("libs.tiny")
local AudioManager = require("src.audio.manager")
local constants = require("src.constants.game")

local ability_handlers = {}
local resolve_context_state

local function drain_energy(entity, cost)
    if not cost or cost <= 0 then
        return true
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
            stash.camera = {
                previousZoom = previousZoom,
                appliedZoom = targetZoom,
            }
            camera.zoom = targetZoom
            ctxState._afterburnerZoomOwner = entity
            if type(ctxState.updateCamera) == "function" then
                ctxState:updateCamera()
            end
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
                    local currentZoom = camera.zoom or 1
                    local appliedZoom = original.camera.appliedZoom or currentZoom
                    if math.abs(currentZoom - appliedZoom) < 1e-4 then
                        camera.zoom = original.camera.previousZoom or currentZoom
                        if type(resolvedState.updateCamera) == "function" then
                            resolvedState:updateCamera()
                        end
                    end
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

    local energy = entity and entity.energy
    if not energy then
        return true
    end

    local current = tonumber(energy.current) or 0
    if current < cost then
        return false
    end

    energy.current = current - cost
    local maxEnergy = tonumber(energy.max) or 0
    if maxEnergy > 0 then
        energy.percent = math.max(0, energy.current / maxEnergy)
    end
    energy.rechargeTimer = (energy.rechargeDelay or 0)
    energy.isDepleted = energy.current <= 0
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

local function resolve_intent(context, entity)
    local holder = context.intentHolder or context.state
    if not holder then
        return nil
    end

    local intents = holder.playerIntents
    if not intents then
        return nil
    end

    return entity.playerId and intents[entity.playerId] or nil
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

            local intent = entity.player and resolve_intent(context, entity) or nil
            local body = entity.body

            for index = 1, #abilityModules do
                local entry = abilityModules[index]
                local ability = entry.ability
                local key = entry.key
                local state = abilityState[key]

                if ability and state then
                    if state.cooldown and state.cooldown > 0 then
                        state.cooldown = math.max(0, state.cooldown - dt)
                    end
                    if state.activeTimer and state.activeTimer > 0 then
                        state.activeTimer = math.max(0, state.activeTimer - dt)
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
                    if entity.player and intent then
                        local intentIndex = ability.intentIndex or 1
                        if intentIndex == 1 then
                            isDown = not not intent.ability1
                        else
                            local field = "ability" .. tostring(intentIndex)
                            isDown = not not intent[field]
                        end
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

                    if holdActivation then
                        local drainPerSecond = ability.energyPerSecond or ability.energyDrain or ability.energyCost or 0
                        local energyTick = drainPerSecond * (dt or 0)

                        if isDown then
                            if drain_energy(entity, energyTick) then
                                if not state.holdActive then
                                    local handler = ability_handlers[ability.type or ability.id]
                                    local activated = true
                                    if handler then
                                        activated = handler(context, entity, body, ability, state)
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
                                if state.holdActive and state._restoreFn then
                                    state._restoreFn(context, entity, body, dt, state)
                                end
                                state.holdActive = false
                                state._afterburnerActive = nil
                            end
                        elseif state.holdActive then
                            if state._restoreFn then
                                state._restoreFn(context, entity, body, dt, state)
                            end
                            state.holdActive = false
                            state._afterburnerActive = nil
                        end

                        -- Skip standard triggered logic for hold abilities
                    else
                        if justPressed and (state.cooldown or 0) <= 0 then
                            if drain_energy(entity, ability.energyCost) then
                                local handler = ability_handlers[ability.type or ability.id]
                                local activated = true
                                if handler then
                                    activated = handler(context, entity, body, ability, state)
                                end

                                if activated then
                                    state.cooldownDuration = ability.cooldown or state.cooldownDuration or 0
                                    state.cooldown = ability.cooldown or 0
                                end
                            end
                        elseif justReleased and state._restoreFn then
                            state._restoreFn(context, entity, body, dt, state)
                        end
                    end
                end
            end
        end,
    }
end
