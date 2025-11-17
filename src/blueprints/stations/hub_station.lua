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

local SCALE = 0.7

local outer_radius = 360 * SCALE
local trim_radius = outer_radius * 0.92
local walkway_radius = outer_radius * 0.82
local mid_radius = 280 * SCALE
local inner_radius = 190 * SCALE
local energy_radius = inner_radius * 0.78
local core_radius = 95 * SCALE

local base_spoke = {
    -48, -300,
    48, -300,
    78, -110,
    -78, -110,
}

local base_docking_arm = {
    -34, -170,
    34, -170,
    60, -40,
    60, 240,
    26, 278,
    -26, 278,
    -60, 240,
    -60, -40,
}

local base_hab_pod = {
    -72, -70,
    -36, -132,
    36, -132,
    72, -70,
    52, 44,
    -52, 44,
}

local base_comm_array = {
    -14, -96,
    0, -138,
    14, -96,
    10, -54,
    -10, -54,
}

local base_light_panel = {
    -18, -24,
    18, -24,
    22, 24,
    -22, 24,
}

local outer_ring = regular_polygon(24, outer_radius)
local trim_ring = regular_polygon(24, trim_radius)
local walkway_band = regular_polygon(24, walkway_radius)
local accent_ring = regular_polygon(12, mid_radius)
local inner_ring = regular_polygon(12, inner_radius)
local energy_ring = regular_polygon(18, energy_radius)
local core_hex = regular_polygon(6, core_radius)
local core_inset = regular_polygon(6, core_radius * 0.68)

local spoke = scale_points(base_spoke, SCALE)
local docking_arm = scale_points(base_docking_arm, SCALE)
local hab_pod = scale_points(base_hab_pod, SCALE)
local comm_array = scale_points(base_comm_array, SCALE)
local light_panel = scale_points(base_light_panel, SCALE)

