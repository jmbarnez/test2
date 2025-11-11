local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local math_util = require("src.util.math")
local table_util = require("src.util.table")
local Entities = require("src.states.gameplay.entities")
local PlayerManager = require("src.player.manager")
local notifications = require("src.ui.notifications")
local FloatingText = require("src.effects.floating_text")

local deep_copy = table_util.deep_copy

---@diagnostic disable-next-line: undefined-global
local love = love
local math = math
local unpack = table.unpack or unpack

local asteroid_factory = {}

local asteroid_constants = constants.asteroids or {}
local mining_xp_config = asteroid_constants.mining_xp or {}
local BASE_MINING_XP = mining_xp_config.base or 20
local CHUNK_MINING_XP = mining_xp_config.chunk or math.max(4, math.floor(BASE_MINING_XP * 0.4 + 0.5))

local function award_mining_xp(entity, destruction_context)
    if not (entity and destruction_context and BASE_MINING_XP > 0) then
        return
    end

    local state = destruction_context
    local playerId = entity.lastDamagePlayerId

    if not playerId then
        local source = entity.lastDamageSource
        if source then
            playerId = source.playerId
                or source.ownerPlayerId
                or (source.owner and source.owner.playerId)
        end
    end

    if not playerId then
        return
    end

    local chunkLevel = entity.chunkLevel or 0
    local xpAward

    if chunkLevel <= 0 then
        xpAward = BASE_MINING_XP
    else
        local chunkBase = CHUNK_MINING_XP
        local attenuation = math.max(0.25, 0.5 ^ chunkLevel)
        xpAward = math.max(2, math.floor(chunkBase * attenuation + 0.5))
    end

    if xpAward > 0 then
        PlayerManager.addSkillXP(state, "industry", "mining", xpAward, playerId)

        if notifications and state then
            notifications.push(state, {
                text = string.format("+%d Mining XP", xpAward),
                icon = "mining",
                accent = { 0.42, 0.68, 0.94, 1 },
            })
        end

        if FloatingText and state and entity.position then
            FloatingText.add(state, entity.position, string.format("+%d XP", xpAward), {
                offsetY = (entity.drawable and entity.drawable.radius or entity.radius or 28) * 0.5,
                color = { 0.42, 0.78, 1.0, 1 },
                rise = 42,
                duration = 1.4,
            })
        end
    end
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

local function destroy_body(entity)
    if entity.body and not entity.body:isDestroyed() then
        entity.body:destroy()
    end
end

local function spawn_chunk_loot(state, entity)
    local chunk_config = asteroid_constants.chunks
    local loot_drop = chunk_config and chunk_config.loot_drop

    if not (loot_drop and state and state.world and entity and entity.position) then
        return
    end

    local drop_id = loot_drop.id
    if not drop_id then
        return
    end

    local drop_count = random_range(loot_drop.count, 0)
    if not drop_count or drop_count <= 0 then
        return
    end

    local base_position = entity.position
    local base_velocity = entity.velocity
    local scatter_spec = loot_drop.scatter

    for _ = 1, drop_count do
        local quantity = random_range(loot_drop.quantity, 1) or 1
        if quantity > 0 then
            local spawn_x = base_position.x or 0
            local spawn_y = base_position.y or 0

            if scatter_spec then
                local scatter_radius = random_float_range(scatter_spec, 0) or 0
                if scatter_radius > 0 then
                    local angle = love.math.random() * math_util.TAU
                    spawn_x = spawn_x + math.cos(angle) * scatter_radius
                    spawn_y = spawn_y + math.sin(angle) * scatter_radius
                end
            end

            Entities.spawnLootPickup(state, {
                id = drop_id,
                quantity = quantity,
                position = { x = spawn_x, y = spawn_y },
                velocity = (function()
                    local vx = base_velocity and (base_velocity.x or 0) or 0
                    local vy = base_velocity and (base_velocity.y or 0) or 0
                    local speed_range = loot_drop.velocity
                    if speed_range then
                        local speed = random_float_range(speed_range, 0)
                        if speed and speed > 0 then
                            local direction = love.math.random() * math_util.TAU
                            vx = vx + math.cos(direction) * speed
                            vy = vy + math.sin(direction) * speed
                        end
                    end
                    return { x = vx, y = vy }
                end)(),
                lifetime = loot_drop.lifetime,
                collectRadius = loot_drop.collectRadius,
                size = loot_drop.size,
            })
        end
    end
end

