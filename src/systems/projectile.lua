local tiny = require("libs.tiny")
local love = love
local lg, lp = love.graphics, love.physics
local damage_util = require("src.util.damage")
local ProjectileFactory = require("src.entities.projectile_factory")

-- Lua compat helpers
local unpack = table.unpack or unpack
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local SQRT = math.sqrt
local EPS = 1e-8

local function normalize(x, y)
    x, y = x or 0, y or 0
    local lenSq = x * x + y * y
    if lenSq <= EPS then
        return 0, -1
    end
    local inv = 1 / SQRT(lenSq)
    return x * inv, y * inv
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

            -- Create impact particles (before early returns so visual feedback always occurs)
            local pos = projectile.position or {}
            local x, y = pos.x or 0, pos.y or 0
            
            local particles = create_impact_particles(x, y, projectile)
            for i = 1, #particles do
                self.impactParticles[#self.impactParticles + 1] = particles[i]
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

            -- Sync position
            local x, y = body:getPosition()
            local pos = entity.position
            pos.x, pos.y = x, y

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
