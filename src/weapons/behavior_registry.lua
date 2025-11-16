---@class WeaponBehaviorRegistry
local BehaviorRegistry = {
    behaviors = {},
    fallbacks = {}
}

---Register a weapon behavior plugin
---@param weaponKey string The weapon's constantKey or ID
---@param behavior table The behavior plugin (update, onFireRequested, draw, etc.)
function BehaviorRegistry.register(weaponKey, behavior)
    if not weaponKey or weaponKey == "" then
        error("BehaviorRegistry.register: weaponKey cannot be empty")
    end
    
    if not behavior then
        error("BehaviorRegistry.register: behavior cannot be nil")
    end
    
    BehaviorRegistry.behaviors[weaponKey] = behavior
end

---Get a weapon behavior plugin
---@param weaponKey string The weapon's constantKey or ID
---@return table|nil The behavior plugin, or nil if not found
function BehaviorRegistry.get(weaponKey)
    if not weaponKey then
        return nil
    end
    
    return BehaviorRegistry.behaviors[weaponKey]
end

---Register a fallback behavior for a fireMode
---@param fireMode string The fireMode (hitscan, projectile, cloud)
---@param behavior table The fallback behavior plugin
function BehaviorRegistry.registerFallback(fireMode, behavior)
    if not fireMode or fireMode == "" then
        error("BehaviorRegistry.registerFallback: fireMode cannot be empty")
    end
    
    if not behavior then
        error("BehaviorRegistry.registerFallback: behavior cannot be nil")
    end
    
    BehaviorRegistry.fallbacks[fireMode] = behavior
end

---Get a behavior for a weapon, with fallback to fireMode
---@param weapon table The weapon component
---@return table|nil The behavior plugin, or nil if not found
function BehaviorRegistry.resolve(weapon)
    if not weapon then
        return nil
    end
    
    -- Try to get by constantKey first
    local behavior = BehaviorRegistry.get(weapon.constantKey)
    if behavior then
        return behavior
    end
    
    -- Fallback to fireMode
    local fireMode = weapon.fireMode
    if fireMode then
        return BehaviorRegistry.fallbacks[fireMode]
    end
    
    return nil
end

---Check if a behavior is registered
---@param weaponKey string The weapon's constantKey or ID
---@return boolean True if registered
function BehaviorRegistry.has(weaponKey)
    return BehaviorRegistry.behaviors[weaponKey] ~= nil
end

---List all registered behaviors
---@return table Array of registered weapon keys
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
