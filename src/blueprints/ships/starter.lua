local math = math
local constants = require("src.constants.game")

local scale = 12

-- Main hull - compact symmetrical drone design
local hull_points = {
    0, -1.0 * scale,
    0.5 * scale, -0.8 * scale,
    0.8 * scale, -0.3 * scale,
    0.8 * scale, 0.3 * scale,
    0.5 * scale, 0.8 * scale,
    0, 1.0 * scale,
    -0.5 * scale, 0.8 * scale,
    -0.8 * scale, 0.3 * scale,
    -0.8 * scale, -0.3 * scale,
    -0.5 * scale, -0.8 * scale,
}

-- Energy core chamber
local core_points = {
    0, -0.5 * scale,
    0.3 * scale, -0.3 * scale,
    0.5 * scale, 0,
    0.3 * scale, 0.5 * scale,
    0, 0.6 * scale,
    -0.3 * scale, 0.5 * scale,
    -0.5 * scale, 0,
    -0.3 * scale, -0.3 * scale,
}

-- Inner energy ring
local energy_ring = {
    0, -0.3 * scale,
    0.2 * scale, -0.2 * scale,
    0.3 * scale, 0,
    0.2 * scale, 0.3 * scale,
    0, 0.4 * scale,
    -0.2 * scale, 0.3 * scale,
    -0.3 * scale, 0,
    -0.2 * scale, -0.2 * scale,
}

-- Wing extensions with angular design
local wing_left = {
    -0.8 * scale, -0.3 * scale,
    -1.2 * scale, -0.2 * scale,
    -1.3 * scale, 0.1 * scale,
    -1.1 * scale, 0.4 * scale,
    -0.8 * scale, 0.3 * scale,
}

local wing_right = {
    0.8 * scale, -0.3 * scale,
    1.2 * scale, -0.2 * scale,
    1.3 * scale, 0.1 * scale,
    1.1 * scale, 0.4 * scale,
    0.8 * scale, 0.3 * scale,
}

-- Wing accent panels
local wing_accent_left = {
    -0.9 * scale, -0.1 * scale,
    -1.1 * scale, 0,
    -1.0 * scale, 0.2 * scale,
    -0.8 * scale, 0.1 * scale,
}

local wing_accent_right = {
    0.9 * scale, -0.1 * scale,
    1.1 * scale, 0,
    1.0 * scale, 0.2 * scale,
    0.8 * scale, 0.1 * scale,
}

-- Advanced sensor array
local sensor_array = {
    0, -1.0 * scale,
    0.15 * scale, -1.1 * scale,
    0.2 * scale, -1.3 * scale,
    0, -1.4 * scale,
    -0.2 * scale, -1.3 * scale,
    -0.15 * scale, -1.1 * scale,
}

-- Rear engine nacelles
local engine_left = {
    -0.3 * scale, 0.7 * scale,
    -0.4 * scale, 0.8 * scale,
    -0.4 * scale, 1.0 * scale,
    -0.2 * scale, 0.9 * scale,
}

local engine_right = {
    0.3 * scale, 0.7 * scale,
    0.4 * scale, 0.8 * scale,
    0.4 * scale, 1.0 * scale,
    0.2 * scale, 0.9 * scale,
}

-- Front blade details
local blade_left = {
    -0.2 * scale, -0.8 * scale,
    -0.3 * scale, -0.9 * scale,
    -0.25 * scale, -1.1 * scale,
    -0.15 * scale, -0.9 * scale,
}

local blade_right = {
    0.2 * scale, -0.8 * scale,
    0.3 * scale, -0.9 * scale,
    0.25 * scale, -1.1 * scale,
    0.15 * scale, -0.9 * scale,
}

local physics_polygon = {
    0, -0.9 * scale,
    0.6 * scale, -0.6 * scale,
    0.7 * scale, -0.2 * scale,
    0.7 * scale, 0.2 * scale,
    0.4 * scale, 0.7 * scale,
    0, 0.8 * scale,
    -0.4 * scale, 0.7 * scale,
    -0.7 * scale, 0.2 * scale,
    -0.7 * scale, -0.2 * scale,
    -0.6 * scale, -0.6 * scale,
}

