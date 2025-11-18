local tiny = require("libs.tiny")
local SpatialGrid = require("src.util.spatial_grid")
local Culling = require("src.util.culling")
local vector = require("src.util.vector")

local DEFAULT_RADIUS = 16

local function compute_entity_radius(entity)
    if not entity then
        return 0
    end

    if type(entity.spatialRadius) == "number" and entity.spatialRadius >= 0 then
        return entity.spatialRadius
    end

    local collider = entity.collider
    if collider then
        if type(collider.radius) == "number" and collider.radius > 0 then
            return collider.radius
        end
        if type(collider.width) == "number" and type(collider.height) == "number" then
            return math.max(collider.width, collider.height) * 0.5
        end
        if type(collider.size) == "number" and collider.size > 0 then
            return collider.size * 0.5
        end
    end

    local colliders = entity.colliders
    if type(colliders) == "table" then
        local maxRadius = 0
        for i = 1, #colliders do
            local def = colliders[i]
            if type(def) == "table" then
                if type(def.radius) == "number" and def.radius > 0 then
                    maxRadius = math.max(maxRadius, def.radius)
                elseif type(def.width) == "number" and type(def.height) == "number" then
                    local radius = math.max(def.width, def.height) * 0.5
                    maxRadius = math.max(maxRadius, radius)
                end
            end
        end
        if maxRadius > 0 then
            return maxRadius
        end
    end

    local radius = Culling.computeCullRadius(entity)
    if radius > 0 then
        return radius
    end

    if entity.hullSize then
        local hx = entity.hullSize.x or 0
        local hy = entity.hullSize.y or 0
        local diag = vector.length(hx, hy)
        if diag > 0 then
            return diag * 0.5
        end
    end

    local drawable = entity.drawable
    if type(drawable) == "table" then
        if type(drawable.radius) == "number" and drawable.radius > 0 then
            return drawable.radius
        end
        if type(drawable.size) == "number" and drawable.size > 0 then
            return drawable.size * 0.5
        end
        if type(drawable.width) == "number" and type(drawable.height) == "number" then
            return math.max(drawable.width, drawable.height) * 0.5
        end
    end

    return DEFAULT_RADIUS
end

---@class SpatialIndexContext : table
---@field state table|nil
---@field spatialGrid SpatialGrid|nil
---@field cellSize number|nil

return function(context)
    context = context or {}

    return tiny.processingSystem {
        filter = tiny.requireAll("position"),

        init = function(self)
            self.context = context
            local state = context.state or context
            local grid = context.spatialGrid

            if not grid then
                local cellSize = context.cellSize
                if not (cellSize and cellSize > 0) then
                    if state and state.constants and state.constants.performance then
                        cellSize = state.constants.performance.spatial_grid_cell_size
                    end
                end
                grid = SpatialGrid.new(cellSize)
            end

            self.grid = grid

            if state then
                state.spatialGrid = grid
            end

            if state and state.world then
                grid:setOwner(state.world)
            end
        end,

        onAdd = function(self, entity)
            local grid = self.grid
            if not grid or entity.spatialIgnore then
                return
            end

            local pos = entity.position
            if not (pos and pos.x and pos.y) then
                return
            end

            local radius = compute_entity_radius(entity)
            grid:insert(entity, pos.x, pos.y, radius)
        end,

        onRemove = function(self, entity)
            local grid = self.grid
            if grid then
                grid:remove(entity)
            end
        end,

        process = function(self, entity)
            local grid = self.grid
            if not grid or entity.spatialIgnore then
                return
            end

            if entity.pendingDestroy then
                grid:remove(entity)
                return
            end

            local pos = entity.position
            if not (pos and pos.x and pos.y) then
                grid:remove(entity)
                return
            end

            local radius = compute_entity_radius(entity)
            grid:update(entity, pos.x, pos.y, radius)
        end,

        clear = function(self)
            if self.grid then
                self.grid:clear()
            end
        end,
    }
end
