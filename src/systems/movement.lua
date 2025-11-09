-- movement.lua
-- Handles entity movement and physics updates
-- Syncs physics body states with entity position/rotation components
-- Part of the ECS architecture using tiny-ecs

---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")

return function(context)
    context = context or {}
    local maxLerp = context.networkLerp or 12
    local maxSnapDistanceSq = (context.snapDistance or 400) ^ 2
    local pi = math.pi
    local pi2 = pi * 2

    local function interpolate_entity(entity, dt)
        local net = entity.networkState
        if not (net and net.initialized) then
            return
        end

        local pos = entity.position
        if not pos then
            return
        end

        -- Interpolate toward server snapshot position
        local targetX = net.targetX or pos.x
        local targetY = net.targetY or pos.y
        local dx = targetX - pos.x
        local dy = targetY - pos.y
        local distSq = dx * dx + dy * dy

        if distSq > maxSnapDistanceSq then
            -- Too far off, snap immediately
            pos.x = targetX
            pos.y = targetY
        elseif distSq > 1e-6 then
            -- Adaptive correction strength based on distance
            -- Stronger correction for larger offsets (collision recovery)
            local distance = math.sqrt(distSq)
            local baseLambda = maxLerp * 2
            
            -- Increase correction strength for distances > 50 pixels (likely collision aftermath)
            local adaptiveLambda = distance > 50 and baseLambda * 3 or baseLambda
            
            local blendFactor = 1 - math.exp(-adaptiveLambda * dt)
            pos.x = pos.x + dx * blendFactor
            pos.y = pos.y + dy * blendFactor
        end

        -- Update velocity component from network for effects
        if entity.velocity then
            entity.velocity.x = net.targetVX or 0
            entity.velocity.y = net.targetVY or 0
        end

        -- Rotation interpolation
        if entity.syncBodyAngle ~= false then
            local current = entity.rotation or 0
            local target = net.targetRotation or current
            local delta = (target - current + pi) % pi2 - pi
            
            if math.abs(delta) > 1e-4 then
                local angleStep = delta * math.min(maxLerp * dt, 1)
                entity.rotation = current + angleStep
            end
        end
    end

    return tiny.processingSystem {
        filter = tiny.requireAll("position"),
        process = function(self, entity, dt)
            local body = entity.body
            if not (body and not body:isDestroyed()) then
                return
            end

            -- Remote networked entities: apply network corrections to physics
            if entity.networkState and entity.networkState.initialized then
                interpolate_entity(entity, dt)
                
                -- Apply strong corrections to physics body for network sync
                if entity.networkCorrected then
                    local currentX, currentY = body:getPosition()
                    local targetX, targetY = entity.position.x, entity.position.y
                    
                    local dx = targetX - currentX
                    local dy = targetY - currentY
                    local distSq = dx * dx + dy * dy
                    
                    -- Strong correction for network-controlled entities
                    if distSq > 25 then -- 5 pixel threshold
                        -- Apply correction force proportional to distance
                        local correctionForce = 2000 -- Strong correction
                        body:applyForce(dx * correctionForce, dy * correctionForce)
                        
                        -- Also apply velocity correction
                        local vx, vy = body:getLinearVelocity()
                        local targetVX = entity.velocity and entity.velocity.x or 0
                        local targetVY = entity.velocity and entity.velocity.y or 0
                        body:setLinearVelocity(
                            vx + (targetVX - vx) * 0.5,
                            vy + (targetVY - vy) * 0.5
                        )
                    end
                    
                    -- Let blueprint angular damping handle rotation naturally
                    -- Don't force rotation corrections to preserve single-player behavior
                end
                
                -- Update entity position from physics (after corrections)
                local x, y = body:getPosition()
                entity.position.x = x
                entity.position.y = y
                
                if entity.velocity then
                    local vx, vy = body:getLinearVelocity()
                    entity.velocity.x = vx
                    entity.velocity.y = vy
                end
                
                if entity.syncBodyAngle ~= false then
                    entity.rotation = body:getAngle()
                end
                return
            end

            -- Local entities: normal physics sync
            local x, y = body:getPosition()
            entity.position.x = x
            entity.position.y = y

            if entity.velocity then
                local vx, vy = body:getLinearVelocity()
                entity.velocity.x = vx
                entity.velocity.y = vy
            end

            if entity.syncBodyAngle ~= false then
                entity.rotation = body:getAngle()
            end
        end
    }
end
