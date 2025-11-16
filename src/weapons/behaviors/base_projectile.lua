---Base behavior for projectile weapons (cannons, missiles, etc.)
local ProjectileFactory = require("src.entities.projectile_factory")
local weapon_common = require("src.util.weapon_common")

local DEFAULT_PLAYER_ENERGY_DRAIN = weapon_common.DEFAULT_PLAYER_ENERGY_DRAIN

local base_projectile = {}

---Check if entity has enough energy to fire
---@param entity table The entity firing
---@param weapon table The weapon component
---@return boolean True if has energy
function base_projectile.checkEnergy(entity, weapon)
    if not entity.player then
        return true
    end
    
    local shotCost = weapon.energyPerShot
        or weapon.energyCost
        or weapon.energyDrain
        or weapon.energyPerSecond
        or DEFAULT_PLAYER_ENERGY_DRAIN
    return weapon_common.has_energy(entity, shotCost)
end

---Apply cooldown to weapon
---@param weapon table The weapon component
function base_projectile.applyCooldown(weapon)
    local fireRate = weapon.fireRate or 0.5
    weapon.cooldown = fireRate
end

---Get muzzle position and direction from weapon
---@param entity table The entity
---@param weapon table The weapon component
---@return number startX, number startY, number dirX, number dirY
function base_projectile.getMuzzleAndDirection(entity, weapon)
    local position = entity.position or { x = 0, y = 0 }
    local startX = weapon._muzzleX or position.x or 0
    local startY = weapon._muzzleY or position.y or 0
    
    local dirX = weapon._fireDirX
    local dirY = weapon._fireDirY
    if not (dirX and dirY) then
        local angle = (entity.rotation or 0) - math.pi * 0.5
        dirX = math.cos(angle)
        dirY = math.sin(angle)
    end
    
    return startX, startY, dirX, dirY
end

---Handle travel-to-cursor lifetime calculation
---@param weapon table The weapon component
---@param startX number Start X position
---@param startY number Start Y position
function base_projectile.handleTravelToCursor(weapon, startX, startY)
    if weapon.travelToCursor and weapon.targetX and weapon.targetY then
        local dx = weapon.targetX - startX
        local dy = weapon.targetY - startY
        local speed = weapon.projectileSpeed or 0
        if speed > 0 then
            local distance = math.sqrt(dx * dx + dy * dy)
            weapon._shotLifetime = math.max(0.1, distance / speed)
        end
    end
end

---Handle color randomization
---@param weapon table The weapon component
function base_projectile.handleColorRandomization(weapon)
    if weapon.randomizeColorOnFire and weapon.colorPalette then
        local shotColor = weapon_common.random_color_from_palette(weapon.colorPalette)
        if shotColor then
            weapon._shotColor = shotColor
            weapon._shotGlow = weapon_common.lighten_color(shotColor, weapon.glowBoost or 0.45)
        end
    end
end

---Handle lock-on target
---@param weapon table The weapon component
function base_projectile.handleLockOnTarget(weapon)
    if weapon.lockOnTarget and weapon._activeTarget then
        weapon._pendingTargetEntity = weapon._activeTarget
    end
end

---Spawn a projectile
---@param world table The ECS world
---@param physicsWorld table The physics world
---@param entity table The entity firing
---@param weapon table The weapon component
---@param startX number Start X position
---@param startY number Start Y position
---@param dirX number Direction X (normalized)
---@param dirY number Direction Y (normalized)
function base_projectile.spawn(world, physicsWorld, entity, weapon, startX, startY, dirX, dirY)
    if weapon.projectilePattern == "shotgun" and type(weapon.shotgunPatternConfig) == "table" then
        weapon_common.fire_shotgun_pattern(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon, weapon.shotgunPatternConfig)
    else
        ProjectileFactory.spawn(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon)
    end
end

---Standard update for projectile weapons
---@param entity table The entity
---@param weapon table The weapon component
---@param dt number Delta time
---@param context table System context
function base_projectile.update(entity, weapon, dt, context)
    -- Projectile weapons don't need continuous updates like hitscan
    -- All logic happens in onFireRequested
end

---Fire a projectile weapon
---@param entity table The entity
---@param weapon table The weapon component
---@param context table System context
---@return boolean Success
function base_projectile.onFireRequested(entity, weapon, context)
    local world = context.world
    local physicsWorld = context.physicsWorld
    
    if not world then
        return false
    end
    
    local fire = not not weapon._fireRequested
    if not fire then
        weapon.firing = false
        return false
    end
    
    if weapon.cooldown and weapon.cooldown > 0 then
        weapon.firing = true
        return false
    end
    
    if not base_projectile.checkEnergy(entity, weapon) then
        weapon.firing = false
        return false
    end
    
    local startX, startY, dirX, dirY = base_projectile.getMuzzleAndDirection(entity, weapon)
    
    base_projectile.handleTravelToCursor(weapon, startX, startY)
    base_projectile.handleColorRandomization(weapon)
    base_projectile.handleLockOnTarget(weapon)
    
    base_projectile.spawn(world, physicsWorld, entity, weapon, startX, startY, dirX, dirY)
    
    weapon._pendingTargetEntity = nil
    
    weapon_common.play_weapon_sound(weapon, "fire")
    base_projectile.applyCooldown(weapon)
    weapon.firing = true
    
    return true
end

return base_projectile
