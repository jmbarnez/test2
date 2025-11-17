local tiny = require("libs.tiny")
local love = love
local lg, lp = love.graphics, love.physics
local damage_util = require("src.util.damage")
local ProjectileFactory = require("src.entities.projectile_factory")
local Entities = require("src.states.gameplay.entities")
local math_util = require("src.util.math")

-- Lua compat helpers
local unpack = table.unpack or unpack
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local SQRT = math.sqrt
local EPS = 1e-8

local spawn_explosion_effect
local apply_explosion_damage

local function normalize(x, y)
    x, y = x or 0, y or 0
    local lenSq = x * x + y * y
    if lenSq <= EPS then
        return 0, -1
    end
    local inv = 1 / SQRT(lenSq)
    return x * inv, y * inv
end

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

local function is_target_valid(target)
    if not target or target.pendingDestroy then
        return false
    end
    local health = target.health
    if health and health.current and health.current <= 0 then
        return false
    end
    return true
end

local function apply_homing(entity, dt, damageEntity, system)
    local homing = entity.homing
    if not homing or dt <= 0 then
        return
    end

    local body = entity.body
    if not (body and not body:isDestroyed()) then
        return
    end

    local target = homing.target
    if target and not is_target_valid(target) then
        target = nil
        homing.target = nil
    end

    if not target and type(homing.acquireTarget) == "function" then
        local ok, resolved = pcall(homing.acquireTarget, homing, entity)
        if ok and resolved then
            target = resolved
            homing.target = resolved
        end
    end

    local tx, ty
    local desiredAngle
    local dirLenSq

    if target then
        tx, ty = resolve_entity_position(target)
        if not (tx and ty) then
            return
        end

        local x, y = body:getPosition()
        local toTargetX = tx - x
        local toTargetY = ty - y
        dirLenSq = toTargetX * toTargetX + toTargetY * toTargetY
        if dirLenSq <= EPS then
            return
        end

        local desiredDirX, desiredDirY = normalize(toTargetX, toTargetY)
        desiredAngle = atan2(desiredDirY, desiredDirX)
    end

    local vx, vy = body:getLinearVelocity()
    local currentSpeed = math.sqrt(vx * vx + vy * vy)
    local currentAngle
    if currentSpeed > EPS then
        currentAngle = atan2(vy, vx)
    else
        currentAngle = (body:getAngle() or 0) - math.pi * 0.5
        currentSpeed = homing.initialSpeed or homing.speed or 0
    end

    if not desiredAngle then
        desiredAngle = currentAngle
    end

    local turnRate = homing.turnRate or math.rad(220)
    local maxTurn = turnRate * dt
    local delta = math_util.clamp_angle(desiredAngle - currentAngle)
    if delta > maxTurn then
        delta = maxTurn
    elseif delta < -maxTurn then
        delta = -maxTurn
    end

    local limitedAngle = currentAngle + delta

    local desiredSpeed = currentSpeed
    local acceleration = homing.acceleration or homing.accel
    if acceleration and acceleration ~= 0 then
        local targetSpeed = homing.maxSpeed or homing.speed or desiredSpeed
        if targetSpeed > desiredSpeed then
            desiredSpeed = math.min(targetSpeed, desiredSpeed + acceleration * dt)
        elseif homing.speed and homing.speed < desiredSpeed then
            desiredSpeed = math.max(homing.speed, desiredSpeed - math.abs(acceleration) * dt)
        end
    elseif homing.speed then
        desiredSpeed = homing.speed
    end

    if homing.maxSpeed then
        desiredSpeed = math.min(desiredSpeed, homing.maxSpeed)
    end
    if homing.minSpeed then
        desiredSpeed = math.max(desiredSpeed, homing.minSpeed)
    end

    if desiredSpeed <= EPS then
        desiredSpeed = EPS
    end

    local targetVelX = math.cos(limitedAngle) * desiredSpeed
    local targetVelY = math.sin(limitedAngle) * desiredSpeed

    local steeringAccel = homing.steeringAcceleration
    if not steeringAccel and homing.usePhysicsSteering then
        local referenceSpeed = math.max(desiredSpeed, homing.initialSpeed or 0, homing.speed or 0, homing.maxSpeed or 0)
        steeringAccel = referenceSpeed * turnRate
    end

    local newVelX
    local newVelY

    if steeringAccel and steeringAccel > 0 then
        local deltaVelX = targetVelX - vx
        local deltaVelY = targetVelY - vy
        local deltaVelMag = math.sqrt(deltaVelX * deltaVelX + deltaVelY * deltaVelY)
        local maxDelta = steeringAccel * dt
        if deltaVelMag > maxDelta then
            local scale = maxDelta / deltaVelMag
            deltaVelX = deltaVelX * scale
            deltaVelY = deltaVelY * scale
        end

        newVelX = vx + deltaVelX
        newVelY = vy + deltaVelY

        local newSpeed = math.sqrt(newVelX * newVelX + newVelY * newVelY)
        if newSpeed > desiredSpeed and newSpeed > EPS then
            local scale = desiredSpeed / newSpeed
            newVelX = newVelX * scale
            newVelY = newVelY * scale
            newSpeed = desiredSpeed
        end

        if homing.minSpeed and newSpeed < homing.minSpeed and newSpeed > EPS then
            local scale = homing.minSpeed / newSpeed
            newVelX = newVelX * scale
            newVelY = newVelY * scale
        end
    else
        newVelX = targetVelX
        newVelY = targetVelY
    end

    body:setLinearVelocity(newVelX, newVelY)

    local visualAngle
    if math.abs(newVelX) > EPS or math.abs(newVelY) > EPS then
        visualAngle = atan2(newVelY, newVelX)
    else
        visualAngle = limitedAngle
    end
    body:setAngle(visualAngle + math.pi * 0.5)

    if entity.velocity then
        entity.velocity.x = newVelX
        entity.velocity.y = newVelY
    end

    if homing.faceTarget then
        entity.rotation = visualAngle + math.pi * 0.5
    end

    if homing.hitRadius and target and tx and ty then
        local x, y = body:getPosition()
        local dx = tx - x
        local dy = ty - y
        local distanceSq = dx * dx + dy * dy
        if distanceSq <= homing.hitRadius * homing.hitRadius then
            if damageEntity and entity.projectile then
                local projectileComponent = entity.projectile
                local baseDamage = projectileComponent.damage or 0
                if baseDamage > 0 then
                    local owner = projectileComponent.owner or entity
                    damageEntity(target, baseDamage, owner, {
                        x = tx,
                        y = ty,
                    })
                end
            end

            if system and system.explosions and homing.explosion and not homing._explosionSpawned then
                spawn_explosion_effect(system.explosions, system.impactParticles, tx, ty, entity, homing.explosion)
                apply_explosion_damage(system, damageEntity, tx, ty, entity, homing.explosion)
            end

            entity.pendingDestroy = true
            return
        end
    end
