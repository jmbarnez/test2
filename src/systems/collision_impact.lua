--- Collision Impact System
-- Handles shield impact visual effects when entities collide
-- Listens to postSolve physics callbacks and triggers shield pulses

local Entities = require("src.states.gameplay.entities")

---@class CollisionImpactSystemContext
---@field registerPhysicsCallback fun(self:table, phase:string, handler:function):fun()|nil

return function(context)
    context = context or {}
    local registerPhysicsCallback = context.registerPhysicsCallback

    -- Simple system with no entity filter - just handles physics callbacks
    return {
        init = function(self)
            self.processedCollisions = {}
            
            -- Register postSolve callback to detect collision impulses
            if not self.collisionSetup and type(registerPhysicsCallback) == "function" then
                local function handler(fixture1, fixture2, contact, normalImpulse1, tangentImpulse1, normalImpulse2, tangentImpulse2)
                    self:handleCollision(fixture1, fixture2, contact, normalImpulse1, tangentImpulse1)
                end
                self.unregisterPhysicsCallback = registerPhysicsCallback(context, "postSolve", handler)
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

        handleCollision = function(self, fixture1, fixture2, contact, normalImpulse, tangentImpulse)
            local data1 = fixture1:getUserData()
            local data2 = fixture2:getUserData()
            
            if not (data1 and data2) then
                return
            end

            local entity1 = data1.entity
            local entity2 = data2.entity

            if not (entity1 and entity2) then
                return
            end

            -- Skip projectiles and boundaries - they have their own collision handling
            if data1.type == "projectile" or data2.type == "projectile" then
                return
            end
            if data1.type == "boundary" or data2.type == "boundary" then
                return
            end

            -- Avoid double-processing this collision pair this frame
            local key1 = tostring(entity1) .. ":" .. tostring(entity2)
            local key2 = tostring(entity2) .. ":" .. tostring(entity1)
            if self.processedCollisions[key1] or self.processedCollisions[key2] then
                return
            end
            self.processedCollisions[key1] = true

            -- Calculate total impact force
            local totalImpulse = math.abs(normalImpulse or 0) + math.abs(tangentImpulse or 0)
            
            -- Only show impact for significant collisions (tune this threshold as needed)
            if totalImpulse < 5 then
                return
            end

            -- Get contact point for impact position
            local cx, cy = contact:getPositions()
            local impactPosition = nil
            if cx and cy then
                impactPosition = { x = cx, y = cy }
            end

            -- Try to show impact on both entities if they have shields
            if entity1 and entity1.shield then
                Entities.pushCollisionImpact(entity1, totalImpulse, impactPosition)
            end

            if entity2 and entity2.shield then
                Entities.pushCollisionImpact(entity2, totalImpulse, impactPosition)
            end
        end,

        update = function(self, dt)
            -- Periodic cleanup of processed collision pairs
            self.cleanupTimer = (self.cleanupTimer or 0) + dt
            if self.cleanupTimer > 0.5 then
                self.processedCollisions = {}
                self.cleanupTimer = 0
            end
        end,
    }
end
