---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local constants = require("src.constants.game")
local vector = require("src.util.vector")
local Intent = require("src.input.intent")
local damage_util = require("src.util.damage")
local ProjectileFactory = require("src.entities.projectile_factory")
local AudioManager = require("src.audio.manager")

local love = love

local DEFAULT_WEAPON_OFFSET = 30 -- Default muzzle offset when no mount data is provided
local ENEMY_DAMAGE_MULTIPLIER = 0.5 -- Enemy-fired weapons deal half damage to ease early encounters
local ENERGY_EPSILON = 1e-6 -- Tolerance to mitigate floating-point drift when evaluating energy availability
local DEFAULT_PLAYER_ENERGY_DRAIN = 14 -- Fallback energy drain when a weapon does not define custom consumption

---@alias WeaponEntity table
---@alias WeaponComponent table
---@alias WeaponBeamContainer table[]
---@alias WeaponImpactContainer table[]
---@alias WeaponSystemContext { physicsWorld:love.World|nil, damageEntity:fun(target:table, amount:number, source:table, context:table)|nil, camera:table|nil, intentHolder:table|nil, state:table|nil }

local SPARK_COUNT = 12 -- Number of impact sparks spawned when a beam strikes
local SPARK_JITTER_MAX = math.pi * 0.6 -- Maximum angular deviation for spark directions
local SPARK_SPEED_MIN = 140 -- Minimum spark velocity in pixels/second
local SPARK_SPEED_MAX = 240 -- Maximum spark velocity in pixels/second
local SPARK_LIFETIME_BASE = 0.2 -- Minimum lifetime for beam impact sparks (seconds)
local SPARK_LIFETIME_VARIANCE = 0.18 -- Additional randomized spark lifetime (seconds)
local SPARK_VELOCITY_DAMPING = 0.88 -- Damping factor applied each frame to spark velocity

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

local function resolve_entity_position(entity)
    local pos = entity and entity.position
    if pos and pos.x and pos.y then
        return pos.x, pos.y
    end
    return nil, nil
end

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

