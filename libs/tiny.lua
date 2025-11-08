local tiny = {}

local World = {}
World.__index = World

local function default_filter()
    return true
end

local function call_if_present(target, method, ...)
    if target and target[method] then
        target[method](target, ...)
    end
end

function tiny.system(def)
    def = def or {}
    def.filter = def.filter or default_filter
    return def
end

function tiny.requireAll(...)
    local keys = { ... }
    return function(entity)
        for i = 1, #keys do
            if entity[keys[i]] == nil then
                return false
            end
        end
        return true
    end
end

function tiny.rejectAny(...)
    local keys = { ... }
    return function(entity)
        for i = 1, #keys do
            if entity[keys[i]] ~= nil then
                return false
            end
        end
        return true
    end
end

function tiny.requireOne(...)
    local keys = { ... }
    return function(entity)
        for i = 1, #keys do
            if entity[keys[i]] ~= nil then
                return true
            end
        end
        return false
    end
end

local function make_world()
    return setmetatable({
        entities = {},
        systems = {},
        to_add = {},
        to_remove = {},
    }, World)
end

function tiny.world(...)
    local world = make_world()
    local systems = { ... }
    for i = 1, #systems do
        world:addSystem(systems[i])
    end
    return world
end

function World:add(entity)
    if entity == nil then
        error("Attempted to add a nil entity", 2)
    end
    entity.world = self
    table.insert(self.to_add, entity)
    return entity
end

function World:remove(entity)
    if entity == nil then
        return
    end
    table.insert(self.to_remove, entity)
end

function World:refresh(entity)
    for i = 1, #self.systems do
        local system = self.systems[i]
        if system.__pool[entity] then
            system.__pool[entity] = nil
            call_if_present(system, "onRemove", entity)
        end
    end
end

local function ensure_initialized(system)
    if system and system.init and not system.__initialized then
        system:init()
        system.__initialized = true
    end
end

function World:addSystem(system)
    assert(type(system) == "table", "system must be a table")
    system.world = self
    system.__active = (system.active ~= false)
    system.__pool = setmetatable({}, { __mode = "k" })
    table.insert(self.systems, system)
    ensure_initialized(system)
    return system
end

local function entity_matches(system, entity)
    local ok, result = pcall(system.filter, entity)
    if not ok then
        error(string.format("System filter error: %s", result), 3)
    end
    return result and system.__active
end

function World:_flush()
    if #self.to_add > 0 then
        for i = 1, #self.to_add do
            local entity = self.to_add[i]
            table.insert(self.entities, entity)
        end
        self.to_add = {}
    end

    if #self.to_remove > 0 then
        for i = 1, #self.to_remove do
            local target = self.to_remove[i]
            for idx = #self.entities, 1, -1 do
                if self.entities[idx] == target then
                    table.remove(self.entities, idx)
                    target.world = nil
                    break
                end
            end
            for s = 1, #self.systems do
                local system = self.systems[s]
                if system.__pool[target] then
                    system.__pool[target] = nil
                    call_if_present(system, "onRemove", target)
                end
            end
        end
        self.to_remove = {}
    end
end

local function process_system_entities(system, dt)
    local world = system.world
    for i = 1, #world.entities do
        local entity = world.entities[i]
        local matches = entity_matches(system, entity)
        local tracked = system.__pool[entity]

        if matches then
            if not tracked then
                system.__pool[entity] = true
                call_if_present(system, "onAdd", entity)
            end
            if system.process then
                system:process(entity, dt)
            end
        elseif tracked then
            system.__pool[entity] = nil
            call_if_present(system, "onRemove", entity)
        end
    end
end

function World:update(dt)
    self:_flush()
    for i = 1, #self.systems do
        local system = self.systems[i]
        if system.__active then
            if system.update then
                system:update(dt)
            end
            if system.process then
                process_system_entities(system, dt)
            end
        end
    end
    self:_flush()
end

function World:draw()
    for i = 1, #self.systems do
        local system = self.systems[i]
        if system.__active then
            if system.draw then
                system:draw()
            end
            if system.drawEntity then
                local entities = self.entities
                for idx = 1, #entities do
                    local entity = entities[idx]
                    if entity_matches(system, entity) then
                        system:drawEntity(entity)
                    end
                end
            end
        end
    end
end

function World:clear()
    for i = 1, #self.entities do
        local entity = self.entities[i]
        if entity then
            entity.world = nil
        end
    end
    self.entities = {}
    self.to_add = {}
    self.to_remove = {}
    for i = 1, #self.systems do
        local system = self.systems[i]
        system.__pool = setmetatable({}, { __mode = "k" })
    end
end

function tiny.activate(system)
    system.__active = true
end

function tiny.deactivate(system)
    system.__active = false
end

return tiny
