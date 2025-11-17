---@class AbilityBehaviorRegistry
local BehaviorRegistry = {
    behaviors = {},
    fallbacks = {}
}

---Register an ability behavior plugin
---@param abilityKey string The ability's ID or type
---@param behavior table The behavior plugin (update, onActivate, onDeactivate, etc.)
function BehaviorRegistry.register(abilityKey, behavior)
    if not abilityKey or abilityKey == "" then
        error("BehaviorRegistry.register: abilityKey cannot be empty")
    end
    
    if not behavior then
        error("BehaviorRegistry.register: behavior cannot be nil")
    end
    
    BehaviorRegistry.behaviors[abilityKey] = behavior
end

---Get an ability behavior plugin
---@param abilityKey string The ability's ID or type
---@return table|nil The behavior plugin, or nil if not found
function BehaviorRegistry.get(abilityKey)
    if not abilityKey then
        return nil
    end
    
    return BehaviorRegistry.behaviors[abilityKey]
end

---Register a fallback behavior for an ability type
---@param abilityType string The ability type (afterburner, dash, temporal_field, etc.)
---@param behavior table The fallback behavior plugin
function BehaviorRegistry.registerFallback(abilityType, behavior)
    if not abilityType or abilityType == "" then
        error("BehaviorRegistry.registerFallback: abilityType cannot be empty")
    end
    
    if not behavior then
        error("BehaviorRegistry.registerFallback: behavior cannot be nil")
    end
    
    BehaviorRegistry.fallbacks[abilityType] = behavior
end

---Get a behavior for an ability, with fallback to ability type
---@param ability table The ability component
---@return table|nil The behavior plugin, or nil if not found
function BehaviorRegistry.resolve(ability)
    if not ability then
        return nil
    end
    
    -- Try to get by ID first
    local behavior = BehaviorRegistry.get(ability.id)
    if behavior then
        return behavior
    end
    
    -- Fallback to type
    local abilityType = ability.type or ability.id
    if abilityType then
        return BehaviorRegistry.fallbacks[abilityType]
    end
    
    return nil
end

---Check if a behavior is registered
---@param abilityKey string The ability's ID or type
---@return boolean True if registered
function BehaviorRegistry.has(abilityKey)
    return BehaviorRegistry.behaviors[abilityKey] ~= nil
end

---List all registered behaviors
---@return table Array of registered ability keys
function BehaviorRegistry.list()
    local keys = {}
    for key, _ in pairs(BehaviorRegistry.behaviors) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

---Clear all registered behaviors (useful for testing)
function BehaviorRegistry.clear()
    BehaviorRegistry.behaviors = {}
    BehaviorRegistry.fallbacks = {}
end

return BehaviorRegistry