local function distance_sq(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return dx * dx + dy * dy
end

local function apply_hitscan_damage(damageEntity, target, baseDamage, source, weapon, hitX, hitY)
    if not (damageEntity and target) then
        return 0
    end

    local damage = math.max(0, baseDamage or 0)
    if damage <= 0 then
        return 0
    end

    local damageType = weapon and weapon.damageType
    local armorType = target.armorType
    local multiplier = damage_util.resolve_multiplier(damageType, armorType)
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

local function find_chain_target(world, shooter, originX, originY, rangeSq, alreadyHit, chainCategory)
    if not (world and world.entities) then
        return nil
    end

    local bestTarget
    local bestDistanceSq

    for i = 1, #world.entities do
        local candidate = world.entities[i]
        if candidate and candidate ~= shooter and not (alreadyHit and alreadyHit[candidate]) then
            if candidate.health and (candidate.health.current or 0) > 0 and not candidate.pendingDestroy then
                if not is_friendly_fire(shooter, candidate) then
                    local matchesCategory = true
                    if chainCategory then
                        local candidateCategory = resolve_chain_category(candidate)
                        matchesCategory = candidateCategory == chainCategory
                    end

                    if matchesCategory then
                        local cx, cy = resolve_entity_position(candidate)
                        if cx and cy then
                            local distSq = distance_sq(originX, originY, cx, cy)
                            if distSq <= rangeSq then
                                if not bestDistanceSq or distSq < bestDistanceSq then
                                    bestDistanceSq = distSq
                                    bestTarget = candidate
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

local function perform_chain_lightning(world, shooter, weapon, damageEntity, baseDamage, originTarget, originX, originY, beams, chainConfig)
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

        local nextTarget = find_chain_target(world, shooter, currentX, currentY, rangeSq, hitRegistry, chainCategory)
        if not nextTarget then
            break
        end

        local nx, ny = resolve_entity_position(nextTarget)
        if not (nx and ny) then
            hitRegistry[nextTarget] = true
            break
        end

        local applied = apply_hitscan_damage(damageEntity, nextTarget, currentDamage, shooter, weapon, nx, ny)
        if applied > 0 then
            if beams then
                beams[#beams + 1] = {
                    x1 = currentX,
                    y1 = currentY,
                    x2 = nx,
                    y2 = ny,
                    width = chainWidth,
                    color = chainColor,
                    glow = chainGlow,
                    style = weapon.beamStyle or "straight",
                }
            end
        end

        hitRegistry[nextTarget] = true
        currentX, currentY = nx, ny
    end
end

local function randf(min, max)
    return min + (max - min) * math.random()
end

local function fire_shotgun_pattern(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon, config)
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

local function random_color_from_palette(palette)
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

local function lighten_color(color, factor)
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

local function resolve_damage_multiplier(shooter)
    if shooter and shooter.enemy then
        return ENEMY_DAMAGE_MULTIPLIER
    end
    return 1
end

---@param entity WeaponEntity
---@return number startX
---@return number startY
local function compute_muzzle_origin(entity)
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

        -- Forward offset: move forward along ship's forward axis (negative Y in local space)
        -- Inset: move back from the forward point (reduces forward distance)
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

    local startX = entity.position.x + localOffsetX * cosAngle - localOffsetY * sinAngle
    local startY = entity.position.y + localOffsetX * sinAngle + localOffsetY * cosAngle

    return startX, startY
end
---@param container WeaponImpactContainer|nil
---@param x number
---@param y number
---@param dirX number
---@param dirY number
---@param beamColor number[]
local function spawn_beam_sparks(container, x, y, dirX, dirY, beamColor)
    if not container then
        return
    end

    local baseAngle = math.atan2(dirY, dirX) + math.pi
    local primaryColor = {
        (beamColor[1] or 0.7) * 1.1,
        (beamColor[2] or 0.85) * 1.05,
        (beamColor[3] or 1.0) * 1.05,
        1.0,
    }

    for _ = 1, SPARK_COUNT do
        local jitter = (love.math.random() - 0.5) * SPARK_JITTER_MAX
        local angle = baseAngle + jitter
        local speed = love.math.random(SPARK_SPEED_MIN, SPARK_SPEED_MAX)
        local lifetime = SPARK_LIFETIME_BASE + love.math.random() * SPARK_LIFETIME_VARIANCE

        local spark = {
            x = x + (love.math.random() - 0.5) * 3,
            y = y + (love.math.random() - 0.5) * 3,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            lifetime = lifetime,
            maxLifetime = lifetime,
            size = love.math.random() * 2 + 1.2,
            baseSize = nil,
            color = {
                math.min(1, primaryColor[1]),
                math.min(1, primaryColor[2]),
                math.min(1, primaryColor[3]),
                1.0,
            },
        }
        spark.baseSize = spark.size
        container[#container + 1] = spark
    end
end

---@param entity WeaponEntity|nil
---@param amount number
---@return boolean
local function has_energy(entity, amount)
    local energy = entity and entity.energy
    if not energy then
        return true
    end

    local current = tonumber(energy.current) or 0
    local maxEnergy = tonumber(energy.max) or 0
    local drain = math.max(0, amount)
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

---@param weapon WeaponComponent|nil
---@param key string
local function play_weapon_sound(weapon, key)
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

---@param entity WeaponEntity
---@param startX number
---@param startY number
---@param dirX number
---@param dirY number
---@param weapon WeaponComponent
---@param physicsWorld love.World|nil
---@param damageEntity fun(target:table, amount:number, source:table, context:table)|nil
---@param dt number
---@param beams WeaponBeamContainer
---@param impacts WeaponImpactContainer
local function fire_hitscan(world, entity, startX, startY, dirX, dirY, weapon, physicsWorld, damageEntity, dt, beams, impacts)
    local maxRange = weapon.maxRange or 600
    local endX = startX + dirX * maxRange
    local endY = startY + dirY * maxRange

    if entity and entity.player then
        local drainPerSecond = weapon.energyPerSecond or weapon.energyDrain or DEFAULT_PLAYER_ENERGY_DRAIN
        local energyCost = math.max(0, drainPerSecond * dt)
        if not has_energy(entity, energyCost) then
            return
        end
    end

    local hitInfo
    if physicsWorld then
        local closestFraction = 1
        physicsWorld:rayCast(startX, startY, endX, endY, function(fixture, x, y, xn, yn, fraction)
            if fixture:getBody() == entity.body then
                return -1
            end
            local user = fixture:getUserData()
            if type(user) == "table" then
                if user.type == "projectile" then
                    return -1
                end
                -- Always record the hit for visual effects, even if there's no entity
                if fraction < closestFraction then
                    closestFraction = fraction
                    local targetEntity = user.entity
                    hitInfo = {
                        entity = targetEntity,  -- May be nil for static/environment fixtures
                        x = x,
                        y = y,
                        collider = user.collider,
                        fraction = fraction,
                        type = user.type,
                        nx = xn,
                        ny = yn,
                    }
                end
                return fraction
            end
            return -1
        end)
    end

    if hitInfo then
        endX = hitInfo.x
        endY = hitInfo.y
        local target = hitInfo.entity
        local shouldDamage = true
        if target then
            if entity.faction and target.faction and entity.faction == target.faction then
                shouldDamage = false
            elseif entity.player and target.player then
                shouldDamage = false
            elseif entity.enemy and target.enemy then
                shouldDamage = false
            end
        end

        if shouldDamage and damageEntity and target then
            local dps = weapon.damagePerSecond or 0
            dps = dps * resolve_damage_multiplier(entity)
            local baseDamage = dps * dt
            if baseDamage > 0 then
                local hitX = hitInfo.x
                local hitY = hitInfo.y
                local applied = apply_hitscan_damage(damageEntity, target, baseDamage, entity, weapon, hitX, hitY)

                if applied > 0 and weapon.chainLightning then
                    local originX, originY = resolve_entity_position(target)
                    if not (originX and originY) then
                        originX, originY = hitX, hitY
                    end
                    perform_chain_lightning(world, entity, weapon, damageEntity, baseDamage, target, originX, originY, beams, weapon.chainLightning)
                end
            end
        end
    end

    local beamWidth = weapon.width or 3

    local beamColor = weapon.color or { 0.6, 0.85, 1.0 }
    local beamGlow = weapon.glowColor or { 1.0, 0.8, 0.6 }

    if hitInfo and impacts then
        spawn_beam_sparks(impacts, endX, endY, dirX, dirY, beamColor)
    end

    beams[#beams + 1] = {
        x1 = startX,
        y1 = startY,
        x2 = endX,
        y2 = endY,
        width = beamWidth,
        color = beamColor,
        glow = beamGlow,
        style = weapon.beamStyle or "straight",
    }
end

---@param context WeaponSystemContext
---@return table
return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity

    return tiny.system {
        filter = tiny.requireAll("weapon", "position"),
        init = function(self)
            self.active_beams = {}
            self.beamImpacts = {}
        end,
        update = function(self, dt)
            local world = self.world
            if not world then
                return
            end

            local cam = context.camera
            local intentHolder = context.intentHolder or context.state or context
            local localPlayerId = intentHolder and intentHolder.localPlayerId
            local localPlayerEntity = intentHolder and (intentHolder.player or intentHolder.playerShip)
            local beams = self.active_beams
            local beamImpacts = self.beamImpacts
            for i = 1, #beams do
                beams[i] = nil
            end

            local gameplayState
            if context then
                if type(context.resolveState) == "function" then
                    gameplayState = context:resolveState()
                end
                gameplayState = gameplayState or context.state
            end

            for i = 1, #world.entities do
                local entity = world.entities[i]
                if self.filter(entity) then
                    local weapon = entity.weapon
                    local angle = entity.rotation or 0
                    local forwardX = math.cos(angle - math.pi * 0.5)
                    local forwardY = math.sin(angle - math.pi * 0.5)
                    local startX, startY = compute_muzzle_origin(entity)

                    -- Update weapon cooldown
                    if weapon.cooldown and weapon.cooldown > 0 then
                        weapon.cooldown = weapon.cooldown - dt
                    end

                    local fire = false
                    local targetX, targetY
                    local activeTarget
                    local intent = Intent.get(intentHolder, entity.playerId)
                    local isLocalPlayer = false
                    if entity.player then
                        if localPlayerId then
                            isLocalPlayer = entity.playerId == localPlayerId
                        elseif localPlayerEntity then
                            isLocalPlayer = entity == localPlayerEntity
                        end
                    end

                    if entity.player then
                        if intent then
                            fire = not not intent.firePrimary
                            targetX = intent.aimX
                            targetY = intent.aimY
                        elseif not isLocalPlayer then
                            fire = weapon.firing or weapon.alwaysFire
                            if weapon.fireMode == "hitscan" and weapon.beamTimer and weapon.beamTimer > 0 then
                                fire = true
                            end
                            targetX = weapon.targetX
                            targetY = weapon.targetY
                        end
                    else
                        fire = weapon.firing or weapon.alwaysFire
                        targetX = weapon.targetX
                        targetY = weapon.targetY
                    end

                    if (not targetX or not targetY) and isLocalPlayer and love.mouse then
                        local mx, my = love.mouse.getPosition()
                        if cam then
                            local zoom = cam.zoom or 1
                            if zoom ~= 0 then
                                mx = mx / zoom + cam.x
                                my = my / zoom + cam.y
                            else
                                mx = cam.x
                                my = cam.y
                            end
                        end
                        targetX = targetX or mx
                        targetY = targetY or my
                    end

                    if isLocalPlayer and not fire and love.mouse and love.mouse.isDown then
                        fire = love.mouse.isDown(1)
                    end

                    if weapon.lockOnTarget and gameplayState then
                        local candidate = gameplayState.activeTarget
                        if candidate and not candidate.pendingDestroy then
                            local tx, ty = resolve_entity_position(candidate)
                            if tx and ty then
                                activeTarget = candidate
                                targetX = tx
                                targetY = ty
                            end
                        end
                    end

                    weapon.targetX = targetX
                    weapon.targetY = targetY

                    if weapon.travelToCursor and targetX and targetY and isLocalPlayer then
                        local indicator = weapon._pendingTravelIndicator or {}
                        indicator.x = targetX
                        indicator.y = targetY
                        indicator.radius = weapon.travelIndicatorRadius
                            or weapon.impactRadius
                            or (weapon.projectileSize and weapon.projectileSize * 3.2)
                            or 32
                        indicator.outlineColor = indicator.outlineColor or weapon.travelIndicatorColor or weapon.glowColor or weapon.color
                        indicator.innerColor = indicator.innerColor or weapon.travelIndicatorInnerColor
                        weapon._pendingTravelIndicator = indicator
                    else
                        weapon._pendingTravelIndicator = nil
                    end

                    -- Determine firing direction
                    local dirX, dirY
                    if targetX and targetY then
                        dirX = targetX - startX
                        dirY = targetY - startY
                    else
                        dirX = forwardX
                        dirY = forwardY
                    end

                    local normDirX, normDirY, dirLen = vector.normalize(dirX, dirY)
                    if dirLen <= vector.EPSILON then
                        dirX = forwardX
                        dirY = forwardY
                    else
                        dirX = normDirX
                        dirY = normDirY
                    end

                    local fireMode = weapon.fireMode or "hitscan"

                    -- PROJECTILE MODE (Cannon, missiles, etc.)
                    if fireMode == "projectile" then
                        if fire and (not weapon.cooldown or weapon.cooldown <= 0) then
                            if entity and entity.player then
                                local shotCost = weapon.energyPerShot or weapon.energyCost or weapon.energyDrain or weapon.energyPerSecond or DEFAULT_PLAYER_ENERGY_DRAIN
                                if not has_energy(entity, shotCost) then
                                    fire = false
                                end
                            end

                            if fire then
                                if weapon.travelToCursor and targetX and targetY then
                                    local dx = targetX - startX
                                    local dy = targetY - startY
                                    local speed = weapon.projectileSpeed or 0
                                    if speed > 0 then
                                        local distance = math.sqrt(dx * dx + dy * dy)
                                        weapon._shotLifetime = math.max(0.1, distance / speed)
                                    end
                                end

                                if weapon.randomizeColorOnFire and weapon.colorPalette then
                                    local shotColor = random_color_from_palette(weapon.colorPalette)
                                    if shotColor then
                                        weapon._shotColor = shotColor
                                        weapon._shotGlow = lighten_color(shotColor, weapon.glowBoost or 0.45)
                                    end
                                end

                                if weapon.lockOnTarget and activeTarget then
                                    weapon._pendingTargetEntity = activeTarget
                                end

                                if weapon.projectilePattern == "shotgun" and type(weapon.shotgunPatternConfig) == "table" then
                                    fire_shotgun_pattern(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon, weapon.shotgunPatternConfig)
                                else
                                    ProjectileFactory.spawn(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon)
                                end
                                if weapon._pendingTargetEntity then
                                    weapon._pendingTargetEntity = nil
                                end
                                play_weapon_sound(weapon, "fire")

                                -- Reset cooldown
                                local fireRate = weapon.fireRate or 0.5
                                weapon.cooldown = fireRate
                            end
                        end

                        -- Track firing state for visual/audio feedback
                        weapon.firing = fire

                    -- HITSCAN MODE (Laser beams)
                    elseif fireMode == "hitscan" then
                        local usesBurst = weapon.fireRate ~= nil
                        local triggered = false

                        if usesBurst and fire and (not weapon.cooldown or weapon.cooldown <= 0) then
                            weapon.cooldown = weapon.fireRate
                            if weapon.beamDuration and weapon.beamDuration > 0 then
                                weapon.beamTimer = weapon.beamDuration
                            else
                                weapon.beamTimer = nil
                            end
                            triggered = true
                        end

                        local beamActive
                        if usesBurst then
                            if weapon.beamTimer and weapon.beamTimer > 0 then
                                beamActive = true
                            else
                                beamActive = triggered
                            end
                        else
                            beamActive = fire
                        end

                        if usesBurst then
                            if triggered then
                                play_weapon_sound(weapon, "fire")
                            end
                            if not beamActive then
                                weapon._fireSoundPlaying = false
                            end
                        else
                            if beamActive then
                                if not weapon._fireSoundPlaying then
                                    play_weapon_sound(weapon, "fire")
                                    weapon._fireSoundPlaying = true
                                end
                            else
                                weapon._fireSoundPlaying = false
                            end
                        end

                        if beamActive then
                            fire_hitscan(world, entity, startX, startY, dirX, dirY, weapon, physicsWorld, damageEntity, dt, beams, beamImpacts)
                        end

                        if usesBurst and weapon.beamTimer then
                            weapon.beamTimer = math.max(weapon.beamTimer - dt, 0)
                            if weapon.beamTimer <= 0 then
                                weapon.beamTimer = nil
                            end
                        end

                        weapon.firing = beamActive
                    else
                        weapon.firing = fire
                    end
                end
            end

            for index = #beamImpacts, 1, -1 do
                local spark = beamImpacts[index]
                spark.lifetime = spark.lifetime - dt
                if spark.lifetime <= 0 then
                    table.remove(beamImpacts, index)
                else
                    spark.x = spark.x + spark.vx * dt
                    spark.y = spark.y + spark.vy * dt
                    spark.vx = spark.vx * SPARK_VELOCITY_DAMPING
                    spark.vy = spark.vy * SPARK_VELOCITY_DAMPING
                    local ratio = spark.maxLifetime > 0 and (spark.lifetime / spark.maxLifetime) or 0
                    if spark.baseSize then
                        spark.size = spark.baseSize * math.max(ratio, 0)
                    end
                    spark.color[4] = math.max(0, ratio)
                end
            end
        end,
        draw = function(self)
            local beams = self.active_beams
            if not beams then
                return
            end

            love.graphics.push("all")
            love.graphics.setBlendMode("add")
            
            for i = 1, #beams do
                local beam = beams[i]
                local dx = beam.x2 - beam.x1
                local dy = beam.y2 - beam.y1
                local length = vector.length(dx, dy)
                local angle = math.atan2(dy, dx)
                
                love.graphics.push()
                love.graphics.translate(beam.x1, beam.y1)
                love.graphics.rotate(angle)

                local baseWidth = beam.width or 3
                local glow = beam.glow or { 1.0, 0.8, 0.6 }
                local color = beam.color or { 0.6, 0.85, 1.0 }
                local beamStyle = beam.style or "straight"

                if beamStyle == "lightning" then
                    -- Strongly unstable lightning bolt style
                    local segments = math.max(18, math.floor(length / 10))
                    local points = {}

                    -- Time-based wobble so the bolt "shimmers" frame-to-frame
                    local t = love.timer and love.timer.getTime and love.timer.getTime() or 0

                    -- Start point
                    points[1] = { x = 0, y = 0 }

                    -- Generate chaotic jagged points along the beam
                    for j = 1, segments - 1 do
                        local progress = j / segments
                        local centralFactor = 1 - math.min(1, math.abs(progress - 0.5) * 1.4)
                        local baseDev = baseWidth * (4.0 + math.random() * 3.0)
                        local timeWobble = math.sin(t * 18 + j * 1.9) * baseWidth * 1.4
                        local maxDeviation = (baseDev + math.abs(timeWobble)) * centralFactor

                        local xJitter = (math.random() - 0.5) * baseWidth * 1.3
                        local x = progress * length + xJitter
                        local y = (math.random() - 0.5) * maxDeviation

                        points[j + 1] = { x = x, y = y }
                    end

                    -- End point
                    points[segments + 1] = { x = length, y = 0 }

                    -- Draw glow segments (wide, soft halo)
                    local glowWidth = math.max(baseWidth * 2.8, baseWidth + 3.2)
                    love.graphics.setLineWidth(glowWidth)
                    love.graphics.setColor(glow[1], glow[2], glow[3], 0.24)
                    for j = 1, #points - 1 do
                        love.graphics.line(points[j].x, points[j].y, points[j + 1].x, points[j + 1].y)
                    end

                    -- Draw core lightning (thicker, slightly noisy)
                    local coreWidth = math.max(baseWidth * 1.0, 1.4)
                    love.graphics.setLineWidth(coreWidth)
                    love.graphics.setColor(color[1], color[2], color[3], 0.95)
                    for j = 1, #points - 1 do
                        love.graphics.line(points[j].x, points[j].y, points[j + 1].x, points[j + 1].y)
                    end

                    -- Draw bright highlight center
                    local highlightWidth = math.max(coreWidth * 0.5, 0.7)
                    love.graphics.setLineWidth(highlightWidth)
                    love.graphics.setColor(1.0, 1.0, 1.0, 0.8)
                    for j = 1, #points - 1 do
                        love.graphics.line(points[j].x, points[j].y, points[j + 1].x, points[j + 1].y)
                    end

                    -- Occasionally spawn 1–2 branches so it feels chaotic
                    if length > 60 then
                        local branchCount = 0
                        local maxBranches = (length > 160) and 2 or 1
                        for _ = 1, maxBranches do
                            if math.random() < 0.9 then
                                branchCount = branchCount + 1
                                local branchPoint = math.random(2, #points - 1)
                                local branch = points[branchPoint]

                                local branchLength = baseWidth * (4.0 + math.random() * 7)
                                local branchAngle = (math.random() - 0.5) * math.pi * 1.1
                                local branchEndX = branch.x + math.cos(branchAngle) * branchLength
                                local branchEndY = branch.y + math.sin(branchAngle) * branchLength

                                love.graphics.setLineWidth(coreWidth * 0.7)
                                love.graphics.setColor(color[1], color[2], color[3], 0.7)
                                love.graphics.line(branch.x, branch.y, branchEndX, branchEndY)

                                love.graphics.setLineWidth(highlightWidth * 0.55)
                                love.graphics.setColor(1.0, 1.0, 1.0, 0.5)
                                love.graphics.line(branch.x, branch.y, branchEndX, branchEndY)
                            end
                        end
                    end
                else
                    -- Default straight beam style
                    local glowWidth = math.max(baseWidth * 1.5, baseWidth + 1.2)
                    local coreWidth = math.max(baseWidth * 0.55, 0.45)
                    local highlightWidth = math.max(coreWidth * 0.45, 0.22)

                    local halfGlow = glowWidth * 0.5
                    local halfCore = coreWidth * 0.5
                    local halfHighlight = highlightWidth * 0.5

                    -- Soft glow halo
                    love.graphics.setColor(glow[1], glow[2], glow[3], 0.28)
                    love.graphics.rectangle("fill", 0, -halfGlow, length, glowWidth)

                    -- Core body
                    love.graphics.setColor(color[1], color[2], color[3], 0.95)
                    love.graphics.rectangle("fill", 0, -halfCore, length, coreWidth)

                    -- White-hot center
                    love.graphics.setColor(1.0, 1.0, 1.0, 0.6)
                    love.graphics.rectangle("fill", 0, -halfHighlight, length, highlightWidth)
                end

                love.graphics.pop()
            end

            love.graphics.pop()
        end,
    }
end
