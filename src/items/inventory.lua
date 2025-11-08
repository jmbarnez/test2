local Inventory = {}
Inventory.__index = Inventory

local function deepcopy(value, cache)
    if type(value) ~= "table" then
        return value
    end

    cache = cache or {}
    if cache[value] then
        return cache[value]
    end

    local copy = {}
    cache[value] = copy

    for k, v in pairs(value) do
        copy[deepcopy(k, cache)] = deepcopy(v, cache)
    end

    local mt = getmetatable(value)
    if mt then
        setmetatable(copy, mt)
    end

    return copy
end

local function normalize_item(item)
    if type(item) ~= "table" then
        return nil
    end

    item.quantity = item.quantity or 1
    if item.quantity < 1 then
        item.quantity = 1
    end

    return item
end

function Inventory.new(initial)
    local inv = {
        items = {},
        capacity = initial and initial.capacity or nil,
    }
    setmetatable(inv, Inventory)

    if initial then
        if type(initial.items) == "table" then
            for i = 1, #initial.items do
                local item = normalize_item(deepcopy(initial.items[i]))
                if item then
                    inv.items[#inv.items + 1] = item
                end
            end
        end
    end

    return inv
end

function Inventory:add(item)
    item = normalize_item(item)
    if not item then
        return false, "invalid_item"
    end

    -- simple append for now (no stacking logic yet)
    self.items[#self.items + 1] = item
    return true
end

function Inventory:remove(predicate)
    if type(predicate) ~= "function" then
        return nil, "invalid_predicate"
    end

    for i = 1, #self.items do
        local item = self.items[i]
        if predicate(item, i) then
            table.remove(self.items, i)
            return item
        end
    end

    return nil, "not_found"
end

function Inventory:find(predicate)
    if type(predicate) ~= "function" then
        return nil
    end

    for i = 1, #self.items do
        local item = self.items[i]
        if predicate(item, i) then
            return item, i
        end
    end
end

function Inventory:list()
    return self.items
end

return Inventory
