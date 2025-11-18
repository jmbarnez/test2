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

---Calculates the intercept point for predictive aiming.
---Given a shooter position, target position, target velocity, and projectile speed,
---returns the position where a projectile should be aimed to hit the moving target.
---@param shooterX number Shooter's X position
---@param shooterY number Shooter's Y position
---@param targetX number Target's current X position
---@param targetY number Target's current Y position
---@param targetVX number Target's X velocity
---@param targetVY number Target's Y velocity
---@param projectileSpeed number Speed of the projectile
---@return number|nil leadX The X position to aim at, or nil if no solution
---@return number|nil leadY The Y position to aim at, or nil if no solution
---@return number|nil timeToIntercept Time until intercept, or nil if no solution
function vector.predictive_aim(shooterX, shooterY, targetX, targetY, targetVX, targetVY, projectileSpeed)
    if not projectileSpeed or projectileSpeed <= 0 then
        return targetX, targetY, 0
    end
    
    -- Relative position
    local dx = targetX - shooterX
    local dy = targetY - shooterY
    
    -- Target velocity magnitude
    local targetSpeed = vector.length(targetVX, targetVY)
    
    -- If target isn't moving or is very slow, aim at current position
    if targetSpeed < 1 then
        return targetX, targetY, vector.length(dx, dy) / projectileSpeed
    end
    
    -- Quadratic equation coefficients for intercept time
    -- We're solving: |targetPos + targetVel * t - shooterPos| = projectileSpeed * t
    -- Which expands to: a*t^2 + b*t + c = 0
    local a = targetVX * targetVX + targetVY * targetVY - projectileSpeed * projectileSpeed
    local b = 2 * (dx * targetVX + dy * targetVY)
    local c = dx * dx + dy * dy
    
    -- Check if we have a valid solution
    local discriminant = b * b - 4 * a * c
    
    if discriminant < 0 then
        -- No intercept possible (target too fast)
        -- Aim at current position as fallback
        return targetX, targetY, nil
    end
    
    -- Solve for time
    local sqrtDisc = math.sqrt(discriminant)
    local t1 = (-b + sqrtDisc) / (2 * a)
    local t2 = (-b - sqrtDisc) / (2 * a)
    
    -- We want the smallest positive time
    local t
    if t1 > 0 and t2 > 0 then
        t = math.min(t1, t2)
    elseif t1 > 0 then
        t = t1
    elseif t2 > 0 then
        t = t2
    else
        -- No positive solution, aim at current position
        return targetX, targetY, nil
    end
    
    -- Clamp time to reasonable values (don't predict too far into future)
    t = math.min(t, 3.0)
    
    -- Calculate lead position
    local leadX = targetX + targetVX * t
    local leadY = targetY + targetVY * t
    
    return leadX, leadY, t
end

vector.EPSILON = EPSILON

return vector
