local damage_util = require("src.util.damage")
local vector = require("src.util.vector")

local sqrt = math.sqrt

local weapon_beam = {}

local function resolve_entity_position(entity)
    if not entity then
        return nil, nil
    end

    local pos = entity.position
    if pos and pos.x and pos.y then
        return pos.x, pos.y
    end

    local body = entity.body
    if body and not body:isDestroyed() then
        return body:getPosition()
    end

    return nil, nil
end
weapon_beam.resolve_entity_position = resolve_entity_position

local function is_friendly_fire(shooter, target)
    if not shooter or not target then
        return false
    end

    if shooter == target then
        return true
    end

    if shooter.faction and target.faction and shooter.faction == target.faction then
        return true
    end

    if shooter.player and target.player then
        return true
    end

    if shooter.enemy and target.enemy then
        return true
    end

    return false
end
weapon_beam.is_friendly_fire = is_friendly_fire

local function resolve_chain_category(entity)
    if not entity then
        return nil
    end

    if entity.enemy then
        return "enemy"
    end

    if entity.player then
        return "player"
    end

    if entity.asteroid or entity.type == "asteroid" then
        return "asteroid"
    end

    if entity.station or entity.type == "station" then
        return "station"
    end

    if entity.wreckage then
        return "wreckage"
    end

    if entity.armorType then
        return "armor:" .. tostring(entity.armorType)
    end

    if entity.type then
        return tostring(entity.type)
    end

    return nil
end
weapon_beam.resolve_chain_category = resolve_chain_category

local function distance_sq(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return dx * dx + dy * dy
end
weapon_beam.distance_sq = distance_sq

function weapon_beam.apply_hitscan_damage(damageEntity, target, baseDamage, source, weapon, hitX, hitY)
    if not (damageEntity and target) then
        return 0
    end

    local damage = math.max(0, baseDamage or 0)
    if damage <= 0 then
        return 0
    end

    local damageType = weapon and weapon.damageType
    local armorType = target.armorType
    local overrides = weapon and weapon.armorMultipliers
    local multiplier = damage_util.resolve_multiplier(damageType, armorType, overrides)
    damage = damage * multiplier
    if damage <= 0 then
        return 0
    end

    damageEntity(target, damage, source, {
        x = hitX,
        y = hitY,
    })

    return damage
end

function weapon_beam.find_chain_target(world, shooter, originX, originY, rangeSq, alreadyHit, chainCategory)
    if not world then
        return nil
    end

    local spatialGrid = world.spatialGrid

    local bestTarget
    local bestDistanceSq

    local function matches_category(candidate)
        if not chainCategory then
            return true
        end
        local candidateCategory = resolve_chain_category(candidate)
        return candidateCategory == chainCategory
    end

    local function consider_candidate(candidate)
        if not candidate or candidate == shooter then
            return
        end
        if alreadyHit and alreadyHit[candidate] then
            return
        end
        if candidate.pendingDestroy then
            return
        end
        local health = candidate.health
        if not (health and (health.current or 0) > 0) then
            return
        end
        if is_friendly_fire(shooter, candidate) then
            return
        end
        if not matches_category(candidate) then
            return
        end

        local cx, cy = resolve_entity_position(candidate)
        if not (cx and cy) then
            return
        end

        local distSq = distance_sq(originX, originY, cx, cy)
        if distSq <= rangeSq then
            if not bestDistanceSq or distSq < bestDistanceSq then
                bestDistanceSq = distSq
                bestTarget = candidate
            end
        end
    end

    if spatialGrid and rangeSq and rangeSq > 0 and rangeSq < math.huge then
        local searchRadius = sqrt(rangeSq)
        if searchRadius > 0 then
            spatialGrid:eachCircle(originX, originY, searchRadius, consider_candidate, function(candidate)
                if not candidate or candidate == shooter then
                    return false
                end
                if alreadyHit and alreadyHit[candidate] then
                    return false
                end
                if candidate.pendingDestroy then
                    return false
                end
                if not (candidate.health and (candidate.health.current or 0) > 0) then
                    return false
                end
                if is_friendly_fire(shooter, candidate) then
                    return false
                end
                if chainCategory then
                    local candidateCategory = resolve_chain_category(candidate)
                    return candidateCategory == chainCategory
                end
                return true
            end)
            return bestTarget
        end
    end

    if not world.entities then
        return nil
    end

    for i = 1, #world.entities do
        consider_candidate(world.entities[i])
    end

    return bestTarget
end

function weapon_beam.perform_chain_lightning(world, shooter, weapon, damageEntity, baseDamage, originTarget, originX, originY, onSegment, chainConfig)
    if not (world and chainConfig and baseDamage and baseDamage > 0 and originTarget) then
        return
    end

    local maxTargets = chainConfig.maxTargets or chainConfig.maxBounces or chainConfig.bounces or 1
    maxTargets = math.max(1, math.floor(maxTargets + 0.5))
    if maxTargets <= 1 then
        return
    end

    local range = math.max(0, chainConfig.range or chainConfig.radius or 220)
    local rangeSq = range * range
    local falloff = chainConfig.falloff or chainConfig.damageFalloff or 0.65
    local minDamage = chainConfig.minDamage or 0
    local minFraction = chainConfig.minFraction
    if minFraction then
        minDamage = math.max(minDamage, baseDamage * math.max(0, minFraction))
    end

    local chainColor = chainConfig.color or weapon.color
    local chainGlow = chainConfig.glowColor or weapon.glowColor
    local chainWidth = chainConfig.width or weapon.width or 3
    local chainCategory = resolve_chain_category(originTarget)

    local hitRegistry = {}
    hitRegistry[originTarget] = true

    local currentDamage = baseDamage
    local currentX = originX
    local currentY = originY

    local remaining = maxTargets - 1
    for _ = 1, remaining do
        currentDamage = currentDamage * falloff
        if currentDamage <= 0 then
            break
        end
        if minDamage > 0 and currentDamage < minDamage then
            break
        end

        local nextTarget = weapon_beam.find_chain_target(world, shooter, currentX, currentY, rangeSq, hitRegistry, chainCategory)
        if not nextTarget then
            break
        end

        local nx, ny = resolve_entity_position(nextTarget)
        if not (nx and ny) then
            hitRegistry[nextTarget] = true
            break
        end

        local applied = weapon_beam.apply_hitscan_damage(damageEntity, nextTarget, currentDamage, shooter, weapon, nx, ny)
        if applied > 0 then
            if type(onSegment) == "function" then
                onSegment({
                    x1 = currentX,
                    y1 = currentY,
                    x2 = nx,
                    y2 = ny,
                    width = chainWidth,
                    color = chainColor,
                    glow = chainGlow,
                    style = weapon.beamStyle or "straight",
                })
            end
        end

        hitRegistry[nextTarget] = true
        currentX, currentY = nx, ny
    end
end

return weapon_beam
