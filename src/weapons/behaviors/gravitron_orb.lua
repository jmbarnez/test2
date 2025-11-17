local table_util = require("src.util.table")
local ProjectileFactory = require("src.entities.projectile_factory")
local base_projectile = require("src.weapons.behaviors.base_projectile")
local weapon_common = require("src.util.weapon_common")

local gravitron_orb = {}

local function resolve_charge_config(weapon)
    local charge = weapon.charge or weapon.chargeConfig or {}
    local maxTime = charge.maxTime or charge.max_time or 2.0
    local minTime = charge.minTime or charge.min_time or 0
    local minScale = charge.minScale or charge.min_scale or 0.7
    local maxScale = charge.maxScale or charge.max_scale or 2.4
    local energyPerSecond = charge.energyPerSecond or charge.energy_per_second or 0
    return {
        maxTime = maxTime,
        minTime = minTime,
        minScale = minScale,
        maxScale = maxScale,
        energyPerSecond = energyPerSecond,
    }
end

local function drain_energy(entity, amount)
    if not entity or not entity.energy or amount <= 0 then
        return true
    end

    local energy = entity.energy
    local current = tonumber(energy.current) or 0
    local maxEnergy = tonumber(energy.max) or 0
    if current < amount then
        return false
    end

    energy.current = current - amount
    if maxEnergy > 0 then
        energy.percent = math.max(0, energy.current / maxEnergy)
    end
    energy.rechargeTimer = energy.rechargeDelay or 0
    energy.isDepleted = energy.current <= 0
    return true
end

local function fire_charged_shot(entity, weapon, context, chargeScale)
    local world = context.world
    local physicsWorld = context.physicsWorld
    if not (world and physicsWorld) then
        return false
    end

    local shotWeapon = table_util.deep_copy(weapon)
    local baseSize = weapon.projectileSize or 3.2
    local sizeScale = chargeScale or 1

    shotWeapon.projectileSize = baseSize * sizeScale

    local blueprint = shotWeapon.projectileBlueprint
    if blueprint then
        local drawable = blueprint.drawable or {}
        blueprint.drawable = drawable
        drawable.size = (drawable.size or baseSize) * sizeScale

        local projectileComponent = blueprint.projectile
        if projectileComponent and projectileComponent.damage then
            local damageScale = 0.6 + 0.4 * sizeScale
            projectileComponent.damage = projectileComponent.damage * damageScale
        end

        local gravityWell = blueprint.gravityWell
        if gravityWell then
            local radius = gravityWell.radius or 0
            if radius > 0 then
                gravityWell.radius = radius * sizeScale
            end

            local force = gravityWell.force or gravityWell.pullForce
            if force and force > 0 then
                local scaledForce = force * sizeScale
                if gravityWell.force then
                    gravityWell.force = scaledForce
                else
                    gravityWell.pullForce = scaledForce
                end
            end
        end
    end

    local startX, startY, dirX, dirY = base_projectile.getMuzzleAndDirection(entity, shotWeapon)
    base_projectile.handleTravelToCursor(shotWeapon, startX, startY)
    base_projectile.handleColorRandomization(shotWeapon)
    base_projectile.handleLockOnTarget(shotWeapon)

    ProjectileFactory.spawn(world, physicsWorld, entity, startX, startY, dirX, dirY, shotWeapon)
    weapon._pendingTargetEntity = nil

    weapon_common.play_weapon_sound(weapon, "fire")
    base_projectile.applyCooldown(weapon)

    return true
end

function gravitron_orb.update(entity, weapon, dt, context)
    if not entity or not weapon then
        return
    end

    if not weapon._isLocalPlayer then
        if weapon._fireRequested then
            base_projectile.onFireRequested(entity, weapon, context)
        end
        return
    end

    local config = resolve_charge_config(weapon)
    local fire = not not weapon._fireRequested
    local prevFire = weapon._prevFireRequested or false
    weapon._prevFireRequested = fire

    weapon._chargeTime = weapon._chargeTime or 0
    weapon._chargeScale = weapon._chargeScale or config.minScale

    if fire then
        if weapon.cooldown and weapon.cooldown > 0 then
            weapon.firing = false
            return
        end

        local energyPerSecond = config.energyPerSecond or 0
        if energyPerSecond > 0 then
            local energyCost = energyPerSecond * dt
            if not drain_energy(entity, energyCost) then
                weapon.firing = false
                return
            end
        end

        local newCharge = math.min(weapon._chargeTime + dt, config.maxTime)
        weapon._chargeTime = newCharge

        local t = 0
        if config.maxTime > 0 then
            t = newCharge / config.maxTime
        end
        local scale = config.minScale + (config.maxScale - config.minScale) * t
        weapon._chargeScale = scale

        weapon.firing = true
        return
    end

    if prevFire and weapon._chargeTime and weapon._chargeTime >= (config.minTime or 0) then
        local chargeTime = math.min(weapon._chargeTime, config.maxTime)
        local t = 0
        if config.maxTime > 0 then
            t = chargeTime / config.maxTime
        end
        local scale = config.minScale + (config.maxScale - config.minScale) * t

        fire_charged_shot(entity, weapon, context, scale)
    end

    weapon._chargeTime = 0
    weapon._chargeScale = nil
    weapon.firing = false
end

return gravitron_orb
