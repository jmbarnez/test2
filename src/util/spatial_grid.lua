local SpatialGrid = {}
SpatialGrid.__index = SpatialGrid

local floor = math.floor

---@class SpatialGridRecord
---@field x number
---@field y number
---@field radius number
---@field cells table<string, boolean>

---@class SpatialGrid
---@field cellSize number
---@field cells table<string, table<any, boolean>>
---@field records table<any, SpatialGridRecord>
---@field _visited table<any, boolean>
---@field _queryBuffer table

---Creates a new spatial hash grid.
---@param cellSize number? Size of each grid cell (defaults to 256)
---@return SpatialGrid
function SpatialGrid.new(cellSize)
    if type(cellSize) ~= "number" or cellSize <= 0 then
        cellSize = 256
    end

    local grid = {
        cellSize = cellSize,
        cells = {},
        records = setmetatable({}, { __mode = "k" }),
        _visited = {},
        _queryBuffer = {},
        owner = nil,
    }

    return setmetatable(grid, SpatialGrid)
end

---Associates the grid with an owning table (state/world) for convenience.
---@param owner table|nil
function SpatialGrid:setOwner(owner)
    if self.owner and self.owner ~= owner and self.owner.spatialGrid == self then
        self.owner.spatialGrid = nil
    end

    self.owner = owner

    if owner then
        owner.spatialGrid = self
    end
end

local function to_cell_key(cx, cy)
    return tostring(cx) .. ":" .. tostring(cy)
end

function SpatialGrid:_cell_range(x, y, radius)
    local cs = self.cellSize
    local minX = floor((x - radius) / cs)
    local maxX = floor((x + radius) / cs)
    local minY = floor((y - radius) / cs)
    local maxY = floor((y + radius) / cs)
    return minX, maxX, minY, maxY
end

function SpatialGrid:_remove_from_cells(entity, cells)
    for key in pairs(cells) do
        local bucket = self.cells[key]
        if bucket then
            bucket[entity] = nil
            if not next(bucket) then
                self.cells[key] = nil
            end
        end
        cells[key] = nil
    end
end

function SpatialGrid:_add_to_cells(entity, cells, minX, maxX, minY, maxY)
    for cy = minY, maxY do
        for cx = minX, maxX do
            local key = to_cell_key(cx, cy)
            local bucket = self.cells[key]
            if not bucket then
                bucket = {}
                self.cells[key] = bucket
            end
            bucket[entity] = true
            cells[key] = true
        end
    end
end

local function normalize_radius(radius)
    if type(radius) ~= "number" or radius < 0 then
        return 0
    end
    return radius
end

---Inserts an entity into the grid.
---@param entity any
---@param x number
---@param y number
---@param radius number?
function SpatialGrid:insert(entity, x, y, radius)
    if not entity then
        return
    end

    local record = self.records[entity]
    local newX = x or 0
    local newY = y or 0
    local newRadius = normalize_radius(radius)

    local minX, maxX, minY, maxY = self:_cell_range(newX, newY, newRadius)

    if not record then
        record = {
            x = newX,
            y = newY,
            radius = newRadius,
            cells = {},
            minX = minX,
            maxX = maxX,
            minY = minY,
            maxY = maxY,
        }
        self.records[entity] = record
        self:_add_to_cells(entity, record.cells, minX, maxX, minY, maxY)
        return
    end

    local sameCells = record.minX == minX and record.maxX == maxX
        and record.minY == minY and record.maxY == maxY

    if not sameCells then
        self:_remove_from_cells(entity, record.cells)
        self:_add_to_cells(entity, record.cells, minX, maxX, minY, maxY)
    end

    record.x = newX
    record.y = newY
    record.radius = newRadius
    record.minX = minX
    record.maxX = maxX
    record.minY = minY
    record.maxY = maxY
end

---Updates an entity's position in the grid.
---@param entity any
---@param x number
---@param y number
---@param radius number?
function SpatialGrid:update(entity, x, y, radius)
    if not entity then
        return
    end

    if not self.records[entity] then
        self:insert(entity, x, y, radius)
        return
    end

    self:insert(entity, x, y, radius)
end

---Removes an entity from the grid.
---@param entity any
function SpatialGrid:remove(entity)
    local record = self.records[entity]
    if not record then
        return
    end

    self:_remove_from_cells(entity, record.cells)
    self.records[entity] = nil
end

---Clears all entities from the grid.
function SpatialGrid:clear()
    for key in pairs(self.cells) do
        self.cells[key] = nil
    end

    self.records = setmetatable({}, { __mode = "k" })
end

local function passes_filter(filter, entity)
    if type(filter) ~= "function" then
        return true
    end
    return filter(entity) ~= false
end

local function within_radius(dx, dy, radius)
    return dx * dx + dy * dy <= radius * radius
end

---Queries entities within the given radius.
---@param x number
---@param y number
---@param radius number
---@param out table|nil Optional table to reuse for results
---@param filter fun(entity:any):boolean|nil Optional entity filter
---@return table results
---@return integer count
function SpatialGrid:queryCircle(x, y, radius, out, filter)
    radius = normalize_radius(radius)
    local results = out or {}
    local count = 0

    if radius <= 0 then
        for i = 1, #results do
            results[i] = nil
        end
        return results, 0
    end

    local minX, maxX, minY, maxY = self:_cell_range(x, y, radius)
    local visited = self._visited

    for cy = minY, maxY do
        for cx = minX, maxX do
            local key = to_cell_key(cx, cy)
            local bucket = self.cells[key]
            if bucket then
                for entity in pairs(bucket) do
                    if not visited[entity] and passes_filter(filter, entity) then
                        visited[entity] = true
                        local record = self.records[entity]
                        if record then
                            local combined = radius + (record.radius or 0)
                            local dx = (record.x or 0) - x
                            local dy = (record.y or 0) - y
                            if within_radius(dx, dy, combined) then
                                count = count + 1
                                results[count] = entity
                            end
                        end
                    end
                end
            end
        end
    end

    for key in pairs(visited) do
        visited[key] = nil
    end

    for i = count + 1, #results do
        results[i] = nil
    end

    return results, count
end

---Iterates entities within the given radius and invokes a callback.
---@param x number
---@param y number
---@param radius number
---@param callback fun(entity:any)
---@param filter fun(entity:any):boolean|nil
function SpatialGrid:eachCircle(x, y, radius, callback, filter)
    if type(callback) ~= "function" then
        return
    end

    local results, count = self:queryCircle(x, y, radius, self._queryBuffer, filter)
    for i = 1, count do
        callback(results[i])
    end
    for i = 1, #self._queryBuffer do
        self._queryBuffer[i] = nil
    end
end

return SpatialGrid
