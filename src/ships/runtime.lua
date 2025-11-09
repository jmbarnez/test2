local loader = require("src.blueprints.loader")
local Items = require("src.items.registry")
local vector = require("src.util.vector")

local runtime = {}

local function sanitize_positive_number(value)
    local n = tonumber(value) or 0
    return n < 0 and 0 or n
end

local function deep_copy(value, cache)
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
        copy[deep_copy(k, cache)] = deep_copy(v, cache)
    end

    local mt = getmetatable(value)
    if mt then
        setmetatable(copy, mt)
    end

    return copy
end

local function instantiate_initial_item(descriptor)
    if type(descriptor) ~= "table" then
        if type(descriptor) == "string" then
            local itemInstance = Items.instantiate(descriptor)
            if itemInstance then
                return itemInstance
            end
        end
        return descriptor
    end

    if descriptor.id and descriptor.type then
        local clone = deep_copy(descriptor)
        clone.quantity = sanitize_positive_number(clone.quantity or 1)
        clone.volume = sanitize_positive_number(clone.volume or 1)
        return clone
    end

    local weaponId = descriptor.weapon or descriptor.weaponId
    if weaponId then
        local blueprint
        local ok, loaded = pcall(loader.load, "weapons", weaponId)
        if ok then
            blueprint = loaded
        end

        local overrides = {}
        if descriptor.quantity then
            overrides.quantity = sanitize_positive_number(descriptor.quantity)
        end
        if descriptor.installed ~= nil then
            overrides.installed = descriptor.installed
        end
        if descriptor.slot then
            overrides.slot = descriptor.slot
        end
        if descriptor.mount then
            overrides.mount = deep_copy(descriptor.mount)
        end
        if descriptor.overrides then
            overrides.overrides = deep_copy(descriptor.overrides)
        end
        if descriptor.name then
            overrides.name = descriptor.name
        end

        local instance
        if blueprint then
            instance = Items.ensureWeaponItem(blueprint, overrides)
        else
            instance = Items.createWeaponItem(weaponId, overrides)
        end

        if instance then
            instance.quantity = sanitize_positive_number(instance.quantity or descriptor.quantity or 1)
            instance.volume = sanitize_positive_number(descriptor.volume or instance.volume or 1)
            if not instance.icon and blueprint and blueprint.icon then
                instance.icon = deep_copy(blueprint.icon)
            end
            return instance
        end
    end

    local fallback = deep_copy(descriptor)
    fallback.quantity = sanitize_positive_number(fallback.quantity or 1)
    fallback.volume = sanitize_positive_number(fallback.volume or 1)
    return fallback
end

local function cargo_recalculate(self)
    if type(self) ~= "table" then
        return 0
    end

    local items = self.items
    if type(items) ~= "table" then
        items = {}
        self.items = items
    end

    local total = 0
    for index = #items, 1, -1 do
        local item = items[index]
        if type(item) ~= "table" then
            table.remove(items, index)
        else
            item.quantity = sanitize_positive_number(item.quantity or item.count)
            item.volume = sanitize_positive_number(item.volume or item.unitVolume)

            if item.quantity == 0 or item.volume == 0 then
                table.remove(items, index)
            else
                total = total + item.quantity * item.volume
            end
        end
    end

    self.capacity = sanitize_positive_number(self.capacity)
    self.used = total
    self.available = math.max(0, self.capacity - total)
    return total
end

local function cargo_can_fit(self, additionalVolume)
    if type(self) ~= "table" then
        return false
    end

    local volume = sanitize_positive_number(additionalVolume)
    if volume == 0 then
        return true
    end

    local capacity = sanitize_positive_number(self.capacity)
    local used = sanitize_positive_number(self.used)
    return volume <= math.max(0, capacity - used)
end

