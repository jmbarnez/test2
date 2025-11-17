local BehaviorRegistry = {}
BehaviorRegistry.__index = BehaviorRegistry

local function registry_name(options)
    if options and type(options.name) == "string" and options.name ~= "" then
        return options.name
    end
    return "BehaviorRegistry"
end

function BehaviorRegistry.create(options)
    local registry = {
        _behaviors = {},
        _fallbacks = {},
        _default = nil,
        _name = registry_name(options),
    }

    setmetatable(registry, BehaviorRegistry)

    if options and type(options.resolve) == "function" then
        registry.resolve = options.resolve
    end

    return registry
end

local function assert_key(self, key, method_name)
    if key == nil or key == "" then
        error(string.format("%s:%s key cannot be empty", self._name, method_name))
    end
end

local function assert_behavior(self, behavior, method_name)
    if behavior == nil then
        error(string.format("%s:%s behavior cannot be nil", self._name, method_name))
    end
end

function BehaviorRegistry:register(id, behavior)
    assert_key(self, id, "register")
    assert_behavior(self, behavior, "register")
    self._behaviors[id] = behavior
end

function BehaviorRegistry:get(id)
    if id == nil then
        return nil
    end
    return self._behaviors[id]
end

function BehaviorRegistry:has(id)
    return self._behaviors[id] ~= nil
end

function BehaviorRegistry:registerFallback(id, behavior)
    assert_key(self, id, "registerFallback")
    assert_behavior(self, behavior, "registerFallback")
    self._fallbacks[id] = behavior
end

function BehaviorRegistry:getFallback(id)
    if id == nil then
        return nil
    end
    return self._fallbacks[id]
end

function BehaviorRegistry:setDefault(id)
    if id ~= nil then
        assert_key(self, id, "setDefault")
    end
    self._default = id
end

function BehaviorRegistry:getDefault()
    return self._default
end

function BehaviorRegistry:resolve(key)
    if key == nil then
        key = self._default
    end

    if key == nil then
        return nil, nil
    end

    local behavior = self:get(key)
    if behavior ~= nil then
        return behavior, key
    end

    local fallback = self:getFallback(key)
    if fallback ~= nil then
        return fallback, key
    end

    if self._default ~= nil and key ~= self._default then
        local default_behavior = self:get(self._default) or self:getFallback(self._default)
        if default_behavior ~= nil then
            return default_behavior, self._default
        end
    end

    return nil, nil
end

function BehaviorRegistry:list()
    local keys = {}
    for key in pairs(self._behaviors) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function BehaviorRegistry:clear()
    for key in pairs(self._behaviors) do
        self._behaviors[key] = nil
    end

    for key in pairs(self._fallbacks) do
        self._fallbacks[key] = nil
    end

    self._default = nil
end

return BehaviorRegistry
