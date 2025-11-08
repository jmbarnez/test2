local math = math
local constants = require("src.constants.game")

local scale = 14

-- Main hull - sleek interceptor design
local hull_points = {
    0, -1.4 * scale,
    0.3 * scale, -1.2 * scale,
    0.6 * scale, -0.8 * scale,
    0.7 * scale, -0.2 * scale,
    0.4 * scale, 0.6 * scale,
    0.2 * scale, 1.2 * scale,
    0, 1.3 * scale,
    -0.2 * scale, 1.2 * scale,
    -0.4 * scale, 0.6 * scale,
    -0.7 * scale, -0.2 * scale,
    -0.6 * scale, -0.8 * scale,
    -0.3 * scale, -1.2 * scale,
}

-- Cockpit section
local cockpit_points = {
    0, -1.0 * scale,
    0.25 * scale, -0.8 * scale,
    0.35 * scale, -0.4 * scale,
    0.25 * scale, 0.1 * scale,
    0, 0.2 * scale,
    -0.25 * scale, 0.1 * scale,
    -0.35 * scale, -0.4 * scale,
    -0.25 * scale, -0.8 * scale,
}

-- Power core
local power_core = {
    0, -0.2 * scale,
    0.2 * scale, -0.1 * scale,
    0.25 * scale, 0.3 * scale,
    0, 0.4 * scale,
    -0.25 * scale, 0.3 * scale,
    -0.2 * scale, -0.1 * scale,
}

-- Delta wing left
local delta_left = {
    -0.4 * scale, -0.1 * scale,
    -1.0 * scale, 0.2 * scale,
    -1.2 * scale, 0.6 * scale,
    -0.8 * scale, 0.8 * scale,
    -0.3 * scale, 0.4 * scale,
}

-- Delta wing right
local delta_right = {
    0.4 * scale, -0.1 * scale,
    1.0 * scale, 0.2 * scale,
    1.2 * scale, 0.6 * scale,
    0.8 * scale, 0.8 * scale,
    0.3 * scale, 0.4 * scale,
}

-- Wing tips
local wingtip_left = {
    -1.0 * scale, 0.3 * scale,
    -1.3 * scale, 0.4 * scale,
    -1.2 * scale, 0.7 * scale,
    -0.9 * scale, 0.6 * scale,
}

local wingtip_right = {
    1.0 * scale, 0.3 * scale,
    1.3 * scale, 0.4 * scale,
    1.2 * scale, 0.7 * scale,
    0.9 * scale, 0.6 * scale,
}

-- Engine pods
local engine_pod_left = {
    -0.2 * scale, 0.8 * scale,
    -0.3 * scale, 1.0 * scale,
    -0.25 * scale, 1.4 * scale,
    -0.15 * scale, 1.2 * scale,
}

local engine_pod_right = {
    0.2 * scale, 0.8 * scale,
    0.3 * scale, 1.0 * scale,
    0.25 * scale, 1.4 * scale,
    0.15 * scale, 1.2 * scale,
}

-- Nose spike
local nose_spike = {
    0, -1.4 * scale,
    0.1 * scale, -1.6 * scale,
    0, -1.8 * scale,
    -0.1 * scale, -1.6 * scale,
}

-- Stabilizer fins
local fin_left = {
    -0.5 * scale, -0.6 * scale,
    -0.7 * scale, -0.7 * scale,
    -0.6 * scale, -0.9 * scale,
    -0.4 * scale, -0.8 * scale,
}

local fin_right = {
    0.5 * scale, -0.6 * scale,
    0.7 * scale, -0.7 * scale,
    0.6 * scale, -0.9 * scale,
    0.4 * scale, -0.8 * scale,
}

local physics_polygon = {
    0, -1.2 * scale,
    0.5 * scale, -0.7 * scale,
    0.6 * scale, -0.1 * scale,
    0.9 * scale, 0.4 * scale,
    0.3 * scale, 0.9 * scale,
    0, 1.1 * scale,
    -0.3 * scale, 0.9 * scale,
    -0.9 * scale, 0.4 * scale,
    -0.6 * scale, -0.1 * scale,
    -0.5 * scale, -0.7 * scale,
}

