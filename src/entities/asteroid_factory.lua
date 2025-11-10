local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local math_util = require("src.util.math")

---@diagnostic disable-next-line: undefined-global
local love = love
local math = math
local unpack = table.unpack or unpack

local asteroid_factory = {}

local asteroid_constants = constants.asteroids or {}

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

local function random_range(range, default)
    if type(range) == "table" then
        local min = range.min or range[1] or default or 0
        local max = range.max or range[2] or min
        if min > max then
            min, max = max, min
        end
        min = math.floor(min + 0.5)
        max = math.floor(max + 0.5)
        return love.math.random(min, max)
    elseif type(range) == "number" then
        return range
    end
    return default
end

local function random_float_range(range, default)
    if type(range) == "table" then
        local min = range.min or range[1] or default or 0
        local max = range.max or range[2] or min
        if min > max then
            min, max = max, min
        end
        if min == max then
            return min
        end
        return min + love.math.random() * (max - min)
    elseif type(range) == "number" then
        return range
    end
    return default
end

local function build_polygon(radius, sides, scale_range)
    local vertices = {}
    local step = math_util.TAU / sides

    for i = 0, sides - 1 do
        local angle = i * step
        local scale = random_float_range(scale_range, 1)
        local r = radius * scale
        vertices[#vertices + 1] = math.cos(angle) * r
        vertices[#vertices + 1] = math.sin(angle) * r
    end

    return vertices
end

local function create_polygon_shapes(vertices)
    assert(type(vertices) == "table" and #vertices >= 6 and (#vertices % 2 == 0), "Polygon collider requires vertex list")

    local vertex_count = #vertices / 2
    if vertex_count <= 8 then
        return { love.physics.newPolygonShape(unpack(vertices)) }
    end

    local shapes = {}
    local base_x, base_y = vertices[1], vertices[2]
    for i = 3, vertex_count do
        shapes[#shapes + 1] = love.physics.newPolygonShape(
            base_x, base_y,
            vertices[(i - 1) * 2 - 1], vertices[(i - 1) * 2],
            vertices[i * 2 - 1], vertices[i * 2]
        )
    end

    return shapes
end

local function resolve_position(context, entity)
    if context.position then
        local pos = context.position
        entity.position.x = pos.x or entity.position.x
        entity.position.y = pos.y or entity.position.y
    end
end

local function apply_body_settings(body, body_config)
    if not body_config then
        return
    end

    if body_config.fixedRotation ~= nil then
        body:setFixedRotation(body_config.fixedRotation)
    end

    if body_config.linearDamping ~= nil then
        body:setLinearDamping(body_config.linearDamping)
    else
        local damping = asteroid_constants.damping
        if damping and damping.linear then
            body:setLinearDamping(damping.linear)
        end
    end

    if body_config.angularDamping ~= nil then
        body:setAngularDamping(body_config.angularDamping)
    else
        local damping = asteroid_constants.damping
        if damping and damping.angular then
            body:setAngularDamping(damping.angular)
        end
    end
end

local function apply_fixture_settings(fixture, fixture_config, defaults)
    local friction = (fixture_config and fixture_config.friction) or defaults.friction
    if friction then
        fixture:setFriction(friction)
    end

    local restitution = (fixture_config and fixture_config.restitution) or defaults.restitution
    if restitution then
        fixture:setRestitution(restitution)
    end

    if fixture_config and fixture_config.isSensor ~= nil then
        fixture:setSensor(fixture_config.isSensor)
    end
end

function asteroid_factory.instantiate(blueprint, context)
    assert(type(blueprint) == "table", "instantiate requires a blueprint table")
    context = context or {}

    local config = context.config or {}

    local entity = deep_copy(blueprint.components or {})
    entity.blueprint = {
        category = blueprint.category,
        id = blueprint.id,
        name = blueprint.name,
    }

    entity.position = entity.position or { x = 0, y = 0 }
    resolve_position(context, entity)

    entity.rotation = context.rotation or entity.rotation or love.math.random() * math_util.TAU
    entity.velocity = entity.velocity or { x = 0, y = 0 }

    local radius = random_range(config.radius or asteroid_constants.radius, 40)
    local sides = math.max(5, random_range(config.sides or asteroid_constants.sides, 7))
    local scale = config.scale or asteroid_constants.scale or { min = 0.85, max = 1.1 }

    local drawable = entity.drawable or {}
    drawable.type = "asteroid"
    drawable.radius = radius
    drawable.color = drawable.color or config.color or asteroid_constants.color or { 0.7, 0.65, 0.6 }
    drawable.shape = build_polygon(radius, sides, scale)
    entity.drawable = drawable

    entity.radius = entity.radius or radius

    local durability = config.durability or asteroid_constants.durability or { min = 120, max = 220 }
    local max_health = random_range(durability, 160)

    entity.health = entity.health or {}
    entity.health.max = max_health

    local starting_health = entity.health.current
    if not starting_health or starting_health <= 0 then
        entity.health.current = max_health
    else
        entity.health.current = math.min(starting_health, max_health)
    end

    entity.health.showTimer = entity.health.showTimer or 0

    local health_bar_defaults = config.health_bar or asteroid_constants.health_bar or {}
    local health_bar = entity.healthBar or {}
    health_bar.showDuration = health_bar.showDuration or health_bar.show_duration or health_bar_defaults.show_duration or 1.5
    health_bar.height = health_bar.height or health_bar_defaults.height or 4
    health_bar.padding = health_bar.padding or health_bar_defaults.padding or 6
    health_bar.width = health_bar.width or radius * 1.6
    health_bar.offset = health_bar.offset or radius + health_bar.padding
    entity.healthBar = health_bar

    local loot_config = config.loot or entity.loot or asteroid_constants.loot
    if loot_config then
        entity.loot = deep_copy(loot_config)
    end

    if not entity.onDestroyed then
        entity.onDestroyed = function(self)
            if self.body and not self.body:isDestroyed() then
                self.body:destroy()
            end
        end
    end

    local physics_world = context.physicsWorld
    assert(physics_world, "Asteroid instantiation requires a physicsWorld in context")

    local physics = blueprint.physics or {}
    local body_config = physics.body or {}
    local fixture_config = physics.fixture or {}

    local body_type = body_config.type or "dynamic"
    local body = love.physics.newBody(physics_world, entity.position.x, entity.position.y, body_type)
    body:setAngle(entity.rotation)
    body:setUserData(entity)

    apply_body_settings(body, body_config)

    local polygon = drawable.shape
    local shapes = create_polygon_shapes(polygon)
    local shape_count = #shapes
    local base_density = fixture_config.density or config.density or 1
    local density_per_shape = base_density
    if shape_count > 1 then
        density_per_shape = base_density / shape_count
    end

    local fixture_defaults = {
        friction = config.friction or asteroid_constants.friction or 0.85,
        restitution = config.restitution or asteroid_constants.restitution or 0.05,
    }

    local fixtures = {}
    for index = 1, shape_count do
        local fixture = love.physics.newFixture(body, shapes[index], density_per_shape)
        apply_fixture_settings(fixture, fixture_config, fixture_defaults)
        fixture:setUserData({
            type = "asteroid",
            entity = entity,
            collider = index,
        })
        fixtures[index] = fixture
    end

    entity.body = body
    entity.shape = shapes[1]
    entity.fixture = fixtures[1]
    entity.shapes = shapes
    entity.fixtures = fixtures
    entity.colliders = nil
    entity.collider = nil

    return entity
end

loader.register_factory("asteroids", asteroid_factory)

return asteroid_factory
