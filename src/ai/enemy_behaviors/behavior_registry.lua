local BehaviorRegistry = {
    behaviors = {},
    defaultKey = nil,
}

local function ensure_key(key)
    if not key or key == "" then
        error("EnemyBehaviorRegistry: behavior key cannot be empty")
    end
end

---@param key string
---@param plugin table
function BehaviorRegistry.register(key, plugin)
    ensure_key(key)

    if not plugin then
        error("EnemyBehaviorRegistry: plugin cannot be nil")
    end

    BehaviorRegistry.behaviors[key] = plugin
end

---@param key string
---@return table|nil
function BehaviorRegistry.get(key)
    if not key then
        return nil
    end

    return BehaviorRegistry.behaviors[key]
end

---@param key string
function BehaviorRegistry.setDefault(key)
    ensure_key(key)
    BehaviorRegistry.defaultKey = key
end

---@param key string|nil
---@return table|nil
function BehaviorRegistry.resolve(key)
    if key then
        local plugin = BehaviorRegistry.behaviors[key]
        if plugin then
            return plugin, key
        end
    end

    if BehaviorRegistry.defaultKey then
        local fallback = BehaviorRegistry.behaviors[BehaviorRegistry.defaultKey]
        if fallback then
            return fallback, BehaviorRegistry.defaultKey
        end
    end

    return nil, nil
end

---@return table<string, table>
function BehaviorRegistry.list()
    local result = {}
    for key, plugin in pairs(BehaviorRegistry.behaviors) do
        result[key] = plugin
    end
    return result
end

return BehaviorRegistry