local function spawn_chunks(entity, destruction_context)
    local chunk_config = asteroid_constants.chunks
    if not (chunk_config and chunk_config.enabled) then
        return
    end

    local state = destruction_context
    if not (state and state.world and state.physicsWorld) then
        return
    end

    spawn_chunk_loot(state, entity)

    local max_levels = chunk_config.max_levels
    if max_levels and max_levels <= 0 then
        return
    end

    local chunk_level = entity.chunkLevel or 0
    if max_levels and chunk_level >= max_levels then
        return
    end

    local position = entity.position
    if not position then
        return
    end

    local radius = entity.radius or (entity.drawable and entity.drawable.radius)
    local min_radius = chunk_config.min_radius or 0
    if not radius or radius <= min_radius then
        return
    end

    local base_health = entity.health and entity.health.max or (radius * 4)
    if base_health <= 0 then
        base_health = radius * 4
    end

    local chunk_count = random_range(chunk_config.count, 0)
    if not chunk_count or chunk_count <= 0 then
        return
    end

    local body = entity.body
    local base_vx, base_vy = 0, 0
    if body and not body:isDestroyed() then
        base_vx, base_vy = body:getLinearVelocity()
    elseif entity.velocity then
        base_vx = entity.velocity.x or 0
        base_vy = entity.velocity.y or 0
    end

    local world = state.world
    local physics_world = state.physicsWorld

    for _ = 1, chunk_count do
        local radius_scale = random_float_range(chunk_config.size_scale, 0.45) or 0.45
        if radius_scale <= 0 then
            radius_scale = 0.45
        end

        local chunk_radius = math.min(radius * 0.8, radius * radius_scale)
        chunk_radius = math.max(min_radius, chunk_radius)

        if chunk_radius <= min_radius then
            chunk_radius = min_radius
        end

        if chunk_radius <= 0 or chunk_radius >= radius then
            goto continue
        end

        local health_scale = random_float_range(chunk_config.health_scale, 0.3) or 0.3
        if health_scale <= 0 then
            health_scale = 0.3
        end

        local chunk_health = math.max(chunk_config.min_health or 1, math.floor(base_health * health_scale + 0.5))
        if chunk_health <= 0 then
            chunk_health = chunk_config.min_health or 1
        end

        local spawn_angle = love.math.random() * math_util.TAU
        local offset_distance = random_float_range(chunk_config.offset, radius * 0.3) or 0
        local spawn_x = (position.x or 0) + math.cos(spawn_angle) * offset_distance
        local spawn_y = (position.y or 0) + math.sin(spawn_angle) * offset_distance

        local instantiate_context = {
            position = { x = spawn_x, y = spawn_y },
            physicsWorld = physics_world,
            worldBounds = state.worldBounds,
            chunkLevel = chunk_level + 1,
            config = {
                radius = chunk_radius,
                durability = chunk_health,
                color = entity.drawable and entity.drawable.color,
            },
        }

        local chunk_entity = loader.instantiate("asteroids", "default", instantiate_context)
        if chunk_entity then
            chunk_entity.radius = chunk_radius

            if chunk_entity.health then
                chunk_entity.health.max = chunk_health
                chunk_entity.health.current = chunk_health
                chunk_entity.health.showTimer = 0
            end

            if chunk_config.inherit_loot then
                if entity.loot then
                    chunk_entity.loot = deep_copy(entity.loot)
                elseif asteroid_constants.loot then
                    chunk_entity.loot = deep_copy(asteroid_constants.loot)
                end
            else
                chunk_entity.loot = nil
            end

            local travel_angle = spawn_angle + (love.math.random() - 0.5) * 0.6
            local speed = math.abs(random_float_range(chunk_config.speed, 120) or 120)
            local velocity_x = base_vx + math.cos(travel_angle) * speed
            local velocity_y = base_vy + math.sin(travel_angle) * speed

            if chunk_entity.velocity then
                chunk_entity.velocity.x = velocity_x
                chunk_entity.velocity.y = velocity_y
            end

            if chunk_entity.body and not chunk_entity.body:isDestroyed() then
                chunk_entity.body:setLinearVelocity(velocity_x, velocity_y)
                local angular_velocity = random_float_range(chunk_config.angular_velocity, 0) or 0
                chunk_entity.body:setAngularVelocity(angular_velocity)
            end

            world:add(chunk_entity)
        end

        ::continue::
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
    entity.chunkLevel = context.chunkLevel or entity.chunkLevel or 0
    entity.armorType = entity.armorType or "rock"

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

    local previous_on_destroyed = entity.onDestroyed or destroy_body
    entity.onDestroyed = function(self, destruction_context)
        award_mining_xp(self, destruction_context)
        spawn_chunks(self, destruction_context)
        if previous_on_destroyed then
            previous_on_destroyed(self, destruction_context)
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
