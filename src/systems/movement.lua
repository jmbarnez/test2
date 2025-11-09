-- movement.lua
-- Handles entity movement and physics updates
-- Syncs physics body states with entity position/rotation components
-- Part of the ECS architecture using tiny-ecs

---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")

return function(context)
    context = context or {}
    local maxLerp = context.networkLerp or 12
    local maxSnapDistanceSq = (context.snapDistance or 400) * (context.snapDistance or 400)

    local function interpolate_entity(entity, dt)
        local net = entity.networkState
        if not net or not net.initialized then
            return
        end

        local pos = entity.position
        if not pos then
            return
        end

        local dx = (net.targetX or pos.x) - pos.x
        local dy = (net.targetY or pos.y) - pos.y
        local distSq = dx * dx + dy * dy

        if distSq > maxSnapDistanceSq then
            pos.x = net.targetX
            pos.y = net.targetY
            if entity.body and not entity.body:isDestroyed() then
                entity.body:setPosition(pos.x, pos.y)
            end
        else
            local rate = math.min(maxLerp * dt, 1)
            pos.x = pos.x + dx * rate
            pos.y = pos.y + dy * rate
            if entity.body and not entity.body:isDestroyed() then
                entity.body:setPosition(pos.x, pos.y)
            end
        end

        if entity.syncBodyAngle ~= false then
            local current = entity.rotation or 0
            local target = net.targetRotation or current

            local delta = (target - current + math.pi) % (math.pi * 2) - math.pi
            local angleStep = delta * math.min(maxLerp * dt, 1)
            entity.rotation = current + angleStep

            if entity.body and not entity.body:isDestroyed() then
                entity.body:setAngle(entity.rotation)
            end
        end
    end

    return tiny.system {
        filter = tiny.requireAll("body", "position"),
        update = function(self, dt)
            local entities = self.world and self.world.entities or {}
            for i = 1, #entities do
                local entity = entities[i]
                if self.filter(entity) then
                    interpolate_entity(entity, dt)

                    -- Only sync from physics body if NOT a remote networked entity
                    -- Remote entities are controlled by network interpolation
                    local isRemoteNetworked = entity.networkState and entity.networkState.initialized

                    if not isRemoteNetworked then
                        local body = entity.body
                        if body and not body:isDestroyed() then
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
                    end
                end
            end
        end,
    }
end
