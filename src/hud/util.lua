local Util = {}

function Util.clamp01(value)
    if not value then
        return 0
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

function Util.resolve_resource(source)
    if type(source) ~= "table" then
        return nil, nil
    end

    local current_keys = { "current", "value", "amount", "charge", "hp" }
    local max_keys = { "max", "capacity", "limit", "max_value", "maxValue", "strength", "max_strength" }

    local current
    for i = 1, #current_keys do
        local candidate = source[current_keys[i]]
        if candidate ~= nil then
            current = candidate
            break
        end
    end

    local max
    for i = 1, #max_keys do
        local candidate = source[max_keys[i]]
        if candidate ~= nil then
            max = candidate
            break
        end
    end

    if current == nil and type(source[1]) == "number" then
        current = source[1]
    end
    if max == nil and type(source[2]) == "number" then
        max = source[2]
    end

    current = current and tonumber(current) or nil
    max = max and tonumber(max) or nil

    if current and not max and source.capacity then
        max = tonumber(source.capacity)
    end

    if current and max and max > 0 then
        current = math.max(0, math.min(current, max))
        return current, max
    end

    return nil, nil
end

function Util.format_resource(current, max)
    if not (current and max and max > 0) then
        return "--"
    end
    local roundedCurrent = math.floor(current + 0.5)
    local roundedMax = math.floor(max + 0.5)
    return string.format("%d/%d", roundedCurrent, roundedMax)
end

return Util
