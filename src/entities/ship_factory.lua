local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local Items = require("src.items.registry")
---@diagnostic disable-next-line: undefined-global
local love = love

local ship_factory = {}

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

local function deep_merge(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            local existing = target[key]
            if type(existing) ~= "table" then
                existing = {}
                target[key] = existing
            end
            deep_merge(existing, value)
        else
            target[key] = value
        end
    end

    return target
end

local function compute_polygon_radius(points)
    local maxRadius = 0
    for i = 1, #points, 2 do
        local x = points[i]
        local y = points[i + 1]
        local radius = math.sqrt(x * x + y * y)
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
                local partRadius = 0
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

local function resolve_spawn(spawn, context, entity)
    if context and context.position then
        local pos = context.position
        return pos.x or 0, pos.y or 0
    end

    spawn = spawn or {}
    if spawn.strategy == "world_center" and context and context.worldBounds then
        local bounds = context.worldBounds
        return bounds.x + bounds.width * 0.5, bounds.y + bounds.height * 0.5
    end

    local original = entity and entity.position or {}
    local x = spawn.x or original.x or 0
    local y = spawn.y or original.y or 0
    return x, y
end

local function create_shapes(collider)
    if not collider then
        error("Ship blueprint requires a collider definition", 3)
    end

    local collider_type = collider.type or "polygon"
    if collider_type == "polygon" then
        local raw_points = collider.points
        if not raw_points or type(raw_points) ~= "table" or #raw_points < 6 then
            error("Polygon collider requires at least 3 vertices (6 coordinates)", 3)
        end

        local offset = collider.offset
        local adjusted = {}
        local vertex_count = #raw_points / 2

        if offset then
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

        -- Triangulate complex polygons using fan triangulation
        local shapes = {}
        for i = 3, vertex_count do
            local triangle = {
                adjusted[1], adjusted[2],
                adjusted[(i - 1) * 2 - 1], adjusted[(i - 1) * 2],
                adjusted[i * 2 - 1], adjusted[i * 2]
            }
            shapes[#shapes + 1] = love.physics.newPolygonShape(triangle)
        end

        return shapes
    elseif collider_type == "circle" then
        local radius = collider.radius
        if not radius or type(radius) ~= "number" or radius <= 0 then
            error("Circle collider requires a positive radius", 3)
        end
        local offset = collider.offset or {}
        return { love.physics.newCircleShape(offset.x or 0, offset.y or 0, radius) }
    else
        error(string.format("Unsupported collider type '%s'", tostring(collider_type)), 3)
    end
end

local function apply_body_settings(body, body_config, stats)
    if not body_config then
        return
    end

    if body_config.fixedRotation ~= nil then
        body:setFixedRotation(body_config.fixedRotation)
    end

    if body_config.linearDamping then
        body:setLinearDamping(body_config.linearDamping)
    elseif stats and stats.linear_damping then
        body:setLinearDamping(stats.linear_damping)
    end

    if body_config.angularDamping then
        body:setAngularDamping(body_config.angularDamping)
    elseif stats and stats.angular_damping then
        body:setAngularDamping(stats.angular_damping)
    end
end

local function apply_fixture_settings(fixture, fixture_config)
    if not fixture_config then
        return
    end

    if fixture_config.friction then
        fixture:setFriction(fixture_config.friction)
    end

    if fixture_config.restitution then
        fixture:setRestitution(fixture_config.restitution)
    end

    if fixture_config.isSensor ~= nil then
        fixture:setSensor(fixture_config.isSensor)
    end
end

local function resolve_mount_anchor(mount_data, entity)
    if not mount_data then
        return mount_data
    end

    local anchor = mount_data.anchor
    if not anchor then
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

local function sanitize_positive_number(value)
    local n = tonumber(value) or 0
    if n < 0 then
        return 0
    end
    return n
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

        local instance = Items.createWeaponItem(weaponId, overrides)
        if instance then
            instance.quantity = sanitize_positive_number(instance.quantity or descriptor.quantity or 1)
            instance.volume = sanitize_positive_number(descriptor.volume or instance.volume or 1)
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

local function initialize_cargo(cargo)
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

local function instantiate_weapons(entity, blueprint, context)
    local weapon_defs = blueprint.weapons
    if type(weapon_defs) ~= "table" or #weapon_defs == 0 then
        return
    end

    entity.weapons = {}
    local override_by_id = context and context.weaponOverrides

    for index = 1, #weapon_defs do
        local definition = weapon_defs[index]
        local def_type = type(definition)
        local weapon_id, instantiate_context

        if def_type == "string" then
            weapon_id = definition
            instantiate_context = { owner = entity }
        elseif def_type == "table" then
            weapon_id = definition.id or definition.weapon or definition.blueprint or definition[1]
            if weapon_id then
                instantiate_context = {
                    owner = entity,
                    assign = definition.assign,
                    mount = definition.mount or definition.weaponMount,
                }

                local overrides = {}
                if type(definition.overrides) == "table" then
                    deep_merge(overrides, definition.overrides)
                end

                local context_override = override_by_id and override_by_id[weapon_id]
                if type(context_override) == "table" then
                    deep_merge(overrides, context_override)
                end

                if next(overrides) then
                    instantiate_context.overrides = overrides
                end
            end
        end

        if weapon_id and instantiate_context then
            local mount = instantiate_context.mount
            if mount then
                local mount_copy = deep_copy(mount)
                resolve_mount_anchor(mount_copy, entity)

                instantiate_context.mount = mount_copy
            end
            loader.instantiate("weapons", weapon_id, instantiate_context)
        end
    end
end

local function initialize_health_system(entity, blueprint, constants)
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

    if entity.cargo then
        initialize_cargo(entity.cargo)
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

function ship_factory.instantiate(blueprint, context)
    assert(type(blueprint) == "table", "instantiate requires a blueprint table")
    context = context or {}

    local entity = deep_copy(blueprint.components or {})
    entity.blueprint = {
        category = blueprint.category,
        id = blueprint.id,
        name = blueprint.name,
    }

    -- Initialize position and rotation
    entity.position = entity.position or { x = 0, y = 0 }
    local spawn_x, spawn_y = resolve_spawn(blueprint.spawn, context, entity)
    entity.position.x = spawn_x
    entity.position.y = spawn_y

    entity.velocity = entity.velocity or { x = 0, y = 0 }
    entity.rotation = context.rotation or (blueprint.spawn and blueprint.spawn.rotation) or entity.rotation or 0

    -- Initialize health system
    initialize_health_system(entity, blueprint, constants)

    -- Create physics body
    if not context.physicsWorld then
        error("Ship instantiation requires a physicsWorld in context", 2)
    end

    local physics = blueprint.physics or {}
    local body_config = physics.body or {}
    local body_type = body_config.type or "dynamic"

    local body = love.physics.newBody(context.physicsWorld, spawn_x, spawn_y, body_type)
    body:setAngle(entity.rotation)
    apply_body_settings(body, body_config, entity.stats)
    body:setUserData(entity)

    -- Setup colliders
    local collider_defs = entity.colliders
    if not collider_defs or #collider_defs == 0 then
        if entity.collider then
            collider_defs = { entity.collider }
        else
            error("Ship blueprint requires at least one collider definition", 2)
        end
    end

    local base_density = physics.fixture and physics.fixture.density
    local density_source = "explicit"
    if not base_density then
        if entity.stats and entity.stats.mass then
            base_density = entity.stats.mass
            density_source = "mass"
        else
            base_density = 1
            density_source = "default"
        end
    end

    -- Create all shapes first for mass distribution calculation
    local collider_shapes = {}
    local total_shape_count = 0
    for index = 1, #collider_defs do
        local shapes = create_shapes(collider_defs[index])
        collider_shapes[index] = shapes
        total_shape_count = total_shape_count + #shapes
    end

    -- Create fixtures
    local shapes = {}
    local fixtures = {}
    local shape_index = 1

    for index = 1, #collider_defs do
        local collider = collider_defs[index]
        local shapes_for_collider = collider_shapes[index]

        for s = 1, #shapes_for_collider do
            local shape = shapes_for_collider[s]

            local density = collider.density or base_density
            if density_source == "mass" and not collider.density then
                density = base_density / total_shape_count
            end

            local fixture = love.physics.newFixture(body, shape, density)
            apply_fixture_settings(fixture, collider.fixture or physics.fixture)
            fixture:setUserData({
                type = collider.name or collider.type or "ship",
                entity = entity,
                collider = collider.name,
            })

            shapes[shape_index] = shape
            fixtures[shape_index] = fixture
            shape_index = shape_index + 1
        end
    end

    entity.body = body
    entity.shape = shapes[1]
    entity.fixture = fixtures[1]
    entity.shapes = shapes
    entity.fixtures = fixtures
    entity.collider = nil

    entity.mountRadius = compute_drawable_radius(entity.drawable)

    instantiate_weapons(entity, blueprint, context)

    if entity.cargo and entity.cargo.items and entity.weapons then
        for i = 1, #entity.weapons do
            local weapon = entity.weapons[i]
            if weapon and weapon.itemId then
                local itemInstance = Items.instantiate(weapon.itemId, {
                    installed = true,
                    slot = weapon.assign,
                    mount = weapon.weaponMount,
                    overrides = context.weaponOverrides and context.weaponOverrides[weapon.blueprint.id],
                })
                if itemInstance then
                    entity.cargo.items[#entity.cargo.items + 1] = itemInstance
                end
            end
        end
    end

    return entity
end

loader.register_factory("ships", ship_factory)

ship_factory.initializeCargo = initialize_cargo

return ship_factory
