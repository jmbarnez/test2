local table_util = {}

function table_util.deep_copy(value, cache)
    if type(value) ~= "table" then
        return value
    end

    cache = cache or {}
    if cache[value] then
        return cache[value]
    end

    local copy = {}
    cache[value] = copy

    for k, v in pairs(value) do
        copy[table_util.deep_copy(k, cache)] = table_util.deep_copy(v, cache)
    end

    local mt = getmetatable(value)
    if mt then
        setmetatable(copy, mt)
    end

    return copy
end

function table_util.deep_merge(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            local existing = target[key]
            if type(existing) ~= "table" then
                existing = {}
                target[key] = existing
            end
            table_util.deep_merge(existing, value)
        else
            target[key] = value
        end
    end

    return target
end

function table_util.clone_array(values)
    if type(values) ~= "table" then
        return values
    end

    local copy = {}
    for i = 1, #values do
        copy[i] = values[i]
    end
    return copy
end

return table_util
