local math = math

local function regular_polygon(sides, radius, offset_angle)
    local points = {}
    local step = (math.pi * 2) / sides
    local offset = offset_angle or 0

    for i = 0, sides - 1 do
        local angle = offset + step * i
        points[#points + 1] = math.cos(angle) * radius
        points[#points + 1] = math.sin(angle) * radius
    end

    return points
end

local function scale_points(points, factor)
    local scaled = {}
    for i = 1, #points do
        scaled[i] = points[i] * factor
    end
    return scaled
end

local SCALE = 0.6

local outer_radius = 320 * SCALE
local mid_radius = 220 * SCALE
local inner_radius = 120 * SCALE
local core_radius = 72 * SCALE

local base_spoke = {
    -40, -220,
    40, -220,
    48, -80,
    -48, -80,
}

local base_docking_arm = {
    -30, -120,
    30, -120,
    66, -60,
    66, 140,
    30, 180,
    -30, 180,
    -66, 140,
    -66, -60,
}

local outer_ring = regular_polygon(12, outer_radius)
local mid_ring = regular_polygon(6, mid_radius, math.pi / 6)
local inner_ring = regular_polygon(6, inner_radius)
local core_hex = regular_polygon(6, core_radius)

local spoke = scale_points(base_spoke, SCALE)
local docking_arm = scale_points(base_docking_arm, SCALE)

local collider_hex = regular_polygon(12, outer_radius * 0.95)

return {
    category = "stations",
    id = "hub_station",
    name = "Aegis Hub Station",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        station = true,
        type = "station",
        faction = "neutral",
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        mountRadius = outer_radius * 1.05,
        drawable = {
            type = "ship",
            defaultStrokeWidth = 4,
            colors = {
                hull = { 0.12, 0.16, 0.24, 1 },
                outline = { 0.05, 0.07, 0.11, 1 },
                accent = { 0.18, 0.46, 0.78, 1 },
                glow = { 0.3, 0.78, 1.0, 0.9 },
                panel = { 0.2, 0.28, 0.38, 1 },
                default = { 0.12, 0.16, 0.24, 1 },
            },
            parts = {
                {
                    name = "outer_ring",
                    type = "polygon",
                    points = outer_ring,
                    fill = "panel",
                    stroke = "outline",
                    strokeWidth = 6,
                },
                {
                    name = "mid_ring",
                    type = "polygon",
                    points = mid_ring,
                    fill = "hull",
                    stroke = "outline",
                    strokeWidth = 6,
                },
                {
                    name = "inner_ring",
                    type = "polygon",
                    points = inner_ring,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 4,
                },
                {
                    name = "core",
                    type = "polygon",
                    points = core_hex,
                    fill = "glow",
                    stroke = "accent",
                    strokeAlpha = 0.8,
                    strokeWidth = 2,
                    blend = "add",
                },
                {
                    name = "north_spoke",
                    type = "polygon",
                    points = spoke,
                    mirror = true,
                    fill = "panel",
                    stroke = "outline",
                    strokeWidth = 4,
                },
                {
                    name = "east_arm",
                    type = "polygon",
                    points = docking_arm,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 4,
                    offset = { x = 0, y = 0 },
                    rotation = math.pi / 2,
                },
                {
                    name = "west_arm",
                    type = "polygon",
                    points = docking_arm,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 4,
                    offset = { x = 0, y = 0 },
                    rotation = -math.pi / 2,
                },
            },
        },
        health = {
            current = 4000,
            max = 4000,
            showTimer = 0,
        },
        healthBar = {
            showDuration = 0,
            width = 240,
            height = 18,
            offset = 170,
        },
        stationInfluence = {
            radius = 900,
            lineWidth = 2.5,
            accentOffset = 8,
            color = { 0.18, 0.46, 0.78, 0.22 },
            accentColor = { 0.3, 0.78, 1.0, 0.35 },
            activeColor = { 0.3, 0.85, 1.0, 0.55 },
        },
        colliders = {
            {
                name = "core",
                type = "polygon",
                points = collider_hex,
            },
        },
    },
    physics = {
        body = {
            type = "static",
            fixedRotation = true,
        },
        fixture = {
            friction = 0.9,
            restitution = 0.05,
        },
    },
}
