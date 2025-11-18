---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")

---@class DestructionSystemContext
---@field state table|nil   # Optional gameplay state, forwarded to onDestroyed handlers

local function safe_call(callback, entity, context)
    if type(callback) ~= "function" then
        return
    end

    local ok, err = pcall(callback, entity, context)
    if not ok then
        print(string.format("[destruction] onDestroyed failed for entity: %s", tostring(err)))
    end
end

---@param context DestructionSystemContext|nil
---@return table
return function(context)
    context = context or {}

    local destruction_system = tiny.system {
        filter = tiny.requireAll("pendingDestroy"),

        init = function(self)
            self._destroyQueue = {}
        end,

        postProcess = function(self)
            local queue = self._destroyQueue
            if not queue or #queue == 0 then
                return
            end

            for i = 1, #queue do
                local body = queue[i]
                if body and not body:isDestroyed() then
                    body:destroy()
                end
                queue[i] = nil
            end
        end,

        process = function(self, entity, dt)
            safe_call(entity.onDestroyed, entity, context)

            -- Safely destroy physics body with error handling
            local body = entity.body
            if body then
                entity.body = nil

                if not body:isDestroyed() then
                    local queue = self._destroyQueue
                    if queue then
                        queue[#queue + 1] = body
                    else
                        self._destroyQueue = { body }
                    end
                end
            end

            -- Clear physics references
            if entity.fixtures then
                for i = 1, #entity.fixtures do
                    entity.fixtures[i] = nil
                end
            end
            entity.fixture = nil
            entity.fixtures = nil
            entity.shape = nil
            entity.shapes = nil

            -- Clear large nested data structures to help GC
            -- This helps with blueprint tables that may contain large nested configs
            if entity.drawable and type(entity.drawable) == "table" then
                if entity.drawable.layers then
                    entity.drawable.layers = nil
                end
                if entity.drawable.vertices then
                    entity.drawable.vertices = nil
                end
            end
            
            if entity.weapon and type(entity.weapon) == "table" then
                if entity.weapon.projectileBlueprint then
                    entity.weapon.projectileBlueprint = nil
                end
                if entity.weapon.mounts then
                    entity.weapon.mounts = nil
                end
            end
            
            if entity.ai and type(entity.ai) == "table" then
                if entity.ai.behaviorTree then
                    entity.ai.behaviorTree = nil
                end
            end

            entity.pendingDestroy = nil
            entity.destroyed = true

            self.world:remove(entity)
        end,
    }

    return destruction_system
end
