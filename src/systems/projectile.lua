local tiny = require("libs.tiny")
local love = love
local damage_util = require("src.util.damage")
local ProjectileFactory = require("src.entities.projectile_factory")

local SQRT = math.sqrt

local function normalize(x, y)
    local lenSq = (x or 0) * (x or 0) + (y or 0) * (y or 0)
    if lenSq <= 1e-8 then
        return 0, -1
    end
    local len = SQRT(lenSq)
    return (x or 0) / len, (y or 0) / len
end

local function queue_spawn(system, owner, x, y, dirX, dirY, weaponConfig)
    if not system then
        return
    end

    local pending = system.pendingSpawns
    if not pending then
        pending = {}
        system.pendingSpawns = pending
    end

    pending[#pending + 1] = {
        owner = owner,
        x = x,
        y = y,
        dirX = dirX,
        dirY = dirY,
        weapon = weaponConfig,
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
        return love.physics.newRectangleShape(length, width)
    elseif shape == "polygon" and drawable.vertices then
        return love.physics.newPolygonShape(unpack(drawable.vertices))
    else
        -- Default to circle for orb and other shapes
        local radius = (drawable.radius or size) * 0.5
        return love.physics.newCircleShape(radius)
    end
end

local function create_impact_particles(x, y, projectile, target)
    local particles = {}
    local numParticles = math.random(8, 16)
    local baseColor = projectile.drawable and projectile.drawable.color or {0.2, 0.8, 1.0}
    
    -- Desaturate the base color for more muted particles
    local desaturatedColor = {
        baseColor[1] * 0.7,
        baseColor[2] * 0.7,
        baseColor[3] * 0.7
    }
    
    -- Calculate impact direction based on projectile velocity
    local impactAngle = 0
    if projectile.velocity then
        impactAngle = math.atan2(projectile.velocity.y, projectile.velocity.x)
    end
    
    for i = 1, numParticles do
        -- Create cone of particles spreading from impact direction
        local spreadAngle = impactAngle + math.pi + (math.random() - 0.5) * math.pi * 0.8
        local speed = math.random(80, 200)
        local lifetime = math.random(0.22, 0.45)
        local size = 0.9 + math.random() * 1.4
        local tintShift = 0.2 + math.random() * 0.3

        particles[i] = {
            x = x + math.random(-2, 2),
            y = y + math.random(-2, 2),
            vx = math.cos(spreadAngle) * speed,
            vy = math.sin(spreadAngle) * speed,
            size = size,
            maxSize = size,
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

    if not allowed then
        return false
    end

    delayed.triggered = true

    local weaponConfig = delayed.weaponConfig
    if not weaponConfig then
        return false
    end

    local owner = delayed.owner or (projectile.projectile and projectile.projectile.owner) or projectile
    local world = system and system.world
    if not (world and physicsWorld) then
        return false
    end

    local spawnX = projectile.position.x or 0
    local spawnY = projectile.position.y or 0

    local baseDirX = delayed.baseDirection and delayed.baseDirection.x or 0
    local baseDirY = delayed.baseDirection and delayed.baseDirection.y or 0

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
            baseDirX = math.cos(facing)
            baseDirY = math.sin(facing)
        else
            baseDirY = -1
        end
    end

    local dirX, dirY = normalize(baseDirX, baseDirY)
    local baseAngle = math.atan2(dirY, dirX)
    if delayed.angleOffset then
        baseAngle = baseAngle + delayed.angleOffset
    end

    local count = math.max(1, delayed.count or 1)
    local spread = delayed.spread or 0

    if delayed.spawnOffset and delayed.spawnOffset ~= 0 then
        spawnX = spawnX + math.cos(baseAngle) * delayed.spawnOffset
        spawnY = spawnY + math.sin(baseAngle) * delayed.spawnOffset
    end

    if count == 1 then
        local dirAngle = baseAngle
        local burstDirX = math.cos(dirAngle)
        local burstDirY = math.sin(dirAngle)
        queue_spawn(system, owner, spawnX, spawnY, burstDirX, burstDirY, weaponConfig)
    else
        local step = spread / (count - 1)
        local startAngle = baseAngle - spread * 0.5
        for i = 0, count - 1 do
            local dirAngle = startAngle + step * i
            local burstDirX = math.cos(dirAngle)
            local burstDirY = math.sin(dirAngle)
            queue_spawn(system, owner, spawnX, spawnY, burstDirX, burstDirY, weaponConfig)
        end
    end

    projectile.pendingDestroy = true
    return true
end

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity
    
    return tiny.system {
        filter = tiny.requireAll("projectile", "position"),
        
        init = function(self)
            self.processedCollisions = {}
            self.impactParticles = {}
            self.pendingSpawns = {}
            
            -- Setup collision callbacks for projectiles
            if physicsWorld and not self.collisionSetup then
                physicsWorld:setCallbacks(
                    function(fixture1, fixture2, contact)
                        self:beginContact(fixture1, fixture2, contact)
                    end,
                    nil, nil, nil
                )
                self.collisionSetup = true
            end
        end,
        
        beginContact = function(self, fixture1, fixture2, contact)
            local data1 = fixture1:getUserData()
            local data2 = fixture2:getUserData()
            
            if not (data1 and data2) then
                return
            end
            
            local projectile, target
            local projectileData, targetData
            
            if data1.type == "projectile" then
                projectile = data1.entity
                projectileData = data1
                target = data2.entity
                targetData = data2
            elseif data2.type == "projectile" then
                projectile = data2.entity
                projectileData = data2
                target = data1.entity
                targetData = data1
            end
            
            if not (projectile and target) then
                return
            end
            
            -- Check if this collision was already processed
            local key = tostring(projectile) .. ":" .. tostring(target)
            if self.processedCollisions[key] then
                return
            end
            self.processedCollisions[key] = true
            
            -- Don't hit the shooter
            if projectile.projectile.owner == target then
                return
            end

            local ownerPlayerId = projectile.projectile.ownerPlayerId
            if ownerPlayerId and target.playerId == ownerPlayerId then
                return
            end
            
            -- Create impact particles at collision point
            local x, y = projectile.position.x, projectile.position.y
            local particles = create_impact_particles(x, y, projectile, target)
            for i = 1, #particles do
                table.insert(self.impactParticles, particles[i])
            end
            
            if projectile.body and not projectile.body:isDestroyed() then
                projectile.body:destroy()
                projectile.body = nil
            end
            projectile.pendingDestroy = true

            trigger_delayed_spawn(self, projectile, "impact", physicsWorld)

            -- Don't hit boundaries
            if targetData.type == "boundary" then
                return
            end
            
            -- Faction check
            local shouldDamage = true
            if target then
                if projectile.faction and target.faction and projectile.faction == target.faction then
                    shouldDamage = false
                elseif projectile.playerProjectile and target.player then
                    shouldDamage = false
                elseif projectile.enemyProjectile and target.enemy then
                    shouldDamage = false
                end
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
                        local owner = damageComponent.owner or projectile.projectile.owner
                        damageEntity(target, damage, owner or projectile, {
                            x = x,
                            y = y,
                        })
                    end
                end
            end
            
            -- Destroy projectile on hit
            projectile.pendingDestroy = true
        end,
        
        onAdd = function(self, entity)
            if not entity.body or not entity.drawable then
                return
            end

            -- Respect fixtures created during instantiation (weapon_fire)
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

            -- Create appropriate physics shape based on drawable configuration
            local size = entity.drawable.size or 6
            local shape = create_projectile_shape(entity.drawable, size)
            local fixture = love.physics.newFixture(entity.body, shape)

            fixture:setUserData({
                type = "projectile",
                entity = entity,
            })

            entity.shape = shape
            entity.fixture = fixture
        end,
        
        update = function(self, dt)
            -- Clean up processed collisions table periodically
            if not self.cleanupTimer then
                self.cleanupTimer = 0
            end
            self.cleanupTimer = self.cleanupTimer + dt
            if self.cleanupTimer > 1.0 then
                self.processedCollisions = {}
                self.cleanupTimer = 0
            end
            
            -- Update impact particles
            for i = #self.impactParticles, 1, -1 do
                local particle = self.impactParticles[i]
                particle.lifetime = particle.lifetime - dt
                
                if particle.lifetime <= 0 then
                    table.remove(self.impactParticles, i)
                else
                    -- Update particle physics with gravity and friction
                    particle.x = particle.x + particle.vx * dt
                    particle.y = particle.y + particle.vy * dt
                    particle.vx = particle.vx * 0.92  -- friction
                    particle.vy = particle.vy * 0.92 + 50 * dt  -- slight gravity

                    local lifeRatio = math.max(0, particle.lifetime / particle.maxLifetime)
                    local baseAlpha = particle.baseAlpha or 0.9
                    if particle.maxSize then
                        particle.size = particle.maxSize * (lifeRatio ^ 0.4)
                    end
                    particle.color[4] = baseAlpha * lifeRatio
                end
            end
            
            -- Update projectile lifetimes
            for entity in pairs(self.__pool) do
                if entity.projectile and entity.projectile.lifetime then
                    entity.projectile.lifetime = entity.projectile.lifetime - dt

                    -- Remove expired projectiles
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

            local pending = self.pendingSpawns
            if pending and #pending > 0 then
                for i = 1, #pending do
                    local entry = pending[i]
                    ProjectileFactory.spawn(self.world, physicsWorld, entry.owner, entry.x, entry.y, entry.dirX, entry.dirY, entry.weapon)
                    pending[i] = nil
                end
            end
        end,
        
        process = function(self, entity, dt)
            local body = entity.body
            if not body or body:isDestroyed() then
                return
            end
            
            -- Sync position with physics body
            local x, y = body:getPosition()
            entity.position.x = x
            entity.position.y = y
            
            if entity.velocity then
                local vx, vy = body:getLinearVelocity()
                entity.velocity.x = vx
                entity.velocity.y = vy
            end
            
            -- Use frozen rotation if available, otherwise sync with physics body
            if entity.frozenRotation then
                entity.rotation = entity.frozenRotation
            else
                entity.rotation = body:getAngle()
            end
        end,
        
        onRemove = function(self, entity)
            -- Clean up physics body
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
                    table.remove(self.impactParticles, i)
                end
            end
        end,
        
        draw = function(self)
            -- Render impact particles with more saturated colors
            love.graphics.push("all")
            love.graphics.setBlendMode("add")
            
            for i = 1, #self.impactParticles do
                local particle = self.impactParticles[i]
                local alpha = particle.color[4]
                if alpha and alpha > 0 and particle.size and particle.size > 0 then
                    love.graphics.setColor(particle.color)
                    love.graphics.setPointSize(math.max(1, particle.size))
                    love.graphics.points(particle.x, particle.y)
                end
            end

            love.graphics.pop()
        end,
    }
end
