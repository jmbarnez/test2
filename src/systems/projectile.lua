local tiny = require("libs.tiny")
local love = love

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity
    
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
            
            -- Destroy projectile on hit
            projectile.pendingDestroy = true
        end,
        
        onAdd = function(self, entity)
            self.projectiles[entity] = true
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
