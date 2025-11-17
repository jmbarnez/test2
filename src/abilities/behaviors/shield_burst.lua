---Example: Shield Burst ability behavior
---Releases a shockwave that damages nearby enemies and restores shields
local AudioManager = require("src.audio.manager")

local shield_burst = {}

---Activate shield burst
---@param context table System context
---@param entity table The entity
---@param body table The physics body
---@param ability table The ability configuration
---@param state table The ability state
---@return boolean Success
function shield_burst.activate(context, entity, body, ability, state)
    if not (body and not body:isDestroyed()) then
        return false
    end

    local x, y = body:getPosition()
    local radius = ability.radius or 200
    local damage = ability.damage or 50
    local shieldRestore = ability.shieldRestore or 30

    -- Restore own shields
    if entity.shield then
        entity.shield.current = math.min(
            entity.shield.max,
            entity.shield.current + shieldRestore
        )
        entity.shield.percent = entity.shield.current / entity.shield.max
    end

    -- Damage nearby enemies
    if context.world and context.damageEntity then
        for _, target in pairs(context.world.entities) do
            if target ~= entity and target.enemy and target.body then
                local targetBody = target.body
                if not targetBody:isDestroyed() then
                    local tx, ty = targetBody:getPosition()
                    local dx = tx - x
                    local dy = ty - y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    if dist <= radius then
                        -- Apply damage (reduced by distance)
                        local damageMultiplier = 1 - (dist / radius) * 0.5
                        local actualDamage = damage * damageMultiplier
                        
                        context.damageEntity(target, actualDamage, entity, "energy")
                        
                        -- Apply knockback
                        if ability.knockback and dist > 1 then
                            local knockbackForce = ability.knockback or 500
                            local angle = math.atan2(dy, dx)
                            local fx = math.cos(angle) * knockbackForce * damageMultiplier
                            local fy = math.sin(angle) * knockbackForce * damageMultiplier
                            targetBody:applyLinearImpulse(fx, fy)
                        end
                    end
                end
            end
        end
    end

    -- Visual and audio feedback
    AudioManager.play_sfx(ability.sfx or "sfx:shield_burst", {
        pitch = ability.sfxPitch or 1.1,
        volume = ability.sfxVolume or 0.9,
    })

    -- Store burst data for rendering
    state._burstTime = 0
    state._burstDuration = ability.visualDuration or 0.4
    state._burstRadius = radius
    state._burstX = x
    state._burstY = y

    return true
end

---Deactivate shield burst
---@param context table System context
---@param entity table The entity
---@param body table The physics body
---@param ability table The ability configuration
---@param state table The ability state
function shield_burst.deactivate(context, entity, body, ability, state)
    -- Clean up visual data
    state._burstTime = nil
    state._burstDuration = nil
    state._burstRadius = nil
    state._burstX = nil
    state._burstY = nil
end

---Update shield burst visuals
---@param context table System context
---@param entity table The entity
---@param ability table The ability configuration
---@param state table The ability state
---@param dt number Delta time
function shield_burst.update(context, entity, ability, state, dt)
    -- Update burst visual timer
    if state._burstTime then
        state._burstTime = state._burstTime + dt
        if state._burstTime >= (state._burstDuration or 0.4) then
            shield_burst.deactivate(context, entity, entity.body, ability, state)
        end
    end
end

---Optional: Custom rendering for shield burst
---@param context table System context
---@param entity table The entity
---@param ability table The ability configuration
---@param state table The ability state
function shield_burst.draw(context, entity, ability, state)
    if not state._burstTime then
        return
    end

    local duration = state._burstDuration or 0.4
    local progress = math.min(1, state._burstTime / duration)
    local radius = state._burstRadius or 200
    local x = state._burstX or 0
    local y = state._burstY or 0

    -- Expanding ring effect
    local currentRadius = radius * progress
    local alpha = 1 - progress

    love.graphics.push()
    
    -- Outer ring
    love.graphics.setColor(0.3, 0.7, 1.0, alpha * 0.4)
    love.graphics.circle("line", x, y, currentRadius, 64)
    
    -- Inner ring
    love.graphics.setColor(0.5, 0.9, 1.0, alpha * 0.6)
    love.graphics.circle("line", x, y, currentRadius * 0.8, 64)
    
    -- Core flash
    love.graphics.setColor(0.8, 1.0, 1.0, alpha * 0.3)
    love.graphics.circle("fill", x, y, 20 * (1 - progress), 32)
    
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return shield_burst
