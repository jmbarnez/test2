---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")

return function(context)
    return tiny.system {
        filter = function(entity)
            return entity.wrap and entity.position ~= nil
        end,
        process = function(_, entity)
            local bounds = context.worldBounds
            if not bounds then
                return
            end
            local minX = bounds.x
            local minY = bounds.y
            local maxX = bounds.x + bounds.width
            local maxY = bounds.y + bounds.height

            if entity.position.x < minX then
                entity.position.x = minX
                if entity.velocity then
                    entity.velocity.x = math.max(0, entity.velocity.x)
                end
            elseif entity.position.x > maxX then
                entity.position.x = maxX
                if entity.velocity then
                    entity.velocity.x = math.min(0, entity.velocity.x)
                end
            end

            if entity.position.y < minY then
                entity.position.y = minY
                if entity.velocity then
                    entity.velocity.y = math.max(0, entity.velocity.y)
                end
            elseif entity.position.y > maxY then
                entity.position.y = maxY
                if entity.velocity then
                    entity.velocity.y = math.min(0, entity.velocity.y)
                end
            end
        end,
    }
end
