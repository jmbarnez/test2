local EntityIds = {}

---@class EntityIds

local love_ref = love
local math_random = (love_ref and love_ref.math and love_ref.math.random) or math.random
local knownIds = setmetatable({}, { __mode = "v" })

local function random16()
    return math_random(0, 0xFFFF)
end

local function generate_uuid()
    local id
    repeat
        id = string.format(
            "%04x%04x-%04x-%04x-%04x-%04x%04x%04x",
            random16(), random16(),
            random16(),
            random16(),
            random16(),
            random16(), random16(), random16()
        )
    until knownIds[id] == nil
    return id
end

local function register(entity, id)
    if type(id) ~= "string" or id == "" then
        return false
    end

    local existing = knownIds[id]
    if existing and existing ~= entity then
        return false
    end

    knownIds[id] = entity or true
    return true
end

---Ensures the entity has a stable entityId, generating one if necessary.
---@param entity table
---@return string|nil
function EntityIds.ensure(entity)
    if type(entity) ~= "table" then
        return nil
    end

    local id = entity.entityId
    if type(id) ~= "string" or id == "" then
        if type(entity._saveId) == "string" and entity._saveId ~= "" then
            id = entity._saveId
        else
            id = generate_uuid()
        end
    end

    return EntityIds.assign(entity, id)
end

---Assigns a specific identifier to the entity and registers it.
---@param entity table
---@param id string|nil
---@return string|nil
function EntityIds.assign(entity, id)
    if type(entity) ~= "table" then
        return nil
    end

    if type(id) ~= "string" or id == "" then
        return EntityIds.ensure(entity)
    end

    local current = entity.entityId
    if current and current ~= id then
        if knownIds[current] == entity then
            knownIds[current] = nil
        end
    end

    entity.entityId = id
    entity._saveId = nil
    register(entity, id)
    return id
end

---Generates a brand-new identifier without assigning it.
---@return string
function EntityIds.generate()
    return generate_uuid()
end

---Registers an identifier as in-use for the provided entity.
---@param entity table|nil
---@param id string
---@return boolean
function EntityIds.register(entity, id)
    return register(entity, id)
end

---Returns whether the identifier is known to be in use.
---@param id string
---@return boolean
function EntityIds.isKnown(id)
    return knownIds[id] ~= nil
end

---Clears all tracked identifiers (primarily for tests).
function EntityIds.reset()
    for key in pairs(knownIds) do
        knownIds[key] = nil
    end
end

return EntityIds