end

local function apply_gravity_well(system, projectile, body)
    local config = projectile and projectile.gravityWell
    if not config then
        return
    end

    local world = system and system.world
    if not (world and world.entities) then
        return
    end

    if not (body and not body:isDestroyed()) then
        return
    end

    local radius = config.radius or config.range or 0
    if radius <= EPS then
        return
    end

    local radiusSq = radius * radius
    local minDistance = math.max(0, config.minDistance or config.innerRadius or 12)
    local minDistanceSq = minDistance * minDistance
    local pullStrength = config.force or config.pullForce or config.strength or 4200
    if pullStrength <= 0 then
        return
    end

    local falloff = config.falloff or 1.6
    local maxTargets = config.maxTargets or math.huge
    local includeProjectiles = config.includeProjectiles or false
    local includeStatic = config.includeStatic or false
    local excludePlayers = config.excludePlayers ~= false
    local excludeOwner = config.excludeOwner ~= false
    local onlyEnemies = config.onlyEnemies or false
    local owner = config.owner
    local drag = config.drag or 0
    local impulseStrength = config.impulse

    local x, y = body:getPosition()
    local affected = 0
    local entities = world.entities

    for i = 1, #entities do
        if affected >= maxTargets then
            break
        end

        local target = entities[i]
        if target and target ~= projectile and not target.pendingDestroy then
            if excludeOwner and target == owner then
                goto continue
            end
            if excludePlayers and target.player then
                goto continue
            end
            if onlyEnemies and not target.enemy then
                goto continue
            end
            if target.projectile and not includeProjectiles then
                goto continue
            end

            local targetBody = target.body
            if not (targetBody and not targetBody:isDestroyed()) then
                goto continue
            end
            if targetBody == body then
                goto continue
            end
            if not includeStatic then
                local bodyType = targetBody:getType()
                if bodyType ~= "dynamic" then
                    goto continue
                end
            end

            local tx, ty = resolve_entity_position(target)
            if not (tx and ty) then
                goto continue
            end

            local dx = tx - x
            local dy = ty - y
            local distSq = dx * dx + dy * dy
            if distSq > radiusSq or distSq <= minDistanceSq or distSq <= EPS then
                goto continue
            end

            local distance = math.sqrt(distSq)
            if distance <= 0 then
                goto continue
            end

            local dirX = dx / distance
            local dirY = dy / distance
            local proximity = 1 - math.min(distance / radius, 1)
            if proximity <= 0 then
                goto continue
            end

            local scaled = pullStrength * (proximity ^ falloff)
            if scaled <= 0 then
                goto continue
            end

            if impulseStrength and impulseStrength > 0 then
                local impulse = impulseStrength * (proximity ^ falloff)
                targetBody:applyLinearImpulse(dirX * impulse, dirY * impulse)
            else
                targetBody:applyForce(dirX * scaled, dirY * scaled)
            end

            if drag > 0 then
                local vx, vy = targetBody:getLinearVelocity()
                targetBody:applyForce(-vx * drag * proximity, -vy * drag * proximity)
            end

            affected = affected + 1
        end

        ::continue::
    end
