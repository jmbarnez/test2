---Base behavior for cloud/stream weapons (plasma thrower, flamethrower, etc.)
local vector = require("src.util.vector")
local weapon_common = require("src.util.weapon_common")
local weapon_beam = require("src.util.weapon_beam")

local function randf(min, max)
    if not max then
        max = min
    end
    return min + (max - min) * math.random()
end

local function resolve_forward(entity, weapon)
    local dirX = weapon._fireDirX or 0
    local dirY = weapon._fireDirY or -1
    local len = vector.length(dirX, dirY)
    if len <= vector.EPSILON then
        local angle = (entity.rotation or 0) - math.pi * 0.5
        dirX = math.cos(angle)
        dirY = math.sin(angle)
        len = 1
    end
    if len > 0 then
        dirX = dirX / len
        dirY = dirY / len
    end
    return dirX, dirY
end

local function resolve_muzzle(entity, weapon)
    return weapon._muzzleX or (entity.position and entity.position.x) or 0,
        weapon._muzzleY or (entity.position and entity.position.y) or 0
end

local base_cloud = {}

---Spawn a cloud puff
---@param entity table The entity firing
---@param weapon table The weapon component
---@param config table The cloudStream config
---@param puffs table Array to add puff to
function base_cloud.spawnPuff(entity, weapon, config, puffs)
    local startX, startY = resolve_muzzle(entity, weapon)
    local dirX, dirY = resolve_forward(entity, weapon)
    local baseAngle = math.atan2(dirY, dirX)
    
    local spread = math.rad(config.spreadDegrees or config.spread_degrees or 0)
    if spread > 0 then
        baseAngle = baseAngle + randf(-spread * 0.5, spread * 0.5)
    end
    
    local spawnDistance = config.spawnDistance or config.spawn_distance or 0
    local spawnX = startX + math.cos(baseAngle) * spawnDistance
    local spawnY = startY + math.sin(baseAngle) * spawnDistance
    
    local lateralJitter = config.lateralJitter or config.lateral_jitter or 0
    if lateralJitter > 0 then
        local perpX = -math.sin(baseAngle)
        local perpY = math.cos(baseAngle)
        local jitter = randf(-lateralJitter, lateralJitter)
        spawnX = spawnX + perpX * jitter
        spawnY = spawnY + perpY * jitter
    end
    
    local forwardSpeed = config.forwardSpeed or config.forward_speed or 0
    local driftSpeed = config.driftSpeed or config.drift_speed or 0
    local velocityAngle = baseAngle + randf(-math.pi * 0.35, math.pi * 0.35)
    local vx = math.cos(baseAngle) * forwardSpeed + math.cos(velocityAngle) * driftSpeed
    local vy = math.sin(baseAngle) * forwardSpeed + math.sin(velocityAngle) * driftSpeed
    
    local radiusMin = config.radius and config.radius.min or config.radius_min or config.radiusMin or 12
    local radiusMax = config.radius and config.radius.max or config.radius_max or config.radiusMax or radiusMin
    local radius = randf(radiusMin, radiusMax)
    local startRadius = math.max(6, radius * 0.35)
    local lifetime = config.lifetime or 0.7
    local damagePerSecond = config.damagePerSecond or config.damage_per_second or 0
    local puffsPerSecond = config.puffsPerSecond or config.puffs_per_second or 1
    local perPuffDamage = damagePerSecond
    if puffsPerSecond > 0 then
        perPuffDamage = damagePerSecond / puffsPerSecond
    end
    
    local puff = {
        x = spawnX,
        y = spawnY,
        vx = vx,
        vy = vy,
        radius = startRadius,
        targetRadius = radius,
        radiusGrowth = config.radiusGrowth or config.radius_growth or 12,
        lifetime = lifetime,
        maxLifetime = lifetime,
        damagePerSecond = perPuffDamage,
        color = config.color,
        glowColor = config.glowColor,
        alpha = config.alpha or 0.78,
        highlightAlpha = config.highlightAlpha or 0.92,
    }
    
    puffs[#puffs + 1] = puff
end

---Check if target should be damaged
---@param owner table The entity owning the weapon
---@param target table The target entity
---@return boolean True if should damage
function base_cloud.shouldDamage(owner, target)
    if not target or target.pendingDestroy then
        return false
    end
    if weapon_beam.is_friendly_fire(owner, target) then
        return false
    end
    if not target.health or (target.health.current or 0) <= 0 then
        return false
    end
    return true
end

---Check if entity has enough energy to fire
---@param entity table The entity firing
---@param weapon table The weapon component
---@param config table The cloudStream config
---@param dt number Delta time
---@return boolean True if has energy
function base_cloud.checkEnergy(entity, weapon, config, dt)
    if not entity.player then
        return true
    end
    
    local energyPerSecond = weapon.energyPerSecond or config.energyPerSecond or config.energy_per_second or 0
    local energyCost = math.max(0, energyPerSecond * dt)
    if energyCost <= 0 then
        return true
    end
    
    return weapon_common.has_energy(entity, energyCost)
end

---Standard update for cloud/stream weapons
---@param entity table The entity
---@param weapon table The weapon component
---@param dt number Delta time
---@param context table System context
function base_cloud.update(entity, weapon, dt, context)
    local world = context.world
    if not world then
        return
    end
    
    local config = weapon.cloudStream or {}
    local puffs = weapon._cloudPuffs
    if not puffs then
        puffs = {}
        weapon._cloudPuffs = puffs
    end
    
    local fire = not not weapon._fireRequested
    if fire then
        if not base_cloud.checkEnergy(entity, weapon, config, dt) then
            fire = false
        end
    end
    
    weapon.firing = fire
    
    local spawnRate = config.puffsPerSecond or config.puffs_per_second or 0
    weapon._cloudAccumulator = weapon._cloudAccumulator or 0
    if fire and spawnRate > 0 then
        weapon._cloudAccumulator = weapon._cloudAccumulator + spawnRate * dt
        while weapon._cloudAccumulator >= 1 do
            base_cloud.spawnPuff(entity, weapon, config, puffs)
            weapon._cloudAccumulator = weapon._cloudAccumulator - 1
        end
    else
        weapon._cloudAccumulator = 0
    end
end

---Default behavior: fire logic is handled in update
---@param entity table The entity
---@param weapon table The weapon component
---@param context table System context
---@return boolean Success
function base_cloud.onFireRequested(entity, weapon, context)
    -- Fire logic is handled in update for cloud weapons
    return true
end

return base_cloud
