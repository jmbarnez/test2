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
-- Max depth prevents infinite recursion and performance issues
local MAX_COPY_DEPTH = 50

local function deep_copy_serializable(value, seen, depth)
    local valueType = type(value)
    if valueType == "nil" or valueType == "number" or valueType == "string" or valueType == "boolean" then
        return value
    end

    if valueType ~= "table" then
        return nil
    end

    -- Depth limit to prevent infinite recursion or excessive nesting
    depth = depth or 0
    if depth >= MAX_COPY_DEPTH then
        print("[ComponentRegistry] Warning: Max depth reached during serialization, truncating")
        return {}
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
            local copied = deep_copy_serializable(innerValue, seen, depth + 1)
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
    serialize = function(entity)
        local ai = entity.ai
        if type(ai) ~= "table" then
            return nil
        end
        
        -- Only serialize essential AI state, skip runtime data
        local copy = {
            behavior = ai.behavior,
            detectionRange = ai.detectionRange,
            engagementRange = ai.engagementRange,
            preferredDistance = ai.preferredDistance,
            wanderRadius = ai.wanderRadius,
            wanderSpeed = ai.wanderSpeed,
            wanderArriveRadius = ai.wanderArriveRadius,
            home = ai.home and { x = ai.home.x, y = ai.home.y } or nil,
            aggroRange = ai.aggroRange,
            leashRange = ai.leashRange,
        }
        
        return prune_empty(copy)
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" then
            return
        end
        
        entity.ai = entity.ai or {}
        for key, value in pairs(data) do
            entity.ai[key] = value
        end
    end,
}

ComponentRegistry.LOOT = {
    key = "loot",
    copy = true,
}

-- CARGO is handled by custom serialization in serialize_cargo_items
-- Do NOT deep copy it here to avoid duplication and performance issues
ComponentRegistry.CARGO = {
    key = "cargo",
    serialize = function(entity)
        -- Skip cargo serialization here - it's handled by entity_serializer
        return nil
    end,
    deserialize = function(entity, data)
        -- Skip cargo deserialization here - it's handled by restore_cargo_items
    end,
}

ComponentRegistry.QUEST = {
    key = "quest",
    copy = true,
}