end

local function randf(min, max)
    -- math.random() -> [0,1); scale to [min,max]
    return min + (max - min) * math.random()
end

local function queue_spawn(system, owner, x, y, dirX, dirY, weaponConfig, speedMultiplier)
    if not system then return end
    local pending = system.pendingSpawns
    pending[#pending + 1] = {
        owner = owner,
        x = x,
        y = y,
        dirX = dirX,
        dirY = dirY,
        weapon = weaponConfig,
        speedMultiplier = speedMultiplier,
    }
end

local function create_projectile_shape(drawable, size)
    local shape = drawable.shape or drawable.form or "orb"

    if shape == "beam" or shape == "rectangle" then
        local width = drawable.width or size
        local length = drawable.length or drawable.beamLength
        if not length then
            local lengthScale = drawable.lengthScale or 7
            length = width * lengthScale
        end
        -- Box2D uses width, height. Treat "length" as longitudinal axis, "width" as thickness.
        return lp.newRectangleShape(length, width)
    elseif shape == "polygon" and drawable.vertices then
        return lp.newPolygonShape(unpack(drawable.vertices))
    else
        local radius = (drawable.radius or size) * 0.5
        return lp.newCircleShape(radius)
    end
end

local function create_impact_particles(x, y, projectile)
    local particles = {}
    local numParticles = math.random(8, 16)
    local baseColor = (projectile.drawable and projectile.drawable.color) or { 0.2, 0.8, 1.0 }

    local desaturatedColor = {
        baseColor[1] * 0.7,
        baseColor[2] * 0.7,
        baseColor[3] * 0.7
    }

    -- Derive impact direction from velocity
    local impactAngle = 0
    if projectile.velocity then
        impactAngle = atan2(projectile.velocity.y or 0, projectile.velocity.x or 0)
    end

    for i = 1, numParticles do
        local spreadAngle = impactAngle + math.pi + (math.random() - 0.5) * math.pi * 0.8
        local speed = math.random(80, 200)
        local lifetime = randf(0.24, 0.52)
        local size = randf(3.4, 5.1)
        local glowSize = size * randf(1.4, 1.75)
        local tintShift = randf(0.2, 0.5)

        particles[i] = {
            x = x + math.random(-2, 2),
            y = y + math.random(-2, 2),
            vx = math.cos(spreadAngle) * speed,
            vy = math.sin(spreadAngle) * speed,
            size = size,
            maxSize = size,
            glowSize = glowSize,
            maxGlowSize = glowSize,
            lifetime = lifetime,
            maxLifetime = lifetime,
            baseAlpha = 0.85 + math.random() * 0.15,
            color = {
                math.min(1, desaturatedColor[1] + tintShift * 0.4),
                math.min(1, desaturatedColor[2] + tintShift * 0.2),
                math.min(1, desaturatedColor[3] + tintShift),
                0.9
            }
        }
    end

    return particles
end

local function clone_color(color, defaultAlpha)
    if type(color) ~= "table" then
        if defaultAlpha then
            return { 1, 1, 1, defaultAlpha }
        end
        return nil
    end

    return {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        color[4] ~= nil and color[4] or defaultAlpha or 1,
    }
end

