--- Component Registry for Generic Serialization
-- Defines which components are serializable and provides custom handlers
-- Adding a new serializable component is as simple as adding an entry here

local ComponentRegistry = {}

---@class ComponentDefinition
---@field key string The component key on the entity
---@field serialize? fun(entity: table): any Custom serialization function (optional)
---@field deserialize? fun(entity: table, data: any) Custom deserialization function (optional)
---@field copy? boolean If true, deep copy the component (default behavior if no serialize function)

-- Helper to prune empty values from tables
local function prune_empty(tbl, seen)
    if type(tbl) ~= "table" then
        return tbl
    end

    seen = seen or {}
    if seen[tbl] then
        return tbl
    end
    seen[tbl] = true

    for key, value in pairs(tbl) do
        if value == nil then
            tbl[key] = nil
        elseif type(value) == "table" then
            prune_empty(value, seen)
            if next(value) == nil then
                tbl[key] = nil
            end
        end
    end

    seen[tbl] = nil
    return tbl
end

-- Helper to deep copy serializable values
local function deep_copy_serializable(value, seen)
    local valueType = type(value)
    if valueType == "nil" or valueType == "number" or valueType == "string" or valueType == "boolean" then
        return value
    end

    if valueType ~= "table" then
        return nil
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local result = {}
    seen[value] = result

    for key, innerValue in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            local copied = deep_copy_serializable(innerValue, seen)
            if copied ~= nil then
                result[key] = copied
            end
        end
    end

    if next(result) == nil then
        return {}
    end

    return result
end

-- Core Physics Components
ComponentRegistry.POSITION = {
    key = "position",
    serialize = function(entity)
        local px, py
        
        if entity.position then
            px = entity.position.x
            py = entity.position.y
        end
        
        -- Prefer physics body position if available
        local body = entity.body
        if body and not body:isDestroyed() then
            px = body:getX()
            py = body:getY()
        end
        
        if px or py then
            return { x = px or 0, y = py or 0 }
        end
        
        return nil
    end,
    deserialize = function(entity, data)
        if not data then return end
        entity.position = entity.position or {}
        entity.position.x = data.x or entity.position.x or 0
        entity.position.y = data.y or entity.position.y or 0
    end,
}

ComponentRegistry.ROTATION = {
    key = "rotation",
    serialize = function(entity)
        if entity.rotation ~= nil then
            return entity.rotation
        end
        
        if entity.body and not entity.body:isDestroyed() then
            return entity.body:getAngle()
        end
        
        return nil
    end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.rotation = data
        end
    end,
}

ComponentRegistry.VELOCITY = {
    key = "velocity",
    serialize = function(entity)
        local vx, vy
        
        if entity.velocity then
            vx = entity.velocity.x
            vy = entity.velocity.y
        end
        
        -- Prefer physics body velocity if available
        local body = entity.body
        if body and not body:isDestroyed() then
            local bodyVx, bodyVy = body:getLinearVelocity()
            vx = bodyVx
            vy = bodyVy
        end
        
        if vx or vy then
            return { x = vx or 0, y = vy or 0 }
        end
        
        return nil
    end,
    deserialize = function(entity, data)
        if not data then return end
        entity.velocity = entity.velocity or {}
        entity.velocity.x = data.x or entity.velocity.x or 0
        entity.velocity.y = data.y or entity.velocity.y or 0
    end,
}

ComponentRegistry.ANGULAR_VELOCITY = {
    key = "angularVelocity",
    serialize = function(entity)
        if entity.angularVelocity ~= nil then
            return entity.angularVelocity
        end
        
        if entity.body and not entity.body:isDestroyed() then
            return entity.body:getAngularVelocity()
        end
        
        return nil
    end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.angularVelocity = data
        end
    end,
}

-- Resource Components
ComponentRegistry.HEALTH = {
    key = "health",
    serialize = function(entity)
        if type(entity.health) ~= "table" then
            return nil
        end
        
        return prune_empty({
            current = entity.health.current,
            max = entity.health.max,
            regen = entity.health.regen,
            showTimer = entity.health.showTimer,
        })
    end,
    deserialize = function(entity, data)
        if not data then return end
        entity.health = entity.health or {}
        for key, value in pairs(data) do
            entity.health[key] = value
        end
    end,
}

ComponentRegistry.SHIELD = {
    key = "shield",
    serialize = function(entity)
        if type(entity.shield) ~= "table" then
            return nil
        end
        
        return prune_empty({
            current = entity.shield.current,
            max = entity.shield.max,
            regen = entity.shield.regen,
            percent = entity.shield.percent,
            isDepleted = entity.shield.isDepleted,
        })
    end,
    deserialize = function(entity, data)
        if not data then return end
        entity.shield = entity.shield or {}
        for key, value in pairs(data) do
            entity.shield[key] = value
        end
        -- Link shield to health if health exists
        if entity.health then
            entity.health.shield = entity.shield
        end
    end,
}