return {
    category = "ships",
    id = "starter",
    name = "Nebula Interceptor",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "starter_drone",
        player = true,
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        drawable = {
            type = "ship",
            hull = hull_points,
            core = core_points,
            wing_left = wing_left,
            wing_right = wing_right,
            sensor_array = sensor_array,
            hullColor = { 0.15, 0.2, 0.45 },
            wingColor = { 0.2, 0.25, 0.5 },
            trimColor = { 0.5, 0.3, 0.8 },
            colors = {
                hull = { 0.15, 0.2, 0.45, 1 },
                outline = { 0.08, 0.1, 0.25, 1 },
                plating = { 0.25, 0.3, 0.55, 1 },
                accent = { 0.4, 0.25, 0.7, 1 },
                energy = { 0.6, 0.4, 0.95, 0.9 },
                glow = { 0.7, 0.5, 1, 0.8 },
                engine = { 0.5, 0.3, 0.8, 1 },
                blade = { 0.3, 0.35, 0.65, 1 },
            },
            parts = {
                {
                    name = "hull",
                    type = "polygon",
                    points = hull_points,
                    fill = "hull",
                    stroke = "outline",
                    strokeWidth = 2.5,
                },
                {
                    name = "wing_left",
                    type = "polygon",
                    points = wing_left,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 2,
                },
                {
                    name = "wing_right",
                    type = "polygon",
                    points = wing_right,
                    fill = "plating",
                    stroke = "outline",
                    strokeWidth = 2,
                },
                {
                    name = "wing_accent_left",
                    type = "polygon",
                    points = wing_accent_left,
                    fill = "accent",
                    stroke = "glow",
                    strokeWidth = 1,
                },
                {
                    name = "wing_accent_right",
                    type = "polygon",
                    points = wing_accent_right,
                    fill = "accent",
                    stroke = "glow",
                    strokeWidth = 1,
                },
                {
                    name = "core",
                    type = "polygon",
                    points = core_points,
                    fill = "accent",
                    stroke = "glow",
                    strokeWidth = 2,
                },
                {
                    name = "energy_ring",
                    type = "polygon",
                    points = energy_ring,
                    fill = "energy",
                    stroke = "glow",
                    strokeWidth = 1.5,
                },
                {
                    name = "sensor_array",
                    type = "polygon",
                    points = sensor_array,
                    fill = "accent",
                    stroke = "glow",
                    strokeWidth = 1.5,
                },
                {
                    name = "blade_left",
                    type = "polygon",
                    points = blade_left,
                    fill = "blade",
                    stroke = "glow",
                    strokeWidth = 1,
                },
                {
                    name = "blade_right",
                    type = "polygon",
                    points = blade_right,
                    fill = "blade",
                    stroke = "glow",
                    strokeWidth = 1,
                },
                {
                    name = "engine_left",
                    type = "polygon",
                    points = engine_left,
                    fill = "engine",
                    stroke = "glow",
                    strokeWidth = 1.5,
                },
                {
                    name = "engine_right",
                    type = "polygon",
                    points = engine_right,
                    fill = "engine",
                    stroke = "glow",
                    strokeWidth = 1.5,
                },
            },
        },
        stats = {
            mass = 3,
            main_thrust = 900,
            reverse_thrust = 600,
            strafe_thrust = 600,
            rotation_torque = 2800,
            max_acceleration = 400,
            max_speed = 300,
            linear_damping = 0.3,
            angular_damping = 0.08,
        },
        hull = {
            max = 120,
            current = 120,
            regen = 0,
        },
        colliders = {
            {
                name = "hull",
                type = "polygon",
                points = physics_polygon,
            },
            {
                name = "wing_left",
                type = "polygon",
                points = wing_left,
            },
            {
                name = "wing_right",
                type = "polygon",
                points = wing_right,
            },
            {
                name = "sensor",
                type = "polygon",
                points = sensor_array,
            },
        },
    },
    weapons = {
        {
            id = "laser_basic",
            mount = {
                anchor = { x = 0, y = 0.85 },
                inset = 4,
            },
        },
    },
    physics = {
        body = {
            type = "dynamic",
            fixedRotation = false,
        },
        fixture = {
            friction = 0.25,
            restitution = 0.1,
        },
    },
}