spawn_explosion_effect = function(explosionPool, impactPool, x, y, projectile, config)
    if not explosionPool then
        return
    end

    config = config or {}

    local maxRadius = config.radius or 52
    local startRadius = config.startRadius or math.max(8, maxRadius * 0.35)
    local duration = config.duration or 0.5

    local color = clone_color(config.color, 0.85) or { 1.0, 0.62, 0.24, 0.85 }
    local ringColor = clone_color(config.ringColor, 0.9)

    local entry = {
        x = x,
        y = y,
        radius = startRadius,
        startRadius = startRadius,
        maxRadius = maxRadius,
        lifetime = duration,
        maxLifetime = duration,
        color = color,
        baseAlpha = color and (color[4] or 1) or 1,
        ringColor = ringColor,
        baseRingAlpha = ringColor and (ringColor[4] or 1) or 0,
        ringWidth = config.ringWidth or maxRadius * 0.12,
        ringRadiusScale = config.ringRadiusScale or 1.0,
    }

    explosionPool[#explosionPool + 1] = entry

    if impactPool and config.sparkCount and config.sparkCount > 0 then
        local sparkColor = clone_color(config.sparkColor, 1) or color or { 1, 0.72, 0.3, 1 }
        local minSpeed = config.sparkSpeedMin or 140
        local maxSpeed = config.sparkSpeedMax or 260
        local minLifetime = config.sparkLifetimeMin or 0.28
        local maxLifetime = config.sparkLifetimeMax or 0.55
        local minSize = config.sparkSizeMin or 2.0
        local maxSize = config.sparkSizeMax or 4.2
        local glowScale = config.sparkGlowScale or 1.6
        for i = 1, config.sparkCount do
            local angle = math.random() * math.pi * 2
            local speed = minSpeed + math.random() * (maxSpeed - minSpeed)
            local lifetime = minLifetime + math.random() * (maxLifetime - minLifetime)
            local size = minSize + math.random() * (maxSize - minSize)

            impactPool[#impactPool + 1] = {
                x = x,
                y = y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                size = size,
                maxSize = size,
                glowSize = size * glowScale,
                maxGlowSize = size * glowScale,
                lifetime = lifetime,
                maxLifetime = lifetime,
                baseAlpha = sparkColor[4] or 1,
                color = {
                    sparkColor[1] or 1,
                    sparkColor[2] or 0.8,
                    sparkColor[3] or 0.4,
                    sparkColor[4] or 1,
                }
            }
        end
    end

    if projectile and projectile.homing then
        projectile.homing._explosionSpawned = true
    end

    return entry
end

local function should_damage_target(projectile, target)
    if target == projectile then
        return false
    end
    if not target or target.pendingDestroy then
        return false
    end
    if projectile.projectile and projectile.projectile.owner == target then
        return false
    end
    local ownerPlayerId = projectile.projectile and projectile.projectile.ownerPlayerId
    if ownerPlayerId and target.playerId == ownerPlayerId then
        return false
    end
    if projectile.faction and target.faction and projectile.faction == target.faction then
        return false
    end
    if projectile.playerProjectile and target.player then
        return false
    end
    if projectile.enemyProjectile and target.enemy then
        return false
    end
    if not target.health then
        return false
    end
    return true
end

apply_explosion_damage = function(system, damageEntityCallback, x, y, projectile, config)
    if not (system and damageEntityCallback and config) then
        return
    end

    if projectile._aoeApplied then
        return
    end

    local baseDamage = config.damage or 0
    local radius = config.damageRadius or config.radius or 0
    if baseDamage <= 0 or radius <= 0 then
        return
    end

    local world = system.world
    if not (world and world.entities) then
        return
    end

    local radiusSq = radius * radius
    local projectileComponent = projectile.projectile or {}
    local owner = projectileComponent.owner or projectile
    local damageType = config.damageType or projectileComponent.damageType

    local entities = world.entities
    for i = 1, #entities do
        local target = entities[i]
        if should_damage_target(projectile, target) then
            local tx, ty = resolve_entity_position(target)
            if tx and ty then
                local dx = tx - x
                local dy = ty - y
                local distSq = dx * dx + dy * dy
                if distSq <= radiusSq then
                    local distance = SQRT(distSq)
                    local ratio = radius > 0 and (distance / radius) or 1
                    if ratio <= 1 then
                        local multiplier = 1
                        local falloff = config.damageFalloff
                        if falloff and falloff > 0 then
                            local t = math.max(0, 1 - ratio)
                            if t <= 0 then
                                multiplier = 0
                            else
                                multiplier = t ^ falloff
                            end
                        end

                        if multiplier > 0 then
                            local amount = baseDamage * multiplier
                            if damageType then
                                local armorType = target.armorType
                                local typeMultiplier = damage_util.resolve_multiplier(damageType, armorType)
                                amount = amount * typeMultiplier
                            end

                            if amount > 0 then
                                damageEntityCallback(target, amount, owner, {
                                    x = x,
                                    y = y,
                                    radius = radius,
                                    type = "explosion",
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    projectile._aoeApplied = true
end

local function trigger_delayed_spawn(system, projectile, reason, physicsWorld)
    local delayed = projectile and projectile.delayedSpawn
    if not delayed or delayed.triggered then
        return false
    end

    local allowed = false
    if reason == "impact" then
        allowed = delayed.triggerOnImpact ~= false
    elseif reason == "timer" then
        allowed = delayed.triggerOnTimer ~= false
    elseif reason == "expire" then
        allowed = delayed.triggerOnExpire ~= false
    end
    if not allowed then return false end

    delayed.triggered = true

    local weaponConfig = delayed.weaponConfig
    if not weaponConfig then return false end

    local owner = delayed.owner or (projectile.projectile and projectile.projectile.owner) or projectile
    local world = system and system.world
    if not (world and physicsWorld) then return false end

    local pos = projectile.position or {}
    local spawnX = pos.x or 0
    local spawnY = pos.y or 0

    local baseDirX = (delayed.baseDirection and delayed.baseDirection.x) or 0
    local baseDirY = (delayed.baseDirection and delayed.baseDirection.y) or 0

    if delayed.useCurrentVelocity then
        if projectile.body and not projectile.body:isDestroyed() then
            local vx, vy = projectile.body:getLinearVelocity()
            baseDirX, baseDirY = vx, vy
        elseif projectile.velocity then
            baseDirX = projectile.velocity.x or baseDirX
            baseDirY = projectile.velocity.y or baseDirY
        end
    end

    if baseDirX == 0 and baseDirY == 0 then
        if projectile.rotation then
            local facing = projectile.rotation - math.pi * 0.5
            baseDirX, baseDirY = math.cos(facing), math.sin(facing)
        else
            baseDirY = -1
        end
    end

    local dirX, dirY = normalize(baseDirX, baseDirY)
    local baseAngle = atan2(dirY, dirX)
    if delayed.angleOffset then
        baseAngle = baseAngle + delayed.angleOffset
    end
    if delayed.baseJitter and delayed.baseJitter > 0 then
        baseAngle = baseAngle + randf(-delayed.baseJitter, delayed.baseJitter)
    end

    local countMin = delayed.countMin or delayed.count or 1
    local countMax = delayed.countMax or countMin
    if countMax < countMin then
        countMin, countMax = countMax, countMin
    end

    countMin = math.max(1, math.floor(countMin + 0.5))
    countMax = math.max(countMin, math.floor(countMax + 0.5))

    local count
    if countMin == countMax then
        count = countMin
    else
        count = math.random(countMin, countMax)
    end

    local spread = delayed.spread or 0

    if delayed.spawnOffset and delayed.spawnOffset ~= 0 then
        spawnX = spawnX + math.cos(baseAngle) * delayed.spawnOffset
        spawnY = spawnY + math.sin(baseAngle) * delayed.spawnOffset
    end

    local lateralJitter = delayed.lateralJitter or 0

    local speedMin = delayed.speedMultiplierMin
    local speedMax = delayed.speedMultiplierMax
    if speedMin == nil and speedMax == nil then
        speedMin, speedMax = 1, 1
    else
        speedMin = speedMin or speedMax or 1
        speedMax = speedMax or speedMin or 1
    end

    if speedMax < speedMin then
        speedMin, speedMax = speedMax, speedMin
    end

    local function pick_speed_multiplier()
        if not speedMin or not speedMax then
            return 1
        end
        if speedMin == speedMax then
            return speedMin
        end
        return randf(speedMin, speedMax)
    end

    if count <= 1 or spread <= 0 then
        local jitterX, jitterY = 0, 0
        if lateralJitter and lateralJitter > 0 then
            local jitter = randf(-lateralJitter, lateralJitter)
            jitterX = math.cos(baseAngle + math.pi * 0.5) * jitter
            jitterY = math.sin(baseAngle + math.pi * 0.5) * jitter
        end
        local speedMultiplier = pick_speed_multiplier()
        queue_spawn(system, owner, spawnX + jitterX, spawnY + jitterY, math.cos(baseAngle), math.sin(baseAngle), weaponConfig, speedMultiplier)
    else
        local halfSpread = spread * 0.5
        if delayed.randomizeSpread then
            for _ = 1, count do
                local dirAngle = baseAngle + randf(-halfSpread, halfSpread)
                local jitterX, jitterY = 0, 0
                if lateralJitter and lateralJitter > 0 then
                    local jitter = randf(-lateralJitter, lateralJitter)
                    jitterX = math.cos(dirAngle + math.pi * 0.5) * jitter
                    jitterY = math.sin(dirAngle + math.pi * 0.5) * jitter
                end
                local speedMultiplier = pick_speed_multiplier()
                queue_spawn(system, owner, spawnX + jitterX, spawnY + jitterY, math.cos(dirAngle), math.sin(dirAngle), weaponConfig, speedMultiplier)
            end
        else
            local step = spread / (count - 1)
            local startAngle = baseAngle - halfSpread
            for i = 0, count - 1 do
                local dirAngle = startAngle + step * i
                local jitterX, jitterY = 0, 0
                if lateralJitter and lateralJitter > 0 then
                    local jitter = randf(-lateralJitter, lateralJitter)
                    jitterX = math.cos(dirAngle + math.pi * 0.5) * jitter
                    jitterY = math.sin(dirAngle + math.pi * 0.5) * jitter
                end
                local speedMultiplier = pick_speed_multiplier()
                queue_spawn(system, owner, spawnX + jitterX, spawnY + jitterY, math.cos(dirAngle), math.sin(dirAngle), weaponConfig, speedMultiplier)
            end
        end
    end

    projectile.pendingDestroy = true
    return true
end

---@class ProjectileSystemContext
---@field physicsWorld love.World        # Physics world used for projectile bodies
---@field damageEntity fun(target:table, amount:number, source:table, context:table)|nil
---@field registerPhysicsCallback fun(self:table, phase:string, handler:function):fun()|nil

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity
    local registerPhysicsCallback = context.registerPhysicsCallback

    return tiny.system {
        filter = tiny.requireAll("projectile", "position"),

        init = function(self)
            self.processedCollisions = {}
            self.impactParticles = {}
            self.explosions = {}
            self.pendingSpawns = {}
            self._destroyQueue = {}

            -- Centralized collision callback for projectiles
            if not self.collisionSetup and type(registerPhysicsCallback) == "function" then
                local function handler(fixture1, fixture2, contact)
                    self:beginContact(fixture1, fixture2, contact)
                end
                self.unregisterPhysicsCallback = registerPhysicsCallback(context, "beginContact", handler)
                self.collisionSetup = true
            end
        end,

        detachPhysicsCallbacks = function(self)
            if self.unregisterPhysicsCallback then
                self.unregisterPhysicsCallback()
                self.unregisterPhysicsCallback = nil
            end
            self.collisionSetup = nil
        end,

        beginContact = function(self, fixture1, fixture2, contact)
            local data1 = fixture1:getUserData()
            local data2 = fixture2:getUserData()
            if not (data1 and data2) then return end

            local projectile, projectileData, target, targetData
            if data1.type == "projectile" then
                projectile, projectileData, target, targetData = data1.entity, data1, data2.entity, data2
            elseif data2.type == "projectile" then
                projectile, projectileData, target, targetData = data2.entity, data2, data1.entity, data1
            else
                return
            end
            if not (projectile and target) then return end

            -- Avoid double-processing this pair this frame
            local key = tostring(projectile) .. ":" .. tostring(target)
            if projectile and projectile.ignoreCollisions then
                return
            end

            if self.processedCollisions[key] then return end
            self.processedCollisions[key] = true

            local pos = projectile.position or {}
            local x, y = pos.x or 0, pos.y or 0

            local targetHasShield = Entities.hasActiveShield and Entities.hasActiveShield(target)

            -- Create impact particles only when the target lacks an active shield
            if not targetHasShield then
                local particles = create_impact_particles(x, y, projectile)
                for i = 1, #particles do
                    self.impactParticles[#self.impactParticles + 1] = particles[i]
                end
            end

            if projectile.homing and projectile.homing.explosion and not projectile.homing._explosionSpawned then
                spawn_explosion_effect(self.explosions, self.impactParticles, x, y, projectile, projectile.homing.explosion)
                apply_explosion_damage(self, damageEntity, x, y, projectile, projectile.homing.explosion)
            end

            -- Don't hit the shooter or same playerId
            if projectile.projectile and projectile.projectile.owner == target then return end
            local ownerPlayerId = projectile.projectile and projectile.projectile.ownerPlayerId
            if ownerPlayerId and target.playerId == ownerPlayerId then return end

            -- Deactivate and queue physics body/fixture destruction outside the callback
            local body = projectile.body
            if body and not body:isDestroyed() then
                self._destroyQueue[#self._destroyQueue + 1] = body
                projectile.body = nil
            end
            local fixture = projectile.fixture
            if fixture and not fixture:isDestroyed() then
                self._destroyQueue[#self._destroyQueue + 1] = fixture
                projectile.fixture = nil
            end
            projectile.pendingDestroy = true

            trigger_delayed_spawn(self, projectile, "impact", physicsWorld)

            -- Don't damage boundaries
            if targetData.type == "boundary" then return end

            -- Faction checks
            local shouldDamage = true
            if projectile.faction and target.faction and projectile.faction == target.faction then
                shouldDamage = false
            elseif projectile.playerProjectile and target.player then
                shouldDamage = false
            elseif projectile.enemyProjectile and target.enemy then
                shouldDamage = false
            end

            -- Apply damage
            if shouldDamage and damageEntity and target then
                local damageComponent = projectile.projectile or {}
                local damage = damageComponent.damage or 0
                if damage > 0 then
                    local damageType = damageComponent.damageType
                    local armorType = target.armorType
                    local multiplier = damage_util.resolve_multiplier(damageType, armorType)
                    damage = damage * multiplier
                    if damage > 0 then
                        local owner = damageComponent.owner or (damageComponent and damageComponent.owner)
                        damageEntity(target, damage, owner or projectile, { x = x, y = y })
                    end
                end
            end
        end,

        onAdd = function(self, entity)
            if not entity.body or not entity.drawable then return end

            -- Respect pre-made fixture (e.g., weapon_fire)
            if entity.fixture and not entity.fixture:isDestroyed() then
                local fixture = entity.fixture
                local data = fixture:getUserData() or {}
                data.type = data.type or "projectile"
                data.entity = entity
                fixture:setUserData(data)
                if not entity.shape then
                    entity.shape = fixture:getShape()
                end
                return
            end

            -- Create shape from drawable config
            local size = entity.drawable.size or 6
            local shape = create_projectile_shape(entity.drawable, size)
            local fixture = lp.newFixture(entity.body, shape)

            fixture:setUserData({ type = "projectile", entity = entity })

            entity.shape = shape
            entity.fixture = fixture
        end,

        update = function(self, dt)
            -- Periodic cleanup of processed collision pairs
            self.cleanupTimer = (self.cleanupTimer or 0) + dt
            if self.cleanupTimer > 1.0 then
                self.processedCollisions = {}
                self.cleanupTimer = 0
            end

            -- Flush physics destruction safely outside callbacks
            if #self._destroyQueue > 0 then
                for i = 1, #self._destroyQueue do
                    local o = self._destroyQueue[i]
                    if o and not o:isDestroyed() then
                        o:destroy()
                    end
                    self._destroyQueue[i] = nil
                end
            end

            -- Update impact particles
            for i = #self.impactParticles, 1, -1 do
                local p = self.impactParticles[i]
                p.lifetime = p.lifetime - dt
                if p.lifetime <= 0 then
                    self.impactParticles[i] = self.impactParticles[#self.impactParticles]
                    self.impactParticles[#self.impactParticles] = nil
                else
                    p.x = p.x + p.vx * dt
                    p.y = p.y + p.vy * dt
                    p.vx = p.vx * 0.92
                    p.vy = p.vy * 0.92 + 50 * dt

                    local lifeRatio = math.max(0, p.lifetime / p.maxLifetime)
                    local baseAlpha = p.baseAlpha or 0.9
                    if p.maxSize then
                        p.size = p.maxSize * (lifeRatio ^ 0.4)
                    end
                    p.color[4] = baseAlpha * lifeRatio
                end
            end

            local explosions = self.explosions
            if explosions and #explosions > 0 then
                for i = #explosions, 1, -1 do
                    local e = explosions[i]
                    e.lifetime = e.lifetime - dt
                    if e.lifetime <= 0 then
                        explosions[i] = explosions[#explosions]
                        explosions[#explosions] = nil
                    else
                        local lifeRatio = math.max(0, e.lifetime / (e.maxLifetime or 1))
                        local progress = 1 - lifeRatio
                        e.radius = e.startRadius + (e.maxRadius - e.startRadius) * progress
                        e.ringRadius = (e.ringRadiusScale or 1) * e.radius

                        if e.color then
                            e.color[4] = (e.baseAlpha or 1) * lifeRatio
                        end
                        if e.ringColor then
                            e.ringColor[4] = (e.baseRingAlpha or 1) * lifeRatio
                        end
                    end
                end
            end

            -- Update projectile lifetimes and delayed spawns
            for entity in pairs(self.__pool) do
                if entity.projectile and entity.projectile.lifetime then
                    entity.projectile.lifetime = entity.projectile.lifetime - dt
                    if entity.projectile.lifetime <= 0 then
                        entity.pendingDestroy = true
                        trigger_delayed_spawn(self, entity, "expire", physicsWorld)
                    end
                end

                if entity.delayedSpawn then
                    local delayed = entity.delayedSpawn
                    if delayed.timer then
                        delayed.timer = delayed.timer - dt
                        if delayed.timer <= 0 then
                            delayed.timer = nil
                            trigger_delayed_spawn(self, entity, "timer", physicsWorld)
                        end
                    end
                end
            end

            -- Spawn queued projectiles
            local pending = self.pendingSpawns
            if #pending > 0 then
                for i = 1, #pending do
                    local entry = pending[i]
                    local dirX = entry.dirX
                    local dirY = entry.dirY
                    if entry.speedMultiplier and entry.speedMultiplier ~= 1 then
                        dirX = dirX * entry.speedMultiplier
                        dirY = dirY * entry.speedMultiplier
                    end
                    ProjectileFactory.spawn(self.world, physicsWorld, entry.owner, entry.x, entry.y, dirX, dirY, entry.weapon)
                    pending[i] = nil
                end
            end
        end,

        process = function(self, entity, dt)
            local body = entity.body
            if not body or body:isDestroyed() then return end

            if entity.homing then
                apply_homing(entity, dt, damageEntity, self)
            end

            if entity.gravityWell then
                apply_gravity_well(self, entity, body)
            end

            -- Check for temporal field effects
            local insideTemporalField = false
            local x, y = body:getPosition()
            local world = self.world
            if world and world.entities then
                local entities = world.entities
                for i = 1, #entities do
                    local fieldEntity = entities[i]
                    local field = fieldEntity and fieldEntity._temporalField
                    if field and field.active and field.radius and field.radius > 0 then
                        local dx = x - (field.x or 0)
                        local dy = y - (field.y or 0)
                        local distSq = dx * dx + dy * dy
                        local radius = field.radius or 0
                        local radiusSq = radius * radius

                        if distSq <= radiusSq then
                            insideTemporalField = true
                            local slowFactor = field.slowFactor or 0.35
                            slowFactor = math.max(0, math.min(slowFactor, 1))

                            if not entity._originalVelocity then
                                local ovx, ovy = body:getLinearVelocity()
                                entity._originalVelocity = { x = ovx, y = ovy }
                            end

                            local original = entity._originalVelocity
                            if original then
                                body:setLinearVelocity(original.x * slowFactor, original.y * slowFactor)
                            end

                            break
                        end
                    end
                end
            end

            if not insideTemporalField then
                if entity._inTemporalField and entity._originalVelocity then
                    body:setLinearVelocity(entity._originalVelocity.x, entity._originalVelocity.y)
                end
                entity._originalVelocity = nil
            end

            entity._inTemporalField = insideTemporalField

            -- Sync position
            local pos = entity.position
            pos.x, pos.y = x, y

            local trail = entity.projectileTrail
            if trail then
                local points = trail.points or {}
                trail.points = points
                local segment = trail.segment or 6
                local maxPoints = trail.maxPoints or 24
                local lifetime = trail.pointLifetime or 0.45
                local segSq = segment * segment
                local last = points[#points]
                if not last or ((x - last.x) * (x - last.x) + (y - last.y) * (y - last.y)) >= segSq then
                    points[#points + 1] = {
                        x = x,
                        y = y,
                        life = lifetime,
                        maxLife = lifetime,
                    }
                end

                for i = #points, 1, -1 do
                    local p = points[i]
                    p.life = (p.life or lifetime) - dt
                    if p.life <= 0 then
                        table.remove(points, i)
                    end
                end

                while #points > maxPoints do
                    table.remove(points, 1)
                end
            end

            -- Sync velocity
            if entity.velocity then
                local vx, vy = body:getLinearVelocity()
                entity.velocity.x, entity.velocity.y = vx, vy
            end

            -- Sync rotation
            if entity.frozenRotation then
                entity.rotation = entity.frozenRotation
            else
                entity.rotation = body:getAngle()
            end
        end,

        onRemove = function(self, entity)
            if entity.body and not entity.body:isDestroyed() then
                entity.body:destroy()
                entity.body = nil
            end
            if entity.fixture and not entity.fixture:isDestroyed() then
                entity.fixture:destroy()
                entity.fixture = nil
            end
            for i = #self.impactParticles, 1, -1 do
                if self.impactParticles[i].source == entity then
                    self.impactParticles[i] = self.impactParticles[#self.impactParticles]
                    self.impactParticles[#self.impactParticles] = nil
                end
            end
        end,
    }
end