local function cargo_try_add(self, descriptor, quantity)
    if type(self) ~= "table" or type(descriptor) ~= "table" then
        return false, "invalid_descriptor"
    end

    local qty = sanitize_positive_number(quantity or descriptor.quantity or 1)
    local perVolume = sanitize_positive_number(descriptor.volume or descriptor.unitVolume)
    if qty == 0 or perVolume == 0 then
        return false, "zero_volume"
    end

    local deltaVolume = qty * perVolume
    if not cargo_can_fit(self, deltaVolume) then
        return false, "insufficient_capacity"
    end

    local items = self.items
    local id = descriptor.id
    local target

    if id then
        for i = 1, #items do
            local existing = items[i]
            if existing and existing.id == id then
                target = existing
                break
            end
        end
    end

    if target then
        target.quantity = sanitize_positive_number(target.quantity) + qty
        target.volume = sanitize_positive_number(target.volume)
        if target.volume == 0 then
            target.volume = perVolume
        end
    else
        target = {
            id = id,
            name = descriptor.name or descriptor.displayName or id or "Unknown Cargo",
            quantity = qty,
            volume = perVolume,
            icon = descriptor.icon,
        }
        items[#items + 1] = target
    end

    self.used = sanitize_positive_number(self.used) + deltaVolume
    self.capacity = sanitize_positive_number(self.capacity)
    self.available = math.max(0, self.capacity - self.used)
    self.dirty = true
    return true
end

local function cargo_try_remove(self, itemId, quantity)
    if type(self) ~= "table" or not itemId then
        return false, "invalid_item"
    end

    local qty = sanitize_positive_number(quantity or 1)
    if qty == 0 then
        return false, "zero_quantity"
    end

    local items = self.items
    for index = 1, #items do
        local item = items[index]
        if item and (item.id == itemId or item.name == itemId) then
            local removable = math.min(item.quantity or 0, qty)
            if removable <= 0 then
                return false, "insufficient_quantity"
            end

            item.quantity = (item.quantity or 0) - removable
            local freedVolume = removable * (item.volume or 0)

            if item.quantity <= 0 then
                table.remove(items, index)
            end

            self.used = math.max(0, sanitize_positive_number(self.used) - freedVolume)
            self.capacity = sanitize_positive_number(self.capacity)
            self.available = math.max(0, self.capacity - self.used)
            self.dirty = true
            return true
        end
    end

    return false, "not_found"
end

local function compute_polygon_radius(points)
    local maxRadius = 0
    if type(points) ~= "table" then
        return maxRadius
    end

    for i = 1, #points, 2 do
        local x = points[i] or 0
        local y = points[i + 1] or 0
        local radius = vector.length(x, y)
        if radius > maxRadius then
            maxRadius = radius
        end
    end

    return maxRadius
end

local function compute_drawable_radius(drawable)
    if type(drawable) ~= "table" then
        return 0
    end

    if drawable._mountRadius then
        return drawable._mountRadius
    end

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

                if partRadius > radius then
                    radius = partRadius
                end
            end
        end
    end

    drawable._mountRadius = radius
    return radius
end

local function resolve_mount_anchor(mount_data, entity)
    if type(mount_data) ~= "table" then
        return mount_data
    end

    local anchor = mount_data.anchor
    if type(anchor) ~= "table" then
        return mount_data
    end

    local mount_radius = entity and entity.mountRadius or 0
    if mount_radius > 0 then
        local anchorX = anchor.x or 0
        local anchorY = anchor.y or 0
        mount_data.lateral = (mount_data.lateral or 0) + anchorX * mount_radius
        mount_data.forward = (mount_data.forward or 0) + anchorY * mount_radius
    end

    mount_data.anchor = nil
    return mount_data
end

local function create_shapes(collider)
    if type(collider) ~= "table" then
        error("Ship blueprint requires a collider definition", 3)
    end

    local collider_type = collider.type or "polygon"

    if collider_type == "polygon" then
        local raw_points = collider.points
        if type(raw_points) ~= "table" or #raw_points < 6 then
            error("Polygon collider requires at least 3 vertices (6 coordinates)", 3)
        end

        local offset = collider.offset
        local adjusted = {}
        local vertex_count = #raw_points / 2

        if type(offset) == "table" then
            local ox = offset.x or 0
            local oy = offset.y or 0
            for i = 1, #raw_points, 2 do
                adjusted[#adjusted + 1] = raw_points[i] + ox
                adjusted[#adjusted + 1] = raw_points[i + 1] + oy
            end
        else
            for i = 1, #raw_points do
                adjusted[i] = raw_points[i]
            end
        end

        if vertex_count <= 8 then
            return { love.physics.newPolygonShape(adjusted) }
        end

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
    elseif collider_type == "circle" then
        local radius = collider.radius
        if type(radius) ~= "number" or radius <= 0 then
            error("Circle collider requires a positive radius", 3)
        end
        local offset = collider.offset or {}
        return { love.physics.newCircleShape(offset.x or 0, offset.y or 0, radius) }
    else
        error(string.format("Unsupported collider type '%s'", tostring(collider_type)), 3)
    end
end

runtime.deep_copy = deep_copy
runtime.compute_polygon_radius = compute_polygon_radius
runtime.compute_drawable_radius = compute_drawable_radius
runtime.resolve_mount_anchor = resolve_mount_anchor
runtime.create_shapes = create_shapes

function runtime.create_entity(components)
    return deep_copy(components or {})
end

function runtime.initialize_cargo(cargo)
    if type(cargo) ~= "table" then
        return nil
    end

    cargo.capacity = sanitize_positive_number(cargo.capacity or cargo.volumeCapacity or cargo.volumeLimit)
    cargo.items = type(cargo.items) == "table" and cargo.items or {}

    if #cargo.items > 0 then
        local normalized = {}
        for index = 1, #cargo.items do
            local resolved = instantiate_initial_item(cargo.items[index])
            if resolved then
                normalized[#normalized + 1] = resolved
            end
        end
        cargo.items = normalized
    end

    cargo.refresh = cargo.refresh or cargo_recalculate
    cargo.canFit = cargo.canFit or cargo_can_fit
    cargo.tryAddItem = cargo.tryAddItem or cargo_try_add
    cargo.tryRemoveItem = cargo.tryRemoveItem or cargo_try_remove

    cargo.refresh(cargo)
    cargo.dirty = false
    cargo.autoRefresh = cargo.autoRefresh ~= false
    return cargo
end

local function populate_weapon_inventory(entity, context)
    local weapons = entity.weapons
    local cargo = entity.cargo
    if not (weapons and cargo and cargo.items) then
        return
    end

    for i = 1, #weapons do
        local weapon = weapons[i]
        if weapon and weapon.itemId then
            local overrides = context.weaponOverrides and context.weaponOverrides[weapon.blueprint.id]
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

function runtime.initialize_health(entity, constants)
    local hull = entity.hull
    if hull then
        local maxHull = hull.max or hull.capacity or hull.strength or 100
        entity.hull.max = maxHull
        entity.hull.current = math.min(hull.current or maxHull, maxHull)
    end

    if entity.health then
        entity.health.max = entity.health.max or (entity.hull and entity.hull.max) or entity.health.current or 100
        entity.health.current = math.min(entity.health.current or entity.health.max, entity.health.max)
        entity.health.showTimer = entity.health.showTimer or 0
    elseif entity.hull then
        entity.health = entity.hull
        entity.health.showTimer = entity.health.showTimer or 0
    end

    if not entity.healthBar then
        local defaults = constants.ships and constants.ships.health_bar
        if defaults then
            entity.healthBar = deep_copy(defaults)
            local bar = entity.healthBar
            bar.showDuration = bar.showDuration or bar.show_duration
        end
    elseif entity.healthBar.showDuration == nil and entity.healthBar.show_duration ~= nil then
        entity.healthBar.showDuration = entity.healthBar.show_duration
    end
end

local function decrement_health_timer(entity, dt)
    if dt <= 0 then
        return
    end

    local health = entity.health
    if health and health.showTimer and health.showTimer > 0 then
        health.showTimer = math.max(0, health.showTimer - dt)
    end
end

local function refresh_cargo_if_dirty(cargo)
    if not cargo then
        return
    end

    if cargo.autoRefresh ~= false and cargo.dirty and type(cargo.refresh) == "function" then
        cargo.refresh(cargo)
        cargo.dirty = false
    end
end

function runtime.initialize(entity, constants, context)
    entity.shipRuntime = true

    if entity.cargo then
        runtime.initialize_cargo(entity.cargo)
    end

    runtime.initialize_health(entity, constants)
    populate_weapon_inventory(entity, context or {})
    refresh_cargo_if_dirty(entity.cargo)
end

function runtime.update(entity, dt)
    refresh_cargo_if_dirty(entity.cargo)
    decrement_health_timer(entity, dt)
end

local function serialize_weapon_state(weapon)
    if type(weapon) ~= "table" then
        return nil
    end

    local state = {
        id = weapon.id or (weapon.blueprint and weapon.blueprint.id),
        assign = weapon.assign,
        firing = not not weapon.firing,
        alwaysFire = not not weapon.alwaysFire,
        cooldown = weapon.cooldown,
        beamTimer = weapon.beamTimer,
        maxRange = weapon.maxRange,
        targetX = weapon.targetX,
        targetY = weapon.targetY,
        sequence = weapon.sequence,
    }

    if weapon.mount then
        state.mount = deep_copy(weapon.mount)
    elseif weapon.weaponMount then
        state.mount = deep_copy(weapon.weaponMount)
    end

    return state
end

local function apply_weapon_state(weapon, snapshot)
    if type(weapon) ~= "table" or type(snapshot) ~= "table" then
        return
    end

    weapon.firing = not not snapshot.firing
    weapon.alwaysFire = not not snapshot.alwaysFire
    weapon.cooldown = snapshot.cooldown or 0
    weapon.beamTimer = snapshot.beamTimer
    weapon.maxRange = snapshot.maxRange or weapon.maxRange
    weapon.targetX = snapshot.targetX
    weapon.targetY = snapshot.targetY
    weapon.sequence = snapshot.sequence or weapon.sequence

    if snapshot.mount then
        weapon.weaponMount = deep_copy(snapshot.mount)
    end
end

function runtime.serialize(entity)
    if type(entity) ~= "table" then
        return nil
    end

    local body = entity.body
    local vx, vy = 0, 0
    local angularVelocity
    if body and not body:isDestroyed() then
        vx, vy = body:getLinearVelocity()
        angularVelocity = body:getAngularVelocity()
    end

    local weapons
    if type(entity.weapons) == "table" and #entity.weapons > 0 then
        weapons = {}
        for i = 1, #entity.weapons do
            local weaponState = serialize_weapon_state(entity.weapons[i])
            if weaponState then
                weapons[#weapons + 1] = weaponState
            end
        end
    end

    -- Serialize primary weapon component
    local weaponState
    if entity.weapon then
        weaponState = serialize_weapon_state(entity.weapon)
    end

    local snapshot = {
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
        level = entity.level and deep_copy(entity.level) or nil,
        thrust = {
            isThrusting = not not entity.isThrusting,
            current = entity.currentThrust or 0,
            max = entity.maxThrust or (entity.stats and entity.stats.main_thrust),
        },
        weapons = weapons,
        weapon = weaponState,
        weaponMount = entity.weaponMount and deep_copy(entity.weaponMount) or nil,
        stats = entity.stats and deep_copy(entity.stats) or nil,
        cargo = entity.cargo and {
            used = entity.cargo.used,
            capacity = entity.cargo.capacity,
        } or nil,
    }

    return snapshot
end

function runtime.applySnapshot(entity, snapshot)
    if type(entity) ~= "table" or type(snapshot) ~= "table" then
        return entity
    end

    local body = entity.body

    if snapshot.playerId then
        entity.playerId = snapshot.playerId
    end
    if snapshot.faction then
        entity.faction = snapshot.faction
    end

    if snapshot.position then
        entity.position = entity.position or {}
        entity.position.x = snapshot.position.x or entity.position.x or 0
        entity.position.y = snapshot.position.y or entity.position.y or 0
        -- Don't update body here - snapshot.lua handles body positioning for interpolation
    end

    if snapshot.rotation ~= nil then
        entity.rotation = snapshot.rotation
        -- Don't update body here - snapshot.lua handles body rotation for interpolation
    end

    if snapshot.velocity then
        entity.velocity = entity.velocity or {}
        entity.velocity.x = snapshot.velocity.x or 0
        entity.velocity.y = snapshot.velocity.y or 0
        -- Don't update body here - snapshot.lua handles body velocity for interpolation
    end

    -- Don't update angularVelocity on body - snapshot.lua handles all body state for interpolation

    if snapshot.health then
        entity.health = entity.health or {}
        entity.health.current = snapshot.health.current or entity.health.current
        entity.health.max = snapshot.health.max or entity.health.max
    end

    if snapshot.level then
        entity.level = deep_copy(snapshot.level)
    end

    if snapshot.stats then
        entity.stats = entity.stats or {}
        for key, value in pairs(snapshot.stats) do
            entity.stats[key] = value
        end
    end

    if snapshot.thrust then
        entity.isThrusting = not not snapshot.thrust.isThrusting
        entity.currentThrust = snapshot.thrust.current or entity.currentThrust
        entity.maxThrust = snapshot.thrust.max or entity.maxThrust
    end

    if snapshot.weapons and type(entity.weapons) == "table" then
        for index = 1, #snapshot.weapons do
            local weaponSnapshot = snapshot.weapons[index]
            local weapon = entity.weapons[index]
            if not weapon and weaponSnapshot.id then
                -- Attempt to find by weapon id
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
                apply_weapon_state(weapon, weaponSnapshot)
            end
        end
    end

    -- Apply primary weapon component
    if snapshot.weapon and entity.weapon then
        apply_weapon_state(entity.weapon, snapshot.weapon)
    end

    -- Apply weapon mount
    if snapshot.weaponMount then
        entity.weaponMount = deep_copy(snapshot.weaponMount)
    end

    if snapshot.cargo and entity.cargo then
        entity.cargo.capacity = snapshot.cargo.capacity or entity.cargo.capacity
        entity.cargo.used = snapshot.cargo.used or entity.cargo.used
        entity.cargo.available = math.max(0, (entity.cargo.capacity or 0) - (entity.cargo.used or 0))
    end

    return entity
end

runtime.sanitize_positive_number = sanitize_positive_number
runtime.instantiate_initial_item = instantiate_initial_item
runtime.cargo_recalculate = cargo_recalculate
runtime.cargo_can_fit = cargo_can_fit
runtime.cargo_try_add = cargo_try_add
runtime.cargo_try_remove = cargo_try_remove
runtime.populate_weapon_inventory = populate_weapon_inventory
runtime.serialize = runtime.serialize
runtime.applySnapshot = runtime.applySnapshot

return runtime