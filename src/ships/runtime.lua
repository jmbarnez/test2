local Items = require("src.items.registry")
local vector = require("src.util.vector")
local ship_util = require("src.ships.util")
local ShipCargo = require("src.ships.cargo")
local Modules = require("src.ships.modules")

local runtime = {}

-- Helper functions
local function compute_polygon_radius(points)
    if type(points) ~= "table" then return 0 end
    
    local maxRadius = 0
    for i = 1, #points, 2 do
        local radius = vector.length(points[i] or 0, points[i + 1] or 0)
        maxRadius = math.max(maxRadius, radius)
    end
    return maxRadius
end

local function compute_drawable_radius(drawable)
    if type(drawable) ~= "table" then return 0 end
    if drawable._mountRadius then return drawable._mountRadius end

    local radius = 0
    local parts = drawable.parts
    
    if type(parts) == "table" then
        for i = 1, #parts do
            local part = parts[i]
            if part then
                local partRadius
                if part.type == "ellipse" then
                    local rx = part.radiusX or (part.width and part.width * 0.5) or part.radius or 0
                    local ry = part.radiusY or (part.height and part.height * 0.5) or part.length or rx
                    partRadius = math.max(math.abs(rx), math.abs(ry))
                else
                    partRadius = compute_polygon_radius(part.points or {})
                end
                radius = math.max(radius, partRadius)
            end
        end
    end

    drawable._mountRadius = radius
    return radius
end

local function resolve_mount_anchor(mount_data, entity)
    if type(mount_data) ~= "table" or type(mount_data.anchor) ~= "table" then
        return mount_data
    end

    local mount_radius = entity and entity.mountRadius or 0
    if mount_radius > 0 then
        local anchor = mount_data.anchor
        mount_data.lateral = (mount_data.lateral or 0) + (anchor.x or 0) * mount_radius
        mount_data.forward = (mount_data.forward or 0) + (anchor.y or 0) * mount_radius
    end

    mount_data.anchor = nil
    return mount_data
end