return {
    category = "ships",
    id = "starter",
    name = "Vortex Striker",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "striker_fighter",
        player = true,
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        drawable = {
            type = "ship",
            hull = hull_points,
            cockpit = cockpit_points,
            delta_left = delta_left,
            delta_right = delta_right,
            nose_spike = nose_spike,
            hullColor = { 0.2, 0.3, 0.5 },
            wingColor = { 0.25, 0.35, 0.55 },
            trimColor = { 0.6, 0.4, 0.9 },
            colors = {
                hull = { 0.2, 0.3, 0.5, 1 },
                outline = { 0.1, 0.15, 0.3, 1 },
                cockpit = { 0.15, 0.25, 0.45, 1 },
                wing = { 0.25, 0.35, 0.55, 1 },
                accent = { 0.5, 0.3, 0.8, 1 },
                core = { 0.7, 0.5, 1, 0.95 },
                engine = { 0.8, 0.4, 0.6, 1 },
                spike = { 0.3, 0.4, 0.7, 1 },
                fin = { 0.35, 0.45, 0.65, 1 },
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
                    name = "delta_left",
                    type = "polygon",
                    points = delta_left,
                    fill = "wing",
                    stroke = "outline",
                    strokeWidth = 2,
                },
                {
                    name = "delta_right",
                    type = "polygon",
                    points = delta_right,
                    fill = "wing",
                    stroke = "outline",
                    strokeWidth = 2,
                },
                {
                    name = "wingtip_left",
                    type = "polygon",
                    points = wingtip_left,
                    fill = "accent",
                    stroke = "core",
                    strokeWidth = 1.5,
                },
                {
                    name = "wingtip_right",
                    type = "polygon",
                    points = wingtip_right,
                    fill = "accent",
                    stroke = "core",
                    strokeWidth = 1.5,
                },
                {
                    name = "cockpit",
                    type = "polygon",
                    points = cockpit_points,
                    fill = "cockpit",
                    stroke = "core",
                    strokeWidth = 1.5,
                },
                {
                    name = "power_core",
                    type = "polygon",
                    points = power_core,
                    fill = "core",
                    stroke = "core",
                    strokeWidth = 2,
                },
                {
                    name = "nose_spike",
                    type = "polygon",
                    points = nose_spike,
                    fill = "spike",
                    stroke = "core",
                    strokeWidth = 1,
                },
                {
                    name = "fin_left",
                    type = "polygon",
                    points = fin_left,
                    fill = "fin",
                    stroke = "outline",
                    strokeWidth = 1,
                },
                {
                    name = "fin_right",
                    type = "polygon",
                    points = fin_right,
                    fill = "fin",
                    stroke = "outline",
                    strokeWidth = 1,
                },
                {
                    name = "engine_pod_left",
                    type = "polygon",
                    points = engine_pod_left,
                    fill = "engine",
                    stroke = "core",
                    strokeWidth = 1.5,
                },
                {
                    name = "engine_pod_right",
                    type = "polygon",
                    points = engine_pod_right,
                    fill = "engine",
                    stroke = "core",
                    strokeWidth = 1.5,
                },
            },
        },
        stats = {
            mass = 2.5,
            main_thrust = 1100,
            reverse_thrust = 700,
            strafe_thrust = 750,
            rotation_torque = 3200,
            max_acceleration = 450,
            max_speed = 350,
            linear_damping = 0.25,
            angular_damping = 0.06,
        },
        hull = {
            max = 100,
            current = 100,
            regen = 0,
        },
        colliders = {
            {
                name = "hull",
                type = "polygon",
                points = physics_polygon,
            },
            {
                name = "delta_left",
                type = "polygon",
                points = delta_left,
            },
            {
                name = "delta_right",
                type = "polygon",
                points = delta_right,
            },
            {
                name = "nose",
                type = "polygon",
                points = nose_spike,
            },
        },
    },
    weapons = {
        {
            id = "laser_basic",
            mount = {
                anchor = { x = 0, y = 1.1 },
                inset = 6,
            },
        },
    },
    physics = {
        body = {
            type = "dynamic",
            fixedRotation = false,
        },
        fixture = {
            friction = 0.2,
            restitution = 0.15,
        },
    },
}
