local math_util = {}

---@diagnostic disable-next-line: undefined-global
local love = love

-- Constant representing a full turn in radians
math_util.TAU = math.pi * 2

function math_util.clamp_angle(angle)
    angle = angle % math_util.TAU
    if angle > math.pi then
        angle = angle - math_util.TAU
    elseif angle < -math.pi then
        angle = angle + math_util.TAU
    end
    return angle
end

function math_util.random_int_range(range, default)
    if range == nil then
        return default
    end

    if type(range) == "table" then
        local min = range.min or range[1] or default or 0
        local max = range.max or range[2] or min
        if min > max then
            min, max = max, min
        end
        min = math.floor(min + 0.5)
        max = math.floor(max + 0.5)
        return love.math.random(min, max)
    elseif type(range) == "number" then
        return range
    end

    return default
end

function math_util.random_float_range(range, default)
    if range == nil then
        return default
    end

    if type(range) == "table" then
        local min = range.min or range[1] or default or 0
        local max = range.max or range[2] or min
        if min > max then
            min, max = max, min
        end
        if min == max then
            return min
        end
        return min + love.math.random() * (max - min)
    elseif type(range) == "number" then
        return range
    end

    return default
end

return math_util
