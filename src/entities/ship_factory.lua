local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
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
        assert(type(collider.points) == "table" and #collider.points >= 6, "Polygon collider requires points")

        local raw_points = collider.points
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
        assert(type(collider.radius) == "number" and collider.radius > 0, "Circle collider requires radius")
        local offset = collider.offset or {}
        return { love.physics.newCircleShape(offset.x or 0, offset.y or 0, collider.radius) }
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

local function instantiate_weapons(entity, blueprint, context)
    local weapon_defs = blueprint.weapons
    if type(weapon_defs) ~= "table" or #weapon_defs == 0 then
        return
    end

    entity.weapons = {}
    local override_by_id = context and context.weaponOverrides or nil

    for index = 1, #weapon_defs do
        local definition = weapon_defs[index]
        local def_type = type(definition)
        local weapon_id
        local instantiate_context

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

        if weapon_id then
            loader.instantiate("weapons", weapon_id, instantiate_context)
        end
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

    entity.position = entity.position or { x = 0, y = 0 }
    local spawn_x, spawn_y = resolve_spawn(blueprint.spawn, context, entity)
    entity.position.x = spawn_x
    entity.position.y = spawn_y

    entity.velocity = entity.velocity or { x = 0, y = 0 }
    entity.rotation = context.rotation or blueprint.spawn and blueprint.spawn.rotation or entity.rotation or 0

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

    if context.physicsWorld then
        local physics = blueprint.physics or {}
        local body_config = physics.body or {}
        local body_type = body_config.type or "dynamic"

        local body = love.physics.newBody(context.physicsWorld, spawn_x, spawn_y, body_type)
        body:setAngle(entity.rotation)
        apply_body_settings(body, body_config, entity.stats)
        body:setUserData(entity)

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

        local collider_shapes = {}
        local total_shape_count = 0

        for index = 1, #collider_defs do
            local shapes = create_shapes(collider_defs[index])
            collider_shapes[index] = shapes
            total_shape_count = total_shape_count + #shapes
        end

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
    else
        error("Ship instantiation requires a physicsWorld in context", 2)
    end

    instantiate_weapons(entity, blueprint, context)

    return entity
end

loader.register_factory("ships", ship_factory)

return ship_factory
