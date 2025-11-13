local math_util = require("src.util.math")

---@diagnostic disable-next-line: undefined-global
local love = love

local ShipWreckage = {}

local unpack = table.unpack or unpack

local DEFAULT_COLORS = {
    { 0.35, 0.45, 0.55, 1.0 },
    { 0.42, 0.52, 0.62, 1.0 },
    { 0.28, 0.32, 0.40, 1.0 },
}

local palette_keys = {
    "hull",
    "accent",
    "trim",
    "wing",
    "fin",
    "engine",
    "core",
    "default",
}

local function jitter_color(color, variation)
    color = color or DEFAULT_COLORS[1]
    local v = variation or 0.12

    local r = math_util.clamp((color[1] or 0.5) * (1 + (love.math.random() * 2 - 1) * v), 0, 1)
    local g = math_util.clamp((color[2] or 0.5) * (1 + (love.math.random() * 2 - 1) * v), 0, 1)
    local b = math_util.clamp((color[3] or 0.5) * (1 + (love.math.random() * 2 - 1) * v), 0, 1)
    local a = math_util.clamp(color[4] or 1, 0, 1)

    return { r, g, b, a }
end

local function choose_palette_color(palette)
    if type(palette) ~= "table" then
        return jitter_color(DEFAULT_COLORS[love.math.random(1, #DEFAULT_COLORS)])
    end

    local options = {}
    for _, key in ipairs(palette_keys) do
        local value = palette[key]
        if type(value) == "table" and #value >= 3 then
            options[#options + 1] = value
        end
    end

    if #options == 0 then
        for _, value in pairs(palette) do
            if type(value) == "table" and #value >= 3 then
                options[#options + 1] = value
            end
        end
    end

    if #options == 0 then
        return jitter_color(DEFAULT_COLORS[love.math.random(1, #DEFAULT_COLORS)])
    end

    return jitter_color(options[love.math.random(1, #options)])
end

local function generate_polygon(max_radius)
    local sides = love.math.random(3, 5)
    local base_step = math_util.TAU / sides
    local start_angle = love.math.random() * math_util.TAU
    local jitter = base_step * 0.45

    local points = {}
    for i = 0, sides - 1 do
        local angle = start_angle + base_step * i + (love.math.random() - 0.5) * jitter
        local radius = max_radius * (0.65 + love.math.random() * 0.4)
        points[#points + 1] = math.cos(angle) * radius
        points[#points + 1] = math.sin(angle) * radius
    end

    return points
end

local function random_between(min_value, max_value)
    if min_value > max_value then
        min_value, max_value = max_value, min_value
    end
    local span = max_value - min_value
    if span <= 0 then
        return min_value
    end
    return min_value + love.math.random() * span
end

local function compute_reference_radius(entity)
    if entity.mountRadius and entity.mountRadius > 0 then
        return entity.mountRadius
    end

    local hull = entity.hullSize
    if type(hull) == "table" then
        local size_x = math.abs(hull.x or 0)
        local size_y = math.abs(hull.y or 0)
        local avg = (size_x + size_y) * 0.25
        if avg > 0 then
            return avg
        end
    end

    local collider = entity.collider
    if type(collider) == "table" and type(collider.radius) == "number" then
        return collider.radius
    end

    return 26
end

local function collect_palette(entity)
    if entity.drawable and type(entity.drawable.colors) == "table" then
        return entity.drawable.colors
    end
    return nil
end

local function gather_base_motion(entity)
    local vx, vy = 0, 0
    local angular = 0

    local body = entity.body
    if body and not body:isDestroyed() then
        vx, vy = body:getLinearVelocity()
        angular = body:getAngularVelocity()
    elseif entity.velocity then
        vx = entity.velocity.x or 0
        vy = entity.velocity.y or 0
    end

    return vx, vy, angular
end

local function compute_reference_area(entity, radius)
    local hull = entity.hullSize
    if type(hull) == "table" and (hull.x or 0) ~= 0 and (hull.y or 0) ~= 0 then
        return math.abs((hull.x or 0) * (hull.y or 0))
    end

    return math.pi * radius * radius
end

local function build_scrap_loot(piece_radius)
    local min_quantity = math.max(1, math.floor(piece_radius * 0.08 + 0.5))
    local max_quantity = math.max(min_quantity, math.floor(piece_radius * 0.12 + 1))

    return {
        rolls = 1,
        entries = {
            {
                id = "resource:hull_scrap",
                quantity = {
                    min = min_quantity,
                    max = max_quantity,
                },
                chance = 1,
                scatter = piece_radius * 0.35,
            },
        },
    }
end

local function create_wreckage_piece(context, params)
    local position = params.position
    local polygon = params.polygon

    local physics_world = context.physicsWorld
    if not physics_world then
        return
    end

    local body = love.physics.newBody(physics_world, position.x, position.y, "dynamic")
    local rotation = params.rotation
    body:setAngle(rotation)
    body:setLinearDamping(params.linearDamping)
    body:setAngularDamping(params.angularDamping)
    body:setLinearVelocity(params.velocity.x, params.velocity.y)
    body:setAngularVelocity(params.angularVelocity)

    local shape = love.physics.newPolygonShape(unpack(polygon))
    local density = math_util.clamp(params.density or 0.35, 0.05, 6)
    local fixture = love.physics.newFixture(body, shape, density)
    fixture:setFriction(0.85)
    fixture:setRestitution(0.08)

    local radius = params.pieceRadius or 12
    local baseHealth = math_util.clamp((radius * 0.9) + 12, 18, 140)
    local health = params.health or baseHealth

    local piece_radius = params.pieceRadius or 16

    local health_bar_config = params.healthBar or {}
    local health_bar = {
        width = health_bar_config.width or (piece_radius * 1.8),
        height = health_bar_config.height or 5,
        offset = health_bar_config.offset or (piece_radius + 8),
        showDuration = health_bar_config.showDuration or health_bar_config.show_duration or 1.5,
    }

    local entity = {
        position = { x = position.x, y = position.y },
        velocity = { x = params.velocity.x, y = params.velocity.y },
        rotation = rotation,
        health = {
            current = health,
            max = health,
            showTimer = 0,
        },
        healthBar = health_bar,
        drawable = {
            type = "wreckage",
            polygon = polygon,
            color = params.fillColor,
            outline = params.outlineColor,
            alpha = 1,
            lineWidth = params.lineWidth,
        },
        wreckage = {
            lifetime = params.lifetime,
            fadeDuration = params.fadeDuration,
            age = 0,
            alpha = 1,
            pieceRadius = piece_radius,
        },
        loot = params.loot,
        armorType = "wreckage",
        mass = params.density or 0.5,
        body = body,
        shape = shape,
        fixture = fixture,
    }

    body:setUserData(entity)
    fixture:setUserData({ type = "wreckage", entity = entity })

    entity.onDamaged = function(target, amount)
        if not target.health then
            return
        end
        target.health.current = math.max(0, (target.health.current or target.health.max or 0) - amount)
        if target.healthBar then
            target.health.showTimer = target.healthBar.showDuration or 0
        end

        if target.health.current <= 0 then
            target.pendingDestroy = true
        end
    end

    entity.onDestroyed = function(target)
    end

    context.world:add(entity)
end

function ShipWreckage.spawn(ship, context)
    if not (ship and context and context.world and context.physicsWorld) then
        return
    end

    local palette = collect_palette(ship)
    local radius = math.max(12, compute_reference_radius(ship))
    local reference_area = compute_reference_area(ship, radius)
    local base_position = ship.position or { x = 0, y = 0 }

    local vx, vy, angular_velocity = gather_base_motion(ship)

    local piece_count = love.math.random(2, 4)
    local weights = {}
    local weight_sum = 0

    for i = 1, piece_count do
        local weight = 1.1 + love.math.random() * 1.2
        weights[i] = weight
        weight_sum = weight_sum + weight
    end

    if weight_sum <= 0 then
        return
    end

    local offset_radius = radius * 0.55
    local min_piece_radius = radius * 0.45

    for i = 1, piece_count do
        local area_share = reference_area * (weights[i] / weight_sum)
        local nominal_radius = math.sqrt(math.abs(area_share) / math.pi)
        local piece_radius = math_util.clamp(nominal_radius * random_between(0.85, 1.25), min_piece_radius, radius * 0.95)

        local polygon = generate_polygon(piece_radius)

        local angle = love.math.random() * math_util.TAU
        local distance = random_between(piece_radius * 0.5, offset_radius)
        local px = (base_position.x or 0) + math.cos(angle) * distance
        local py = (base_position.y or 0) + math.sin(angle) * distance

        local scatter_speed = random_between(60, 180)
        local scatter_angle = angle + (love.math.random() - 0.5) * 0.9

        local velocity = {
            x = vx + math.cos(scatter_angle) * scatter_speed,
            y = vy + math.sin(scatter_angle) * scatter_speed,
        }

        local rotation = love.math.random() * math_util.TAU
        local angular = angular_velocity + random_between(-5.5, 5.5)

        local fill_color = choose_palette_color(palette)
        local outline_color = {
            math_util.clamp(fill_color[1] * 0.55, 0, 1),
            math_util.clamp(fill_color[2] * 0.55, 0, 1),
            math_util.clamp(fill_color[3] * 0.55, 0, 1),
            fill_color[4] or 1,
        }

        local density = math_util.clamp(piece_radius * 0.12, 0.08, 4)

        local pieceHealth = math_util.clamp((piece_radius * 1.25) + 24, 30, 200)

        create_wreckage_piece(context, {
            position = { x = px, y = py },
            polygon = polygon,
            rotation = rotation,
            velocity = velocity,
            angularVelocity = angular,
            linearDamping = random_between(2.2, 3.3),
            angularDamping = random_between(1.8, 2.6),
            density = density,
            lifetime = random_between(4.2, 6.5),
            fadeDuration = random_between(1.2, 1.9),
            fillColor = fill_color,
            outlineColor = outline_color,
            lineWidth = math_util.clamp(piece_radius * 0.12, 1.2, 2.4),
            pieceRadius = piece_radius,
            health = pieceHealth,
            loot = build_scrap_loot(piece_radius),
        })
    end
end

return ShipWreckage
