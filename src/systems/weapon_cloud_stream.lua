---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local vector = require("src.util.vector")
local weapon_common = require("src.util.weapon_common")
local weapon_beam = require("src.util.weapon_beam")

local love = love
local graphics = love and love.graphics

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

local function spawn_puff(entity, weapon, config, puffs)
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

local function should_damage(owner, target)
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

return function(context)
    context = context or {}
    local damageEntity = context.damageEntity

    return tiny.processingSystem {
        filter = tiny.requireAll("weapon", "position"),

        init = function(self)
            self.activePuffs = {}
        end,

        preProcess = function(self, dt)
            local activePuffs = self.activePuffs
            for i = #activePuffs, 1, -1 do
                activePuffs[i] = nil
            end
        end,

        process = function(self, entity, dt)
            local weapon = entity.weapon
            if not weapon or weapon.fireMode ~= "cloud" then
                return
            end

            local world = self.world
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
            if fire and entity.player then
                local energyPerSecond = weapon.energyPerSecond or config.energyPerSecond or config.energy_per_second or 0
                local energyCost = math.max(0, energyPerSecond * dt)
                if energyCost > 0 and not weapon_common.has_energy(entity, energyCost) then
                    fire = false
                end
            end

            weapon.firing = fire

            local spawnRate = config.puffsPerSecond or config.puffs_per_second or 0
            weapon._cloudAccumulator = weapon._cloudAccumulator or 0
            if fire and spawnRate > 0 then
                weapon._cloudAccumulator = weapon._cloudAccumulator + spawnRate * dt
                while weapon._cloudAccumulator >= 1 do
                    spawn_puff(entity, weapon, config, puffs)
                    weapon._cloudAccumulator = weapon._cloudAccumulator - 1
                end
            else
                weapon._cloudAccumulator = 0
            end

            local multiplier = weapon_common.resolve_damage_multiplier(entity)
            local worldEntities = world.entities or {}
            local activePuffs = self.activePuffs

            for index = #puffs, 1, -1 do
                local puff = puffs[index]
                puff.lifetime = (puff.lifetime or 0) - dt
                if not (puff.lifetime and puff.lifetime > 0) then
                    puffs[index] = puffs[#puffs]
                    puffs[#puffs] = nil
                else
                    puff.x = (puff.x or 0) + (puff.vx or 0) * dt
                    puff.y = (puff.y or 0) + (puff.vy or 0) * dt

                    local radiusGrowth = puff.radiusGrowth or 0
                    if radiusGrowth ~= 0 then
                        puff.radius = math.min(puff.targetRadius or puff.radius, (puff.radius or 0) + radiusGrowth * dt)
                    end

                    if damageEntity and puff.damagePerSecond and puff.damagePerSecond > 0 then
                        local damageAmount = puff.damagePerSecond * multiplier * dt
                        if damageAmount > 0 then
                            local px = puff.x or 0
                            local py = puff.y or 0
                            local radius = puff.radius or 0
                            local radiusSq = radius * radius
                            for _, target in ipairs(worldEntities) do
                                if target ~= entity and should_damage(entity, target) then
                                    local tx, ty = weapon_beam.resolve_entity_position(target)
                                    if tx and ty then
                                        local dx = tx - px
                                        local dy = ty - py
                                        if dx * dx + dy * dy <= radiusSq then
                                            damageEntity(target, damageAmount, entity, {
                                                x = px,
                                                y = py,
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end

                    activePuffs[#activePuffs + 1] = puff
                end
            end
        end,

        draw = function(self)
            if not graphics then
                return
            end

            local activePuffs = self.activePuffs
            if not activePuffs or #activePuffs == 0 then
                return
            end

            graphics.push("all")
            graphics.setBlendMode("add")

            local time = love and love.timer and love.timer.getTime and love.timer.getTime() or 0

            for i = 1, #activePuffs do
                local puff = activePuffs[i]
                local px = puff.x or 0
                local py = puff.y or 0
                local radius = puff.radius or 0
                local lifeRatio = (puff.lifetime or 0) / (puff.maxLifetime or 1)
                lifeRatio = math.max(0, math.min(1, lifeRatio))

                local glow = puff.glowColor or { 1, 0.7, 1, 0.4 }
                local core = puff.color or { 0.8, 0.3, 1, 0.7 }

                local flicker = 1 + 0.12 * math.sin(time * 9.2 + i)

                graphics.setColor(glow[1], glow[2], glow[3], (glow[4] or 0.4) * lifeRatio)
                graphics.circle("fill", px, py, radius * flicker)

                graphics.setColor(core[1], core[2], core[3], (puff.alpha or 0.78) * lifeRatio)
                graphics.circle("fill", px, py, radius * 0.72 * flicker)

                graphics.setColor(1, 0.9, 1, (puff.highlightAlpha or 0.92) * lifeRatio)
                graphics.circle("fill", px, py, radius * 0.38)
            end

            graphics.pop()
        end,
    }
end
