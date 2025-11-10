-- movement.lua
-- Handles entity movement and physics updates
-- Syncs physics body states with entity position/rotation components
-- Part of the ECS architecture using tiny-ecs

---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")

return function()
    return tiny.processingSystem {
        filter = tiny.requireAll("position"),
        process = function(_, entity)
            local body = entity.body
            if not (body and not body:isDestroyed()) then
                return
            end

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
