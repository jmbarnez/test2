local damage_numbers = require("src.systems.damage_numbers")
local FloatingText = require("src.effects.floating_text")

---@diagnostic disable-next-line: undefined-global
local love = love

local Combat = {}

local HEAL_FEEDBACK_INTERVAL = 0.18
local DEFAULT_RETALIATION_DURATION = 6

local function resolve_shield(entity)
    if not entity then
        return nil
    end

    local shield = entity.shield
    if type(shield) ~= "table" and entity.health then
        local healthShield = entity.health.shield
        if type(healthShield) == "table" then
            shield = healthShield
            entity.shield = shield
        end
    end

    if type(shield) ~= "table" then
        return nil
    end

    if entity.health and entity.health.shield == nil then
        entity.health.shield = shield
    end

    return shield
end

function Combat.hasActiveShield(entity)
    local shield = resolve_shield(entity)
    if not shield then
        return false
    end

    local maxShield = tonumber(shield.max or shield.capacity or 0) or 0
    if maxShield <= 0 then
        return false
    end

    local current = tonumber(shield.current or shield.value or shield.energy or 0) or 0
    return current > 0
end

local function assign_retaliation_target(entity, source)
    if not (entity and entity.enemy) then
        return
    end
    if type(source) ~= "table" then
        return
    end

    local attacker = source
    if type(attacker.owner) == "table" then
        attacker = attacker.owner
    end

    if attacker == entity or type(attacker) ~= "table" then
        return
    end

    if not attacker.player then
        return
    end

    if not attacker.position then
        local body = attacker.body
        if not (body and not body:isDestroyed()) then
            return
        end
    end

    entity.retaliationTarget = attacker

    local ai = entity.ai or {}
    local stats = entity.stats or {}
    local duration = ai.retaliationDuration
        or stats.retaliation_duration
        or DEFAULT_RETALIATION_DURATION

    if duration and duration > 0 then
        entity.retaliationTimer = duration
    else
        entity.retaliationTimer = DEFAULT_RETALIATION_DURATION
    end

    entity.currentTarget = attacker
end

local function update_last_damage_metadata(entity, source)
    if not source then
        return
    end

    entity.lastDamageSource = source

    local playerId = source.playerId
        or source.ownerPlayerId
        or (source.owner and source.owner.playerId)

    if not playerId and source.player then
        playerId = source.playerId or (source.player and source.player.playerId)
    end

    if not playerId and source.lastDamagePlayerId then
        playerId = source.lastDamagePlayerId
    end

    if playerId then
        entity.lastDamagePlayerId = playerId
    end
end

local function refresh_health_bar(entity)
    if entity.healthBar then
        entity.health.showTimer = entity.healthBar.showDuration or 0
    end
end

local function resolve_damage_context_host(entity, source)
    return entity.damageContext
        or (source and source.damageContext)
        or (source and source.state)
        or entity.state
end

local function resolve_impact_position(context)
    if not context then
        return nil
    end

    if context.position then
        return context.position
    end

    if context.x and context.y then
        return { x = context.x, y = context.y }
    end

    return nil
end

local function push_impact_pulse(entity, absorbed, impactPosition, pulseType)
    if not (entity and absorbed and absorbed > 0) then
        return
    end

    local pulses = entity.impactPulses
    if type(pulses) ~= "table" then
        pulses = {}
        entity.impactPulses = pulses
    end

    local position = entity.position or {}
    local px = (impactPosition and impactPosition.x) or position.x or 0
    local py = (impactPosition and impactPosition.y) or position.y or 0
    local ex = position.x or 0
    local ey = position.y or 0

    local dx = px - ex
    local dy = py - ey

    local impactAngle = math.atan2(dy, dx)
    local impactDistance = math.sqrt(dx * dx + dy * dy)

    if impactDistance <= 0 then
        local shield = resolve_shield(entity)
        local fallbackRadius = (shield and shield.visualRadius)
            or entity.mountRadius
            or entity.radius
            or 32
        impactDistance = fallbackRadius
    end

    local maxHealth = math.max(0, tonumber(entity.health and entity.health.max) or 0)
    local intensity
    if maxHealth > 0 then
        intensity = math.max(0.15, math.min(1, absorbed / maxHealth))
    else
        intensity = 0.5
    end

    pulses[#pulses + 1] = {
        impactWorldX = dx,
        impactWorldY = dy,
        impactDistance = impactDistance,
        impactAngle = impactAngle,
        age = 0,
        duration = 0.5,
        intensity = intensity,
        pulseType = pulseType or "shield",
    }

    if #pulses > 6 then
        table.remove(pulses, 1)
    end
end

local function push_shield_pulse(entity, shield, absorbed, impactPosition)
    if not (entity and shield and absorbed and absorbed > 0) then
        return
    end

    push_impact_pulse(entity, absorbed, impactPosition, "shield")
end

