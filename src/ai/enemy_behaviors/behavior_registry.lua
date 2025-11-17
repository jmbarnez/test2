local RegistryFactory = require("src.util.behavior_registry")

local EnemyRegistry = RegistryFactory.create({
    name = "EnemyBehaviorRegistry",
    resolve = function(self, key)
        if key then
            local plugin = self:get(key)
            if plugin then
                return plugin, key
            end
        end

        local defaultKey = self:getDefault()
        if defaultKey then
            local fallback = self:get(defaultKey)
            if fallback then
                return fallback, defaultKey
            end
        end

        return nil, nil
    end,
})

function EnemyRegistry:list()
    local result = {}
    for key, plugin in pairs(self._behaviors) do
        result[key] = plugin
    end
    return result
end

return EnemyRegistry
