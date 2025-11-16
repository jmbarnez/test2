local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")
local ShipRuntime = require("src.ships.runtime")
local Culling = require("src.util.culling")
local ShipCargo = require("src.ships.cargo")
local WreckageFactory = require("src.spawners.wreckage_factory")
local table_util = require("src.util.table")
---@diagnostic disable-next-line: undefined-global
local love = love

local ship_factory = {}


local function apply_body_settings(body, body_config, stats)
    if body_config.damping then
        body:setLinearDamping(body_config.damping)
    end
    if body_config.angularDamping then
        body:setAngularDamping(body_config.angularDamping)
    end
    if body_config.fixedRotation then
        body:setFixedRotation(body_config.fixedRotation)
    end
    if body_config.gravityScale then
        body:setGravityScale(body_config.gravityScale)
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
    if fixture_config.sensor then
        fixture:setSensor(fixture_config.sensor)
    end
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
                    table_util.deep_merge(overrides, definition.overrides)
                end

                local context_override = override_by_id and override_by_id[weapon_id]
                if type(context_override) == "table" then
                    table_util.deep_merge(overrides, context_override)
                end

                if next(overrides) then
                    instantiate_context.overrides = overrides
                end
            end
        end

        if weapon_id and instantiate_context then
            local mount = instantiate_context.mount
            if mount then
                local mount_copy = table_util.deep_copy(mount)
                ShipRuntime.resolve_mount_anchor(mount_copy, entity)
                instantiate_context.mount = mount_copy
            end
            loader.instantiate("weapons", weapon_id, instantiate_context)
        end
    end
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

function ship_factory.instantiate(blueprint, context)
    assert(type(blueprint) == "table", "instantiate requires a blueprint table")
    context = context or {}

    local entity = ShipRuntime.create_entity(blueprint.components or {})
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

    -- Initialize ship runtime state (health, cargo, etc.)
    ShipRuntime.initialize(entity, constants, context)

    -- Initialize ability modules for enemies (if defined in blueprint)
    if entity.abilityModules and type(entity.abilityModules) == "table" then
        local abilityState = {}
        for i = 1, #entity.abilityModules do
            local entry = entity.abilityModules[i]
            if entry.ability and entry.key then
                abilityState[entry.key] = {
                    cooldown = 0,
                    cooldownDuration = entry.ability.cooldown or 0,
                    activeTimer = 0,
                    wasDown = false,
                }
            end
        end
        if next(abilityState) then
            entity._abilityState = abilityState
        end
    end

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

    local stats = entity.stats
    if stats then
        if stats.linear_damping then
            body:setLinearDamping(stats.linear_damping)
        end
        if stats.angular_damping then
            body:setAngularDamping(stats.angular_damping)
        end
    end
    
    -- Lock rotation - ships only rotate via player input, not collisions
    body:setFixedRotation(true)
    
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
        local shapes = ShipRuntime.create_shapes(collider_defs[index])
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

    entity.mountRadius = ShipRuntime.compute_drawable_radius(entity.drawable)
    if not entity.cullRadius then
        entity.cullRadius = Culling.computeCullRadius(entity, function(e)
            return e.mountRadius
        end)
    end

    instantiate_weapons(entity, blueprint, context)

    if entity.cargo and entity.weapons then
        ShipCargo.add_weapon_items(entity.cargo, entity.weapons, context)
        ShipCargo.refresh_if_needed(entity.cargo)
    end

    local previous_on_destroyed = entity.onDestroyed
    entity.onDestroyed = function(self, destruction_context)
        WreckageFactory.spawn(self, destruction_context)
        
        -- Track quest progress for hunting enemies
        if self.enemy and self.lastDamagePlayerId and destruction_context then
            local QuestTracker = require("src.quests.tracker")
            QuestTracker.onEnemyDestroyed(destruction_context)
        end
        
        if type(previous_on_destroyed) == "function" then
            previous_on_destroyed(self, destruction_context)
        end
    end

    return entity
end

loader.register_factory("ships", ship_factory)

return ship_factory