local function push_heal_feedback(entity, healedAmount, impactPosition, contextHost)
    if not (entity and healedAmount and healedAmount > 0) then
        return
    end

    if not (FloatingText and FloatingText.add) then
        return
    end

    local host = contextHost or resolve_damage_context_host(entity)
    if not host then
        return
    end

    local position = impactPosition or entity.position
    if not position then
        return
    end

    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local nextTime = entity._nextHealFeedbackTime or 0
    if now < nextTime then
        return
    end
    entity._nextHealFeedbackTime = now + HEAL_FEEDBACK_INTERVAL

    local amount = healedAmount
    local plusCount = 1
    if amount >= 50 then
        plusCount = 4
    elseif amount >= 25 then
        plusCount = 3
    elseif amount >= 10 then
        plusCount = 2
    end

    local radius = entity.radius
        or (entity.drawable and entity.drawable.radius)
        or (entity.healthBar and entity.healthBar.width and entity.healthBar.width * 0.5)
        or 24

    FloatingText.add(host, position, string.rep("+", plusCount), {
        offsetY = radius,
        color = { 0.35, 0.95, 0.35, 1.0 },
        rise = 34 + plusCount * 4,
        scale = 1.0 + plusCount * 0.12,
        font = "bold",
    })
end

function Combat.heal(entity, amount, source, context)
    if not entity or not entity.health then
        return 0
    end

    local healAmount = math.max(0, tonumber(amount) or 0)
    if healAmount <= 0 then
        return 0
    end

    local maxHealth = math.max(0, tonumber(entity.health.max) or 0)
    if maxHealth <= 0 then
        return 0
    end

    local current = math.max(0, tonumber(entity.health.current) or maxHealth)
    local newHealth = math.min(maxHealth, current + healAmount)
    local applied = newHealth - current
    if applied <= 0 then
        return 0
    end

    entity.health.current = newHealth

    if entity.pendingDestroy and newHealth > 0 then
        entity.pendingDestroy = nil
    end

    refresh_health_bar(entity)

    local contextHost = resolve_damage_context_host(entity, source)
    local impactPosition = resolve_impact_position(context)
    push_heal_feedback(entity, applied, impactPosition, contextHost)

    return applied
end

function Combat.damage(entity, amount, source, context)
    if not entity or not entity.health then
        return
    end

    local damageAmount = math.max(0, tonumber(amount) or 0)
    if damageAmount <= 0 then
        return
    end

    local shield = resolve_shield(entity)
    if shield and (tonumber(shield.max) or 0) > 0 then
        local maxShield = math.max(0, tonumber(shield.max) or 0)
        local current = math.max(0, tonumber(shield.current) or 0)
        local absorbed = math.min(current, damageAmount)
        if absorbed > 0 then
            current = current - absorbed
            damageAmount = damageAmount - absorbed
            shield.current = current
            local percent = 0
            if maxShield > 0 then
                percent = math.max(0, math.min(1, current / maxShield))
            end
            shield.percent = percent
            shield.isDepleted = current <= 0
            shield.rechargeTimer = 0

            local contextHost = resolve_damage_context_host(entity, source)
            local impactPosition = resolve_impact_position(context)

            damage_numbers.push(contextHost, entity, absorbed, {
                position = impactPosition,
                kind = "shield",
                key = shield or entity,
            })

            push_shield_pulse(entity, shield, absorbed, impactPosition)
        end
    end

    if damageAmount <= 0 then
        update_last_damage_metadata(entity, source)

        assign_retaliation_target(entity, source)

        refresh_health_bar(entity)

        return
    end

    local previous = entity.health.current or entity.health.max or 0
    entity.health.current = math.max(0, previous - damageAmount)

    update_last_damage_metadata(entity, source)
    assign_retaliation_target(entity, source)
    refresh_health_bar(entity)

    if entity.health.current <= 0 then
        entity.pendingDestroy = true
    end

    if damageAmount and damageAmount > 0 then
        local contextHost = resolve_damage_context_host(entity, source)
        local impactPosition = resolve_impact_position(context)

        damage_numbers.push(contextHost, entity, damageAmount, {
            position = impactPosition,
            kind = "hull",
        })
    end
end

function Combat.pushCollisionImpact(entity, impactForce, impactPosition)
    if not entity then
        return
    end

    local shield = resolve_shield(entity)
    if not shield or (tonumber(shield.max) or 0) <= 0 then
        return
    end

    -- Only show impact if shield is active
    local current = math.max(0, tonumber(shield.current) or 0)
    if current <= 0 then
        return
    end

    -- Scale impact force to a reasonable "absorbed" value for visual effect
    -- Treat it as if it absorbed some shield energy proportional to the impact
    local visualAbsorbed = math.max(1, math.min(impactForce * 0.5, shield.max * 0.2))
    
    push_impact_pulse(entity, visualAbsorbed, impactPosition, "shield")
end

return Combat
