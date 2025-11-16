local ProjectileFactory = require("src.entities.projectile_factory")
local AudioManager = require("src.audio.manager")

local love = love

local weapon_common = {}

local DEFAULT_WEAPON_OFFSET = 30
local ENEMY_DAMAGE_MULTIPLIER = 0.5
local ENERGY_EPSILON = 1e-6
local DEFAULT_PLAYER_ENERGY_DRAIN = 14

weapon_common.DEFAULT_PLAYER_ENERGY_DRAIN = DEFAULT_PLAYER_ENERGY_DRAIN
weapon_common.DEFAULT_WEAPON_OFFSET = DEFAULT_WEAPON_OFFSET
weapon_common.ENEMY_DAMAGE_MULTIPLIER = ENEMY_DAMAGE_MULTIPLIER

local function copy_color(color)
    if type(color) ~= "table" then
        return nil
    end

    return {
        color[1] or 0,
        color[2] or 0,
        color[3] or 0,
        color[4] or 1,
    }
end

function weapon_common.compute_muzzle_origin(entity)
    local weapon = entity.weapon or {}
    local mount = entity.weaponMount
    local angle = entity.rotation or 0
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)

    local localOffsetX = 0
    local localOffsetY = 0

    if mount then
        local forward = mount.forward or mount.length or 0
        local inset = mount.inset or 0
        local lateral = mount.lateral or 0
        local vertical = mount.vertical or 0
        local mountOffsetX = mount.offsetX or 0
        local mountOffsetY = mount.offsetY or 0

        localOffsetX = localOffsetX + lateral + mountOffsetX
        localOffsetY = localOffsetY - (forward - inset) + vertical + mountOffsetY
    else
        localOffsetY = localOffsetY - (weapon.offset or DEFAULT_WEAPON_OFFSET)
    end

    local muzzleOffset = weapon.muzzleOffset or weapon.offsetLocal
    if muzzleOffset then
        localOffsetX = localOffsetX + (muzzleOffset.x or 0)
        localOffsetY = localOffsetY + (muzzleOffset.y or 0)
    end

    local position = entity.position or { x = 0, y = 0 }
    local startX = position.x + localOffsetX * cosAngle - localOffsetY * sinAngle
    local startY = position.y + localOffsetX * sinAngle + localOffsetY * cosAngle

    return startX, startY
end

function weapon_common.has_energy(entity, amount)
    local energy = entity and entity.energy
    if not energy then
        return true
    end

    local current = tonumber(energy.current) or 0
    local maxEnergy = tonumber(energy.max) or 0
    local drain = math.max(0, amount or 0)
    local canSpend = current >= drain - ENERGY_EPSILON

    if canSpend and drain > 0 then
        energy.current = current - drain
        if maxEnergy > 0 then
            energy.percent = math.max(0, energy.current / maxEnergy)
        end
        energy.rechargeTimer = energy.rechargeDelay or 0
        energy.isDepleted = energy.current <= 0
    end

    return canSpend
end

function weapon_common.update_all_weapon_cooldowns(entity, dt)
    if not entity then
        return
    end

    local activeWeapon = entity.weapon
    if activeWeapon and activeWeapon.cooldown and activeWeapon.cooldown > 0 then
        activeWeapon.cooldown = activeWeapon.cooldown - dt
    end

    local weapons = entity.weapons
    if type(weapons) == "table" then
        for i = 1, #weapons do
            local weaponInstance = weapons[i]
            local weaponComponent = weaponInstance and weaponInstance.weapon
            if weaponComponent and weaponComponent ~= activeWeapon and weaponComponent.cooldown and weaponComponent.cooldown > 0 then
                weaponComponent.cooldown = weaponComponent.cooldown - dt
            end
        end
    end
end

function weapon_common.play_weapon_sound(weapon, key)
    if not weapon then
        return
    end

    local soundId
    local sfx = weapon.sfx
    if type(sfx) == "table" then
        soundId = sfx[key]
    elseif key == "fire" and type(sfx) == "string" then
        soundId = sfx
    end

    if not soundId then
        local fieldName = key .. "Sound"
        soundId = weapon[fieldName]
    end

    if not soundId and key ~= "fire" then
        soundId = weapon.fireSound
    end

    if type(soundId) == "string" and soundId ~= "" then
        AudioManager.play_sfx(soundId)
    end
end

local function randf(min, max)
    return min + (max - min) * math.random()
end

function weapon_common.fire_shotgun_pattern(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon, config)
    if not config then
        return ProjectileFactory.spawn(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon)
    end

    local pellets = math.max(1, math.floor((config.count or config.pellets or 6) + 0.5))
    local spreadDeg = config.spreadDegrees or config.spread or 25
    local spreadRad = math.rad(spreadDeg)
    local baseJitterDeg = config.baseJitterDegrees or config.baseJitter or 0
    local baseJitter = math.rad(baseJitterDeg)
    local lateralJitter = config.lateralJitter or 0
    local speedMin = config.speedMultiplierMin or config.speedMultiplier or 1
    local speedMax = config.speedMultiplierMax or config.speedMultiplier or speedMin
    if speedMax < speedMin then
        speedMin, speedMax = speedMax, speedMin
    end

    local baseAngle = math.atan2(dirY, dirX)
    local halfSpread = spreadRad * 0.5

    for i = 1, pellets do
        local angle
        if pellets == 1 then
            angle = baseAngle
        else
            angle = baseAngle - halfSpread + spreadRad * ((i - 1) / (pellets - 1))
        end

        if config.randomizeSpread ~= false then
            angle = angle + randf(-baseJitter, baseJitter)
        end

        local speedMul
        if speedMin == speedMax then
            speedMul = speedMin
        else
            speedMul = randf(speedMin, speedMax)
        end
        if speedMul <= 0 then
            speedMul = 1
        end

        local shotDirX = math.cos(angle)
        local shotDirY = math.sin(angle)

        local offsetX, offsetY = 0, 0
        if lateralJitter and lateralJitter > 0 then
            local jitter = randf(-lateralJitter, lateralJitter)
            offsetX = math.cos(angle + math.pi * 0.5) * jitter
            offsetY = math.sin(angle + math.pi * 0.5) * jitter
        end

        ProjectileFactory.spawn(world, physicsWorld, entity, startX + offsetX, startY + offsetY, shotDirX * speedMul, shotDirY * speedMul, weapon)
    end
end

function weapon_common.random_color_from_palette(palette)
    if type(palette) ~= "table" or #palette == 0 then
        return nil
    end

    local rng = (love and love.math and love.math.random) or math.random
    local index = rng(1, #palette)
    local selected = palette[index]
    if type(selected) ~= "table" then
        return nil
    end

    return copy_color(selected)
end

function weapon_common.lighten_color(color, factor)
    if type(color) ~= "table" then
        return nil
    end

    local clamped = math.max(0, math.min(factor or 0.4, 1))
    local r = color[1] or 0
    local g = color[2] or 0
    local b = color[3] or 0

    return {
        r + (1 - r) * clamped,
        g + (1 - g) * clamped,
        b + (1 - b) * clamped,
        color[4] or 1,
    }
end

function weapon_common.resolve_damage_multiplier(shooter)
    if shooter and shooter.enemy then
        local multiplier = ENEMY_DAMAGE_MULTIPLIER
        local scaling = shooter.levelScaling
        if scaling and scaling.damage then
            multiplier = multiplier * scaling.damage
        end
        return multiplier
    end
    return 1
end

return weapon_common
