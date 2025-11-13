local tiny = require("libs.tiny")

local ability_handlers = {}

local function drain_energy(entity, cost)
    if not cost or cost <= 0 then
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

ability_handlers.dash = function(entity, body, ability, state)
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
                    end

                    local justPressed = isDown and not state.wasDown
                    state.wasDown = isDown

                    if justPressed and (state.cooldown or 0) <= 0 then
                        if drain_energy(entity, ability.energyCost) then
                            local handler = ability_handlers[ability.type or ability.id]
                            local activated = true
                            if handler then
                                activated = handler(entity, body, ability, state)
                            end

                            if activated then
                                state.cooldownDuration = ability.cooldown or state.cooldownDuration or 0
                                state.cooldown = ability.cooldown or 0
                            end
                        end
                    end
                end
            end
        end,
    }
end
