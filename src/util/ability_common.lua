---Common utilities for ability system
local ability_common = {}

---Drain energy from entity
---@param entity table The entity
---@param cost number Energy cost
---@return boolean True if successful
function ability_common.drain_energy(entity, cost)
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
    energy.rechargeTimer = energy.rechargeDelay or 0
    energy.isDepleted = energy.current <= 0
    return true
end

---Check if player is pressing ability key
---@param context table System context
---@param entity table The entity
---@param ability table The ability configuration
---@return boolean True if key is down
function ability_common.is_ability_key_down(context, entity, ability)
    -- Check if player is pressing the ability key
    if not entity.player then
        return false
    end

    -- Check UI input capture
    local holder = context.intentHolder or context.state
    local uiInput = holder and holder.uiInput
    if uiInput and uiInput.keyboardCaptured then
        return false
    end

    -- Poll keyboard directly for ability keys
    local intentIndex = ability.intentIndex or 1
    if intentIndex == 1 then
        return love.keyboard and love.keyboard.isDown("space") or false
    end
    
    -- Future: support additional ability keys
    return false
end

---Resolve context state
---@param context table System context
---@return table|nil The resolved state
function ability_common.resolve_context_state(context)
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

return ability_common
