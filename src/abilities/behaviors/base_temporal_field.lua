---Base behavior for temporal field abilities
---Creates a field that affects projectiles and cooldowns
local AudioManager = require("src.audio.manager")

local base_temporal_field = {}

---Activate temporal field
---@param context table System context
---@param entity table The entity
---@param body table The physics body
---@param ability table The ability configuration
---@param state table The ability state
---@return boolean Success
function base_temporal_field.activate(context, entity, body, ability, state)
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

    return true
end

---Deactivate temporal field
---@param context table System context
---@param entity table The entity
---@param body table The physics body
---@param ability table The ability configuration
---@param state table The ability state
function base_temporal_field.deactivate(context, entity, body, ability, state)
    if entity and entity._temporalField then
        entity._temporalField.active = false
    end
    state._sfxPlayed = nil
    state._temporalFieldRemaining = nil
end

---Update temporal field position and state
---@param context table System context
---@param entity table The entity
---@param ability table The ability configuration
---@param state table The ability state
---@param dt number Delta time
function base_temporal_field.update(context, entity, ability, state, dt)
    local temporalField = entity._temporalField
    if temporalField and temporalField.active then
        local body = entity.body
        if body and not body:isDestroyed() then
            local fx, fy = body:getPosition()
            temporalField.x = fx
            temporalField.y = fy
        end
    end

    -- Track remaining time
    if state._temporalFieldRemaining then
        state._temporalFieldRemaining = math.max(0, state._temporalFieldRemaining - dt)
        if state._temporalFieldRemaining <= 0 then
            local body = entity.body
            base_temporal_field.deactivate(context, entity, body, ability, state)
        end
    end
end

return base_temporal_field