local function create_shapes(collider)
    if type(collider) ~= "table" then
        error("Ship blueprint requires a collider definition", 3)
    end

    local collider_type = collider.type or "polygon"
    local offset = collider.offset or {}
    local ox, oy = offset.x or 0, offset.y or 0

    if collider_type == "circle" then
        local radius = collider.radius
        if type(radius) ~= "number" or radius <= 0 then
            error("Circle collider requires a positive radius", 3)
        end
        return { love.physics.newCircleShape(ox, oy, radius) }
    end

    if collider_type == "polygon" then
        local raw_points = collider.points
        if type(raw_points) ~= "table" or #raw_points < 6 then
            error("Polygon collider requires at least 3 vertices (6 coordinates)", 3)
        end

        -- Apply offset
        local adjusted = {}
        for i = 1, #raw_points, 2 do
            adjusted[#adjusted + 1] = raw_points[i] + ox
            adjusted[#adjusted + 1] = raw_points[i + 1] + oy
        end

        local vertex_count = #adjusted / 2
        
        -- Simple polygon
        if vertex_count <= 8 then
            return { love.physics.newPolygonShape(adjusted) }
        end

        -- Triangulate complex polygon
        local shapes = {}
        for i = 3, vertex_count do
            local triangle = {
                adjusted[1], adjusted[2],
                adjusted[(i - 1) * 2 - 1], adjusted[(i - 1) * 2],
                adjusted[i * 2 - 1], adjusted[i * 2],
            }
            shapes[#shapes + 1] = love.physics.newPolygonShape(triangle)
        end
        return shapes
    end

    error(string.format("Unsupported collider type '%s'", tostring(collider_type)), 3)
end

-- Expose utility functions
runtime.compute_polygon_radius = compute_polygon_radius
runtime.compute_drawable_radius = compute_drawable_radius
runtime.resolve_mount_anchor = resolve_mount_anchor
runtime.create_shapes = create_shapes

function runtime.create_entity(components)
    return ship_util.deep_copy(components or {})
end

local function populate_weapon_inventory(entity, context)
    local weapons, cargo = entity.weapons, entity.cargo
    if not (weapons and cargo and cargo.items) then return end

    local weaponOverrides = (context or {}).weaponOverrides or {}

    for i = 1, #weapons do
        local weapon = weapons[i]
        if weapon and weapon.itemId then
            local overrides = weapon.blueprint and weapon.blueprint.id 
                and weaponOverrides[weapon.blueprint.id]
            
            local itemInstance = Items.instantiate(weapon.itemId, {
                installed = true,
                slot = weapon.assign,
                mount = weapon.weaponMount,
                overrides = overrides,
            })
            
            if itemInstance then
                cargo.items[#cargo.items + 1] = itemInstance
                cargo.dirty = true
            end
        end
    end
end

-- Health system
function runtime.initialize_health(entity, constants)
    local hull = entity.hull
    if hull then
        local maxHull = hull.max or hull.capacity or hull.strength or 100
        hull.max = maxHull
        hull.current = math.min(hull.current or maxHull, maxHull)
    end

    -- Initialize health component
    if not entity.health then
        entity.health = hull or { max = 100, current = 100 }
    else
        entity.health.max = entity.health.max or (hull and hull.max) or entity.health.current or 100
        entity.health.current = math.min(entity.health.current or entity.health.max, entity.health.max)
    end
    entity.health.showTimer = entity.health.showTimer or 0

    -- Initialize health bar
    if not entity.healthBar and constants and constants.ships and constants.ships.health_bar then
        entity.healthBar = ship_util.deep_copy(constants.ships.health_bar)
    end
    
    if entity.healthBar then
        entity.healthBar.showDuration = entity.healthBar.showDuration or entity.healthBar.show_duration
    end
end

function runtime.decrement_health_timer(entity, dt)
    local health = entity.health
    if health and health.showTimer and health.showTimer > 0 and dt > 0 then
        health.showTimer = math.max(0, health.showTimer - dt)
    end
end

-- Shield system
local function resolve_shield_component(entity)
    if type(entity) ~= "table" then return nil end

    local shield = entity.shield
    if type(shield) == "table" then
        if entity.health then
            entity.health.shield = entity.health.shield or shield
        end
        return shield
    end

    -- Check if shield is in health component
    if entity.health and type(entity.health.shield) == "table" then
        entity.shield = entity.health.shield
        return entity.health.shield
    end

    return nil
end

local function clamp(value, min_val, max_val)
    return math.max(min_val, math.min(value, max_val))
end

local function initialize_shield(entity)
    local shield = resolve_shield_component(entity)
    if not shield then return end

    local maxShield = math.max(0, tonumber(shield.max or shield.capacity or shield.limit 
        or shield.strength or shield.current or 0) or 0)
    
    shield.max = maxShield
    shield.current = maxShield > 0 and clamp(tonumber(shield.current) or maxShield, 0, maxShield) or 0
    shield.regen = math.max(0, tonumber(shield.regen) or 0)
    shield.rechargeDelay = math.max(0, tonumber(shield.rechargeDelay) or 0)
    shield.rechargeTimer = math.max(0, tonumber(shield.rechargeTimer) or 0)
    shield.percent = maxShield > 0 and (shield.current / maxShield) or 0
    shield.isDepleted = shield.current <= 0
end

local function update_shield(entity, dt)
    local shield = resolve_shield_component(entity)
    if not shield or dt <= 0 then return end

    local maxShield = math.max(0, tonumber(shield.max) or 0)
    shield.max = maxShield

    if maxShield <= 0 then
        shield.current, shield.percent, shield.rechargeTimer = 0, 0, 0
        shield.isDepleted = true
        return
    end

    local current = clamp(tonumber(shield.current) or maxShield, 0, maxShield)
    local rechargeTimer = math.max(0, (tonumber(shield.rechargeTimer) or 0) - dt)
    local regenRate = math.max(0, tonumber(shield.regen) or 0)

    -- Regenerate shield
    if regenRate > 0 and rechargeTimer <= 0 and current < maxShield then
        current = math.min(maxShield, current + regenRate * dt)
    end

    shield.current = current
    shield.rechargeTimer = rechargeTimer
    shield.percent = current / maxShield
    shield.isDepleted = current <= 0
end

-- Energy system
local function initialize_energy(entity)
    local energy = entity.energy
    if type(energy) ~= "table" then return end

    local stats = entity.stats or {}
    local maxEnergy = math.max(0, tonumber(energy.max or energy.capacity or energy.limit 
        or energy.current or stats.main_thrust or 0) or 0)

    energy.max = maxEnergy
    energy.current = maxEnergy > 0 and clamp(tonumber(energy.current) or maxEnergy, 0, maxEnergy) or 0
    energy.regen = math.max(0, tonumber(energy.regen) or 0)
    energy.thrustDrain = math.max(0, tonumber(energy.thrustDrain) or stats.main_thrust or 0)
    energy.rechargeDelay, energy.rechargeTimer = 0, 0
    energy.isDepleted = energy.current <= 0
    energy.percent = maxEnergy > 0 and (energy.current / maxEnergy) or 0
end

local function update_energy(entity, dt)
    local energy = entity.energy
    if type(energy) ~= "table" then return end

    local maxEnergy = math.max(0, tonumber(energy.max) or 0)
    energy.max = maxEnergy

    if maxEnergy <= 0 then
        energy.current, energy.percent, energy.rechargeTimer = 0, 0, 0
        energy.isDepleted = true
        return
    end

    local current = tonumber(energy.current) or maxEnergy
    local regenRate = math.max(0, tonumber(energy.regen) or 0)

    -- Only regenerate for players
    if entity.player and regenRate > 0 then
        current = math.min(maxEnergy, current + regenRate * dt)
    else
        current = math.min(maxEnergy, current)
    end

    energy.current = current
    energy.percent = current / maxEnergy
    energy.isDepleted = current <= 0
end

-- Main runtime functions
function runtime.initialize(entity, constants, context)
    entity.shipRuntime = true

    if entity.cargo then
        ShipCargo.initialize(entity.cargo)
    end

    Modules.initialize(entity)
    runtime.initialize_health(entity, constants)
    initialize_shield(entity)
    initialize_energy(entity)
    populate_weapon_inventory(entity, context or {})
    Modules.sync_from_cargo(entity)
    ShipCargo.refresh_if_needed(entity.cargo)

    if entity.stats and entity.stats.main_thrust then
        entity.maxThrust = entity.stats.main_thrust
    end
end

function runtime.update(entity, dt)
    ShipCargo.refresh_if_needed(entity.cargo)
    if entity.cargo and entity.cargo.dirty then
        Modules.sync_from_cargo(entity)
    end
    runtime.decrement_health_timer(entity, dt)
    update_shield(entity, dt)
    update_energy(entity, dt)
end

function runtime.serialize(entity)
    if type(entity) ~= "table" then return nil end

    local body = entity.body
    local vx, vy, angularVelocity = 0, 0, nil
    
    if body and not body:isDestroyed() then
        vx, vy = body:getLinearVelocity()
        angularVelocity = body:getAngularVelocity()
    end

    return {
        entityId = entity.id or entity.entityId,
        playerId = entity.playerId,
        faction = entity.faction,
        blueprint = entity.blueprint and {
            category = entity.blueprint.category,
            id = entity.blueprint.id,
        } or nil,
        position = {
            x = entity.position and entity.position.x or (body and body:getX()) or 0,
            y = entity.position and entity.position.y or (body and body:getY()) or 0,
        },
        rotation = entity.rotation or (body and body:getAngle()) or 0,
        velocity = { x = vx, y = vy },
        angularVelocity = angularVelocity,
        health = entity.health and {
            current = entity.health.current,
            max = entity.health.max,
        } or nil,
        level = entity.level and ship_util.deep_copy(entity.level) or nil,
        thrust = {
            isThrusting = not not entity.isThrusting,
            current = entity.currentThrust or 0,
            max = entity.maxThrust or (entity.stats and entity.stats.main_thrust),
        },
        energy = entity.energy and {
            current = entity.energy.current,
            max = entity.energy.max,
        } or nil,
        shield = entity.shield and {
            current = entity.shield.current,
            max = entity.shield.max,
        } or nil,
        modules = Modules.serialize(entity),
        stats = entity.stats and ship_util.deep_copy(entity.stats) or nil,
        cargo = entity.cargo and {
            used = entity.cargo.used,
            capacity = entity.cargo.capacity,
        } or nil,
    }
end

function runtime.applySnapshot(entity, snapshot)
    if type(entity) ~= "table" or type(snapshot) ~= "table" then
        return entity
    end

    -- Simple property updates
    entity.playerId = snapshot.playerId or entity.playerId
    entity.faction = snapshot.faction or entity.faction

    -- Position
    if snapshot.position then
        entity.position = entity.position or {}
        entity.position.x = snapshot.position.x or entity.position.x or 0
        entity.position.y = snapshot.position.y or entity.position.y or 0
    end

    -- Rotation and velocity
    if snapshot.rotation ~= nil then entity.rotation = snapshot.rotation end
    if snapshot.velocity then
        entity.velocity = entity.velocity or {}
        entity.velocity.x = snapshot.velocity.x or 0
        entity.velocity.y = snapshot.velocity.y or 0
    end

    -- Health
    if snapshot.health then
        entity.health = entity.health or {}
        entity.health.current = snapshot.health.current or entity.health.current
        entity.health.max = snapshot.health.max or entity.health.max
    end

    -- Level and stats
    if snapshot.level then
        entity.level = ship_util.deep_copy(snapshot.level)
    end
    if snapshot.stats then
        entity.stats = entity.stats or {}
        for key, value in pairs(snapshot.stats) do
            entity.stats[key] = value
        end
    end

    -- Thrust
    if snapshot.thrust then
        entity.isThrusting = not not snapshot.thrust.isThrusting
        entity.currentThrust = snapshot.thrust.current or entity.currentThrust
        entity.maxThrust = snapshot.thrust.max or entity.maxThrust
    end

    -- Energy
    if snapshot.energy then
        entity.energy = entity.energy or {}
        entity.energy.current = snapshot.energy.current or entity.energy.current
        entity.energy.max = snapshot.energy.max or entity.energy.max
    end

    -- Shield
    if snapshot.shield then
        local shield = resolve_shield_component(entity) or {}
        if not entity.shield then
            entity.shield = shield
            if entity.health then entity.health.shield = shield end
        end

        shield.current = snapshot.shield.current or shield.current or 0
        shield.max = snapshot.shield.max or shield.max or 0
        shield.percent = shield.max > 0 and (shield.current / shield.max) or 0
        shield.isDepleted = shield.current <= 0
    end

    if snapshot.modules then
        Modules.apply_snapshot(entity, snapshot.modules)
    else
        Modules.sync_from_cargo(entity)
    end

    -- Weapons
    if snapshot.weapons and type(entity.weapons) == "table" then
        for index = 1, #snapshot.weapons do
            local weaponSnapshot = snapshot.weapons[index]
            local weapon = entity.weapons[index]
            
            -- Find weapon by id if not at same index
            if not weapon and weaponSnapshot.id then
                for w = 1, #entity.weapons do
                    local candidate = entity.weapons[w]
                    local candidateId = candidate and (candidate.id or (candidate.blueprint and candidate.blueprint.id))
                    if candidateId == weaponSnapshot.id then
                        weapon = candidate
                        break
                    end
                end
            end

            if weapon then
                runtime.apply_weapon_state(weapon, weaponSnapshot)
            end
        end
    end

    if snapshot.weapon and entity.weapon then
        runtime.apply_weapon_state(entity.weapon, snapshot.weapon)
    end

    if snapshot.weaponMount then
        entity.weaponMount = ship_util.deep_copy(snapshot.weaponMount)
    end

    -- Cargo
    if snapshot.cargo and entity.cargo then
        entity.cargo.capacity = snapshot.cargo.capacity or entity.cargo.capacity
        entity.cargo.used = snapshot.cargo.used or entity.cargo.used
        entity.cargo.available = math.max(0, (entity.cargo.capacity or 0) - (entity.cargo.used or 0))
    end

    return entity
end

function runtime.apply_weapon_state(weapon, snapshot)
    if type(weapon) ~= "table" or type(snapshot) ~= "table" then return end

    weapon.firing = not not snapshot.firing
    weapon.alwaysFire = not not snapshot.alwaysFire
    weapon.cooldown = snapshot.cooldown or 0
    weapon.beamTimer = snapshot.beamTimer
    weapon.maxRange = snapshot.maxRange or weapon.maxRange
    weapon.targetX = snapshot.targetX
    weapon.targetY = snapshot.targetY
    weapon.sequence = snapshot.sequence or weapon.sequence

    if snapshot.mount then
        weapon.weaponMount = ship_util.deep_copy(snapshot.mount)
    end
end

return runtime
