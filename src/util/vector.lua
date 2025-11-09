local vector = {}

local EPSILON = 1e-5

---Returns the squared magnitude of the vector.
---@param x number?
---@param y number?
---@param z number?
---@return number
function vector.length_squared(x, y, z)
    x = x or 0
    y = y or 0
    z = z or 0
    return x * x + y * y + z * z
end

---Returns the magnitude of the vector.
---@param x number?
---@param y number?
---@param z number?
---@return number
function vector.length(x, y, z)
    return math.sqrt(vector.length_squared(x, y, z))
end

---Normalizes a vector and returns the normalized components along with the original magnitude.
---@param x number?
---@param y number?
---@param tolerance number?
---@return number normX
---@return number normY
---@return number magnitude
function vector.normalize(x, y, tolerance)
    x = x or 0
    y = y or 0
    tolerance = tolerance or EPSILON

    local len = vector.length(x, y)
    if len < tolerance then
        return 0, 0, tolerance
    end

    return x / len, y / len, len
end

---Clamps a vector's magnitude to the supplied maximum and returns the clamped components and resulting magnitude.
---@param x number?
---@param y number?
---@param maxMagnitude number?
---@return number clampX
---@return number clampY
---@return number magnitude
function vector.clamp(x, y, maxMagnitude)
    x = x or 0
    y = y or 0

    local magSq = vector.length_squared(x, y)

    if not maxMagnitude or maxMagnitude <= 0 then
        return x, y, math.sqrt(magSq)
    end

    local maxSq = maxMagnitude * maxMagnitude

    if magSq > maxSq and magSq > 0 then
        local scale = math.sqrt(maxSq / magSq)
        return x * scale, y * scale, maxMagnitude
    end

    return x, y, math.sqrt(magSq)
end

vector.EPSILON = EPSILON

return vector