local collider_hex = regular_polygon(24, outer_radius * 0.94)

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
        mountRadius = outer_radius * 1.08,
        drawable = {
            type = "ship",
            defaultStrokeWidth = 4,
            colors = {
                hull = { 0.08, 0.12, 0.18, 1 },
                plating = { 0.16, 0.21, 0.28, 1 },
                outline = { 0.03, 0.05, 0.08, 1 },
                accent = { 0.24, 0.64, 0.89, 1 },
                glow = { 0.42, 0.82, 1.0, 0.85 },
                core = { 0.58, 0.9, 1.0, 0.65 },
                hazard = { 0.92, 0.56, 0.22, 0.9 },
                beacon = { 0.52, 0.88, 1.0, 0.75 },
            },
            parts = {
                {
                    name = "outer_frame",
                    type = "polygon",
                    points = outer_ring,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 6,
                },
                {
                    name = "outer_trim",
                    type = "polygon",
                    points = trim_ring,
                    fill = "hull",
                    stroke = "accent",
                    strokeWidth = 4,
                },
                {
                    name = "walkway_band",
                    type = "polygon",
                    points = walkway_band,
                    fill = "hull",
                    stroke = "outline",
                    strokeWidth = 2.5,
                },
                {
                    name = "accent_ring",
                    type = "polygon",
                    points = accent_ring,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 3,
                },
                {
                    name = "inner_plate",
                    type = "polygon",
                    points = inner_ring,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 2.5,
                },
                {
                    name = "energy_ring",
                    type = "polygon",
                    points = energy_ring,
                    fill = "glow",
                    stroke = "accent",
                    strokeWidth = 1.6,
                    blend = "add",
                },
                {
                    name = "core_shell",
                    type = "polygon",
                    points = core_hex,
                    fill = "core",
                    stroke = "accent",
                    strokeAlpha = 0.85,
                    strokeWidth = 2,
                    blend = "add",
                },
                {
                    name = "core_matrix",
                    type = "polygon",
                    points = core_inset,
                    fill = "hull",
                    stroke = "accent",
                    strokeWidth = 1.2,
                },
                {
                    name = "core_emitter",
                    type = "ellipse",
                    centerX = 0,
                    centerY = 0,
                    radiusX = core_radius * 0.56,
                    radiusY = core_radius * 0.56,
                    fill = "glow",
                    stroke = false,
                    blend = "add",
                },
                {
                    name = "north_spoke",
                    type = "polygon",
                    points = spoke,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 4,
                },
                {
                    name = "east_spoke",
                    type = "polygon",
                    points = spoke,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 4,
                    rotation = math.pi / 2,
                },
                {
                    name = "south_spoke",
                    type = "polygon",
                    points = spoke,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 4,
                    rotation = math.pi,
                },
                {
                    name = "west_spoke",
                    type = "polygon",
                    points = spoke,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 4,
                    rotation = -math.pi / 2,
                },
                {
                    name = "north_arm",
                    type = "polygon",
                    points = docking_arm,
                    fill = "accent",
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
                    rotation = math.pi / 2,
                },
                {
                    name = "south_arm",
                    type = "polygon",
                    points = docking_arm,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 4,
                    rotation = math.pi,
                },
                {
                    name = "west_arm",
                    type = "polygon",
                    points = docking_arm,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 4,
                    rotation = -math.pi / 2,
                },
                {
                    name = "north_hab_pod",
                    type = "polygon",
                    points = hab_pod,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 3,
                    offset = { x = 0, y = outer_radius * 0.58 },
                },
                {
                    name = "south_hab_pod",
                    type = "polygon",
                    points = hab_pod,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 3,
                    rotation = math.pi,
                    offset = { x = 0, y = -outer_radius * 0.58 },
                },
                {
                    name = "east_hab_pod",
                    type = "polygon",
                    points = hab_pod,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 3,
                    rotation = math.pi / 2,
                    offset = { x = outer_radius * 0.58, y = 0 },
                },
                {
                    name = "west_hab_pod",
                    type = "polygon",
                    points = hab_pod,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 3,
                    rotation = -math.pi / 2,
                    offset = { x = -outer_radius * 0.58, y = 0 },
                },
                {
                    name = "north_comm",
                    type = "polygon",
                    points = comm_array,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 2,
                    offset = { x = outer_radius * 0.38, y = -outer_radius * 0.08 },
                },
                {
                    name = "south_comm",
                    type = "polygon",
                    points = comm_array,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 2,
                    rotation = math.pi,
                    offset = { x = -outer_radius * 0.38, y = outer_radius * 0.08 },
                },
                {
                    name = "east_comm",
                    type = "polygon",
                    points = comm_array,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 2,
                    rotation = math.pi / 2,
                    offset = { x = outer_radius * 0.08, y = outer_radius * 0.38 },
                },
                {
                    name = "west_comm",
                    type = "polygon",
                    points = comm_array,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 2,
                    rotation = -math.pi / 2,
                    offset = { x = -outer_radius * 0.08, y = -outer_radius * 0.38 },
                },
                {
                    name = "north_light",
                    type = "polygon",
                    points = light_panel,
                    fill = "beacon",
                    stroke = "outline",
                    strokeWidth = 1.4,
                    offset = { x = 0, y = outer_radius * 0.38 },
                },
                {
                    name = "south_light",
                    type = "polygon",
                    points = light_panel,
                    fill = "beacon",
                    stroke = "outline",
                    strokeWidth = 1.4,
                    rotation = math.pi,
                    offset = { x = 0, y = -outer_radius * 0.38 },
                },
                {
                    name = "east_light",
                    type = "polygon",
                    points = light_panel,
                    fill = "beacon",
                    stroke = "outline",
                    strokeWidth = 1.4,
                    rotation = math.pi / 2,
                    offset = { x = outer_radius * 0.38, y = 0 },
                },
                {
                    name = "west_light",
                    type = "polygon",
                    points = light_panel,
                    fill = "beacon",
                    stroke = "outline",
                    strokeWidth = 1.4,
                    rotation = -math.pi / 2,
                    offset = { x = -outer_radius * 0.38, y = 0 },
                },
                {
                    name = "hazard_markers",
                    type = "polygon",
                    points = regular_polygon(8, walkway_radius * 0.46, math.pi / 8),
                    fill = "hazard",
                    stroke = "outline",
                    strokeWidth = 1.2,
                    blend = "add",
                },
                {
                    name = "perimeter_glow",
                    type = "ellipse",
                    centerX = 0,
                    centerY = 0,
                    radiusX = outer_radius * 0.98,
                    radiusY = outer_radius * 0.98,
                    fill = { 0.25, 0.6, 0.95, 0.18 },
                    stroke = false,
                    blend = "add",
                },
            },
        },
        health = {
            current = 4800,
            max = 4800,
            showTimer = 0,
        },
        shield = {
            current = 14000,
            max = 14000,
            regen = 12,
            rechargeDelay = 4,
        },
        healthBar = {
            showDuration = 0,
            width = 280,
            height = 20,
            offset = 190,
        },
        stationInfluence = {
            radius = 940,
            lineWidth = 2.5,
            accentOffset = 10,
            color = { 0.22, 0.52, 0.86, 0.22 },
            accentColor = { 0.35, 0.82, 1.0, 0.36 },
            activeColor = { 0.45, 0.92, 1.0, 0.58 },
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
