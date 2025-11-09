local tiny = require("libs.tiny")
local love = love

local function clamp01(value)
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function scale_color(base, factor, alpha)
    base = base or { 1, 0.8, 0.3 }
    return {
        clamp01((base[1] or 1) * factor),
        clamp01((base[2] or 1) * factor),
        clamp01((base[3] or 1) * factor),
        alpha,
    }
end

local function build_impact_colors(drawable)
    local base = drawable and (drawable.highlightColor or drawable.coreColor or drawable.color)
    return {
        scale_color(base, 1.5, 1.0),
        scale_color(base, 1.25, 0.9),
        scale_color(base, 1.0, 0.7),
        scale_color(base, 0.8, 0.5),
        scale_color(base, 0.6, 0.3),
        scale_color(base, 0.4, 0.1),
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

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity
    local particleSystem = context.particleSystem
    
    return tiny.system {
        filter = tiny.requireAll("projectile", "position"),
        
        init = function(self)
            self.projectiles = {}
            self.processedCollisions = {}
            
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
            
            -- Don't hit boundaries
            if targetData.type == "boundary" then
                -- Create enhanced impact particles at boundary collision
                if particleSystem and projectile.position then
                    local colors = build_impact_colors(projectile.drawable)
                    local vx, vy = 0, 0
                    if projectile.velocity then
                        vx, vy = projectile.velocity.x, projectile.velocity.y
                    end
                    
                    particleSystem:createImpactEffect(
                        projectile.position.x,
                        projectile.position.y,
                        "boundary",
                        {
                            colors = colors,
                            particleCount = 25,
                            speed = { min = 80, max = 200 },
                            spread = math.pi,
                            size = { min = 2, max = 8 },
                            lifetime = { min = 0.3, max = 1.2 },
                            fadeTime = 0.8,
                            sparkCount = 15,
                            sparkSpeed = { min = 120, max = 300 },
                            sparkLifetime = { min = 0.2, max = 0.6 },
                            velocityInherit = 0.3,
                            initialVelocity = { x = vx, y = vy }
                        }
                    )
                end
                projectile.pendingDestroy = true
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
                local damage = projectile.projectile.damage or 0
                if damage > 0 then
                    damageEntity(target, damage)
                end
            end
            
            -- Create enhanced impact particles on hit
            if particleSystem and projectile.position then
                local effectType = shouldDamage and "damage" or "hit"
                local colors = build_impact_colors(projectile.drawable)
                local vx, vy = 0, 0
                if projectile.velocity then
                    vx, vy = projectile.velocity.x, projectile.velocity.y
                end
                
                local particleCount = shouldDamage and 35 or 20
                local sparkCount = shouldDamage and 20 or 12
                
                particleSystem:createImpactEffect(
                    projectile.position.x,
                    projectile.position.y,
                    effectType,
                    {
                        colors = colors,
                        particleCount = particleCount,
                        speed = { min = 60, max = 180 },
                        spread = math.pi * 1.2,
                        size = { min = 1.5, max = 6 },
                        lifetime = { min = 0.4, max = 1.5 },
                        fadeTime = 0.9,
                        sparkCount = sparkCount,
                        sparkSpeed = { min = 100, max = 250 },
                        sparkLifetime = { min = 0.15, max = 0.5 },
                        burstIntensity = shouldDamage and 1.5 or 1.0,
                        velocityInherit = 0.4,
                        initialVelocity = { x = vx, y = vy },
                        glowRadius = shouldDamage and 15 or 10,
                        shockwaveSize = shouldDamage and 25 or 18
                    }
                )
            end
            
            -- Destroy projectile on hit
            projectile.pendingDestroy = true
        end,
        
        onAdd = function(self, entity)
            self.projectiles[entity] = true
            
            -- Create appropriate physics shape based on drawable configuration
            if entity.body and entity.drawable then
                local size = entity.drawable.size or 6
                local shape = create_projectile_shape(entity.drawable, size)
                local fixture = love.physics.newFixture(entity.body, shape)
                
                fixture:setUserData({
                    type = "projectile",
                    entity = entity,
                })
                
                entity.shape = shape
                entity.fixture = fixture
            end
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
            
            -- Update projectile lifetimes
            for entity in pairs(self.__pool) do
                if entity.projectile and entity.projectile.lifetime then
                    entity.projectile.lifetime = entity.projectile.lifetime - dt
                    
                    -- Remove expired projectiles
                    if entity.projectile.lifetime <= 0 then
                        entity.pendingDestroy = true
                    end
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
            
            -- Sync rotation
            entity.rotation = body:getAngle()
        end,
        
        onRemove = function(self, entity)
            self.projectiles[entity] = nil
            
            -- Clean up physics body
            if entity.body and not entity.body:isDestroyed() then
                entity.body:destroy()
            end
        end,
    }
end
