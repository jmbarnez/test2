---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")

local function safe_call(callback, entity, context)
    if type(callback) ~= "function" then
        return
    end

    local ok, err = pcall(callback, entity, context)
    if not ok then
        print(string.format("[destruction] onDestroyed failed for entity: %s", tostring(err)))
    end
end

return function(context)
    context = context or {}

    local destruction_system = tiny.system {
        filter = tiny.requireAll("pendingDestroy"),
        process = function(self, entity, dt)
            safe_call(entity.onDestroyed, entity, context)

            local body = entity.body
            if body and not body:isDestroyed() then
                body:destroy()
            end
            entity.body = nil

            if entity.fixtures then
                for i = 1, #entity.fixtures do
                    entity.fixtures[i] = nil
                end
            end
            entity.fixture = nil
            entity.fixtures = nil
            entity.shape = nil
            entity.shapes = nil

            entity.pendingDestroy = nil
            entity.destroyed = true

            self.world:remove(entity)
        end,
    }

    return destruction_system
end