-- Spawner is typically recreated from blueprints
ComponentRegistry.SPAWNER = {
    key = "spawner",
    serialize = function(entity)
        local spawner = entity.spawner
        if type(spawner) ~= "table" then
            return nil
        end
        
        -- Only save essential spawner state
        return prune_empty({
            spawnTimer = spawner.spawnTimer,
            spawnCount = spawner.spawnCount,
            maxSpawns = spawner.maxSpawns,
        })
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" or not entity.spawner then
            return
        end
        
        for key, value in pairs(data) do
            entity.spawner[key] = value
        end
    end,
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

ComponentRegistry.DRAWABLE = {
    key = "drawable",
    serialize = function(entity)
        local drawable = entity.drawable
        if type(drawable) ~= "table" then
            return nil
        end

        -- Only serialize essential drawable properties, not the entire part tree
        -- The blueprint will recreate the full drawable on load
        local copy = {
            radius = drawable.radius,
            color = drawable.color,
            renderLayer = drawable.renderLayer,
            -- Skip parts array - it's huge and recreated from blueprint
        }

        return prune_empty(copy)
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" or not entity.drawable then
            return
        end

        -- Only restore essential properties, blueprint handles the rest
        if data.radius then
            entity.drawable.radius = data.radius
        end
        if data.color then
            entity.drawable.color = data.color
        end
        if data.renderLayer then
            entity.drawable.renderLayer = data.renderLayer
        end
    end,
}

ComponentRegistry.WEAPON = {
    key = "weapon",
    serialize = function(entity)
        local weapon = entity.weapon
        if type(weapon) ~= "table" then
            return nil
        end

        local copy = deep_copy_serializable(weapon)
        if not copy then
            return nil
        end

        copy._fireRequested = nil
        copy._pendingTravelIndicator = nil
        copy._beamSegments = nil
        copy._beamImpactEvents = nil
        copy._chargeState = nil
        copy._activeTarget = nil
        copy._isLocalPlayer = nil
        copy._muzzleX = nil
        copy._muzzleY = nil
        copy._fireDirX = nil
        copy._fireDirY = nil

        return prune_empty(copy)
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" then
            return
        end

        local weapon = deep_copy_serializable(data)
        if not weapon then
            return
        end

        weapon._fireRequested = nil
        weapon._pendingTravelIndicator = nil
        weapon._beamSegments = nil
        weapon._beamImpactEvents = nil
        weapon._chargeState = nil
        weapon._activeTarget = nil
        weapon._isLocalPlayer = nil
        weapon._muzzleX = nil
        weapon._muzzleY = nil
        weapon._fireDirX = nil
        weapon._fireDirY = nil

        entity.weapon = weapon
    end,
}

ComponentRegistry.WEAPONS = {
    key = "weapons",
    serialize = function(entity)
        local weapons = entity.weapons
        if type(weapons) ~= "table" or #weapons == 0 then
            return nil
        end

        local serialized = {}

        local function serialize_weapon_state(component)
            if type(component) ~= "table" then
                return nil
            end

            local state = prune_empty({
                firing = component.firing,
                alwaysFire = component.alwaysFire,
                cooldown = component.cooldown,
                beamTimer = component.beamTimer,
                maxRange = component.maxRange,
                targetX = component.targetX,
                targetY = component.targetY,
                sequence = component.sequence,
                charge = component.charge,
                heat = component.heat,
                ammo = component.ammo,
            })

            return state and next(state) and state or nil
        end

        local function serialize_mount(mount)
            if type(mount) ~= "table" then
                return nil
            end

            local copy = prune_empty({
                forward = mount.forward,
                inset = mount.inset,
                lateral = mount.lateral,
                vertical = mount.vertical,
                offsetX = mount.offsetX,
                offsetY = mount.offsetY,
            })

            return copy and next(copy) and copy or nil
        end

        for i = 1, #weapons do
            local weapon = weapons[i]
            if type(weapon) == "table" then
                local entry = {}

                if weapon.id then
                    entry.id = weapon.id
                end

                if weapon.itemId then
                    entry.itemId = weapon.itemId
                end

                if weapon.assign then
                    entry.assign = weapon.assign
                end

                if type(weapon.blueprint) == "table" then
                    entry.blueprint = {
                        category = weapon.blueprint.category,
                        id = weapon.blueprint.id,
                    }
                end

                local state = serialize_weapon_state(weapon.weapon)
                if state then
                    entry.state = state
                end

                local mount = serialize_mount(weapon.weaponMount)
                if mount then
                    entry.mount = mount
                end

                if next(entry) then
                    serialized[#serialized + 1] = entry
                end
            end
        end

        if #serialized == 0 then
            return nil
        end

        return serialized
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" or type(entity) ~= "table" then
            return
        end

        local weapons = entity.weapons
        if type(weapons) ~= "table" or #weapons == 0 then
            return
        end

        local function matches(instance, snapshot)
            if not instance or not snapshot then
                return false
            end

            if snapshot.itemId and instance.itemId == snapshot.itemId then
                return true
            end

            if snapshot.id and instance.id == snapshot.id then
                return true
            end

            local blueprint = instance.blueprint
            local snapBlueprint = snapshot.blueprint
            if snapBlueprint and blueprint and blueprint.id == snapBlueprint.id then
                if not snapBlueprint.category or blueprint.category == snapBlueprint.category then
                    return true
                end
            end

            if snapshot.assign and instance.assign == snapshot.assign then
                return true
            end

            return false
        end

        for index = 1, #data do
            local entry = data[index]
            if type(entry) == "table" then
                local target
                for w = 1, #weapons do
                    local candidate = weapons[w]
                    if matches(candidate, entry) then
                        target = candidate
                        break
                    end
                end

                if not target then
                    target = weapons[index]
                end

                if target then
                    if entry.assign and not target.assign then
                        target.assign = entry.assign
                    end

                    if entry.mount then
                        target.weaponMount = target.weaponMount or {}
                        for key, value in pairs(entry.mount) do
                            target.weaponMount[key] = value
                        end
                    end

                    if entry.state and type(target.weapon) == "table" then
                        for key, value in pairs(entry.state) do
                            target.weapon[key] = value
                        end
                    end
                end
            end
        end
    end,
}

ComponentRegistry.ABILITY_MODULES = {
    key = "abilityModules",
    serialize = function(entity)
        local modules = entity.abilityModules
        if type(modules) ~= "table" or #modules == 0 then
            return nil
        end

        local serialized = {}
        for index = 1, #modules do
            local entry = modules[index]
            if type(entry) == "table" then
                local copy = deep_copy_serializable(entry)
                if copy then
                    serialized[#serialized + 1] = prune_empty(copy)
                end
            end
        end

        if #serialized == 0 then
            return nil
        end

        return serialized
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" then
            return
        end

        local modules = {}
        for index = 1, #data do
            local entry = data[index]
            if type(entry) == "table" then
                local copy = deep_copy_serializable(entry)
                if copy then
                    modules[#modules + 1] = copy
                end
            end
        end

        if #modules > 0 then
            entity.abilityModules = modules
        else
            entity.abilityModules = nil
        end
    end,
}

ComponentRegistry.ABILITY_STATE = {
    key = "_abilityState",
    serialize = function(entity)
        local state = entity._abilityState
        if type(state) ~= "table" then
            return nil
        end

        local copy = deep_copy_serializable(state)
        if not copy or next(copy) == nil then
            return nil
        end

        for _, abilityState in pairs(copy) do
            if type(abilityState) == "table" then
                abilityState.wasDown = nil
                abilityState.holdActive = nil
                abilityState._restoreFn = nil
                abilityState._dash_restore = nil
                abilityState._dash_prevDamping = nil
                abilityState._dash_prevBullet = nil
                abilityState._temporalFieldRemaining = nil
                abilityState._afterburnerZoomData = nil
            end
        end

        return prune_empty(copy)
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" then
            return
        end

        local copy = deep_copy_serializable(data)
        if not copy then
            return
        end

        for _, abilityState in pairs(copy) do
            if type(abilityState) == "table" then
                abilityState.wasDown = nil
                abilityState.holdActive = nil
                abilityState._restoreFn = nil
                abilityState._dash_restore = nil
                abilityState._dash_prevDamping = nil
                abilityState._dash_prevBullet = nil
                abilityState._temporalFieldRemaining = nil
                abilityState._afterburnerZoomData = nil
            end
        end

        entity._abilityState = copy
    end,
}

-- Colliders are recreated from blueprints, no need to serialize
ComponentRegistry.COLLIDERS = {
    key = "colliders",
    serialize = function(entity) return nil end,
    deserialize = function(entity, data) end,
}

ComponentRegistry.COLLIDER = {
    key = "collider",
    serialize = function(entity) return nil end,
    deserialize = function(entity, data) end,
}

ComponentRegistry.SHIP_RUNTIME = {
    key = "shipRuntime",
    serialize = function(entity)
        if entity.shipRuntime then
            return true
        end
        return nil
    end,
    deserialize = function(entity, data)
        if data then
            entity.shipRuntime = true
        end
    end,
}

ComponentRegistry.PILOT = {
    key = "pilot",
    serialize = function(entity)
        local pilot = entity.pilot
        if type(pilot) ~= "table" then
            return nil
        end

        local copy = deep_copy_serializable(pilot)
        if not copy then
            return nil
        end

        return prune_empty(copy)
    end,
    deserialize = function(entity, data)
        if type(data) ~= "table" then
            return
        end

        local copy = deep_copy_serializable(data)
        if not copy then
            return
        end

        entity.pilot = copy
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
        ComponentRegistry.DRAWABLE,
        ComponentRegistry.WEAPON,
        ComponentRegistry.WEAPONS,
        ComponentRegistry.ABILITY_MODULES,
        ComponentRegistry.ABILITY_STATE,
        ComponentRegistry.COLLIDERS,
        ComponentRegistry.COLLIDER,
        ComponentRegistry.SHIP_RUNTIME,
        ComponentRegistry.PILOT,
    }
end

--- Serializes an entity using the component registry
---@param entity table
---@return table
function ComponentRegistry.serializeEntity(entity)
    local data = {}
    local timer = love and love.timer
    
    for _, component in ipairs(ComponentRegistry.getAllComponents()) do
        local value
        local startTime = timer and timer.getTime and timer.getTime() or nil
        
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

        if startTime then
            local elapsed = timer.getTime() - startTime
            if elapsed > 0.2 then
                print(string.format("[ComponentRegistry] Slow serialize '%s' (%.2fs)", component.key, elapsed))
            end
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