ComponentRegistry.ENERGY = {
    key = "energy",
    serialize = function(entity)
        if type(entity.energy) ~= "table" then
            return nil
        end
        
        return prune_empty({
            current = entity.energy.current,
            max = entity.energy.max,
        })
    end,
    deserialize = function(entity, data)
        if not data then return end
        entity.energy = entity.energy or {}
        for key, value in pairs(data) do
            entity.energy[key] = value
        end
    end,
}

ComponentRegistry.THRUST = {
    key = "thrust",
    serialize = function(entity)
        if entity.currentThrust or entity.maxThrust or entity.isThrusting then
            return prune_empty({
                current = entity.currentThrust,
                max = entity.maxThrust,
                isThrusting = not not entity.isThrusting,
            })
        end
        return nil
    end,
    deserialize = function(entity, data)
        if not data then return end
        entity.thrust = entity.thrust or {}
        for key, value in pairs(data) do
            entity.thrust[key] = value
        end
        entity.isThrusting = data.isThrusting
        entity.maxThrust = data.max or entity.maxThrust
        entity.currentThrust = data.current or entity.currentThrust
    end,
}

-- Generic Deep-Copy Components (no special logic needed)
ComponentRegistry.STATS = {
    key = "stats",
    copy = true,
}

ComponentRegistry.AI = {
    key = "ai",
    copy = true,
}

ComponentRegistry.LOOT = {
    key = "loot",
    copy = true,
}

ComponentRegistry.CARGO = {
    key = "cargo",
    copy = true,
}

ComponentRegistry.QUEST = {
    key = "quest",
    copy = true,
}

ComponentRegistry.SPAWNER = {
    key = "spawner",
    copy = true,
}

-- Simple Value Components (copied as-is)
ComponentRegistry.CHUNK_LEVEL = {
    key = "chunkLevel",
    serialize = function(entity) return entity.chunkLevel end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.chunkLevel = data
        end
    end,
}

ComponentRegistry.MINING_VARIANT = {
    key = "miningVariant",
    serialize = function(entity) return entity.miningVariant end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.miningVariant = data
        end
    end,
}

ComponentRegistry.FACTION = {
    key = "faction",
    serialize = function(entity) return entity.faction end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.faction = data
        end
    end,
}

ComponentRegistry.ENEMY = {
    key = "enemy",
    serialize = function(entity) return entity.enemy end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.enemy = data
        end
    end,
}

ComponentRegistry.STATION = {
    key = "station",
    serialize = function(entity) return entity.station end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.station = data
        end
    end,
}

ComponentRegistry.ASTEROID = {
    key = "asteroid",
    serialize = function(entity) return entity.asteroid end,
    deserialize = function(entity, data)
        if data ~= nil then
            entity.asteroid = data
        end
    end,
}

--- Returns an ordered list of all component definitions
---@return ComponentDefinition[]
function ComponentRegistry.getAllComponents()
    return {
        ComponentRegistry.POSITION,
        ComponentRegistry.ROTATION,
        ComponentRegistry.VELOCITY,
        ComponentRegistry.ANGULAR_VELOCITY,
        ComponentRegistry.HEALTH,
        ComponentRegistry.SHIELD,
        ComponentRegistry.ENERGY,
        ComponentRegistry.THRUST,
        ComponentRegistry.STATS,
        ComponentRegistry.AI,
        ComponentRegistry.LOOT,
        ComponentRegistry.CARGO,
        ComponentRegistry.QUEST,
        ComponentRegistry.SPAWNER,
        ComponentRegistry.CHUNK_LEVEL,
        ComponentRegistry.MINING_VARIANT,
        ComponentRegistry.FACTION,
        ComponentRegistry.ENEMY,
        ComponentRegistry.STATION,
        ComponentRegistry.ASTEROID,
    }
end

--- Serializes an entity using the component registry
---@param entity table
---@return table
function ComponentRegistry.serializeEntity(entity)
    local data = {}
    
    for _, component in ipairs(ComponentRegistry.getAllComponents()) do
        local value
        
        if component.serialize then
            -- Use custom serializer
            value = component.serialize(entity)
        elseif component.copy and entity[component.key] then
            -- Deep copy the component
            value = deep_copy_serializable(entity[component.key])
        end
        
        if value ~= nil then
            data[component.key] = value
        end
    end
    
    return prune_empty(data)
end

--- Applies serialized data to an entity using the component registry
---@param entity table
---@param data table
function ComponentRegistry.deserializeEntity(entity, data)
    if not (entity and data) then
        return
    end
    
    for _, component in ipairs(ComponentRegistry.getAllComponents()) do
        local serializedValue = data[component.key]
        
        if serializedValue ~= nil then
            if component.deserialize then
                -- Use custom deserializer
                component.deserialize(entity, serializedValue)
            elseif component.copy then
                -- Deep copy into entity
                entity[component.key] = deep_copy_serializable(serializedValue)
            end
        end
    end
end

return ComponentRegistry
