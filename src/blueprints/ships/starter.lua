local scale = 14

local body_hull = {
    0, -1.2 * scale,
    0.85 * scale, -0.35 * scale,
    0.6 * scale, 0.55 * scale,
    0.15 * scale, 1.1 * scale,
    -0.15 * scale, 1.1 * scale,
    -0.6 * scale, 0.55 * scale,
    -0.85 * scale, -0.35 * scale,
}

local core_plate = {
    0, -0.78 * scale,
    0.42 * scale, -0.22 * scale,
    0.28 * scale, 0.36 * scale,
    -0.28 * scale, 0.36 * scale,
    -0.42 * scale, -0.22 * scale,
}

local wing_left = {
    -0.52 * scale, -0.18 * scale,
    -1.05 * scale, 0.05 * scale,
    -0.72 * scale, 0.58 * scale,
    -0.38 * scale, 0.3 * scale,
}

local wing_right = {
    0.52 * scale, -0.18 * scale,
    1.05 * scale, 0.05 * scale,
    0.72 * scale, 0.58 * scale,
    0.38 * scale, 0.3 * scale,
}

local antenna = {
    -0.1 * scale, -1.2 * scale,
    0, -1.45 * scale,
    0.1 * scale, -1.2 * scale,
}

local thruster = {
    -0.28 * scale, 0.75 * scale,
    0.28 * scale, 0.75 * scale,
    0.18 * scale, 1.25 * scale,
    -0.18 * scale, 1.25 * scale,
}

local engine_glow = {
    -0.22 * scale, 0.78 * scale,
    0.22 * scale, 0.78 * scale,
    0, 1.28 * scale,
}

local physics_polygon = {
    0, -1.15 * scale,
    0.75 * scale, -0.32 * scale,
    0.52 * scale, 0.55 * scale,
    0.12 * scale, 1.05 * scale,
    -0.12 * scale, 1.05 * scale,
    -0.52 * scale, 0.55 * scale,
    -0.75 * scale, -0.32 * scale,
}

return {
    category = "ships",
    id = "starter",
    name = "Aurora Scout Drone",
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
        hullSize = { x = 28, y = 30 },
        thrusterOffset = 0,
        engineTrailAnchor = { x = 0, y = 0.8 * scale },
        drawable = {
            type = "ship",
            hull = body_hull,
            colors = {
                hull = { 0.07, 0.16, 0.22, 1 },
                outline = { 0.03, 0.07, 0.12, 1 },
                accent = { 0.18, 0.4, 0.55, 1 },
                trim = { 0.28, 0.58, 0.72, 1 },
                core = { 0.52, 0.85, 1.0, 0.92 },
                glow = { 0.35, 0.7, 1.0, 0.45 },
                engine = { 0.38, 0.8, 1.0, 0.8 },
            },
            parts = {
                {
                    name = "hull",
                    type = "polygon",
                    points = body_hull,
                    fill = "hull",
                    stroke = "outline",
                    strokeWidth = 2.1,
                },
                {
                    name = "wing_left",
                    type = "polygon",
                    points = wing_left,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 1.4,
                },
                {
                    name = "wing_right",
                    type = "polygon",
                    points = wing_right,
                    fill = "accent",
                    stroke = "outline",
                    strokeWidth = 1.4,
                },
                {
                    name = "core",
                    type = "polygon",
                    points = core_plate,
                    fill = "core",
                    stroke = "trim",
                    strokeWidth = 1.1,
                },
                {
                    name = "antenna",
                    type = "polygon",
                    points = antenna,
                    fill = "trim",
                    stroke = "outline",
                    strokeWidth = 1.2,
                },
                {
                    name = "thruster",
                    type = "polygon",
                    points = thruster,
                    fill = "engine",
                    stroke = "outline",
                    strokeWidth = 1.2,
                },
                {
                    name = "engine_glow",
                    type = "polygon",
                    points = engine_glow,
                    fill = "glow",
                    stroke = false,
                    blend = "add",
                },
                {
                    name = "core_glow",
                    type = "ellipse",
                    centerX = 0,
                    centerY = -0.1 * scale,
                    radiusX = 0.22 * scale,
                    radiusY = 0.24 * scale,
                    fill = { 0.48, 0.82, 1.0, 0.32 },
                    stroke = false,
                    blend = "add",
                },
            },
        },
        stats = {
            mass = 1.3,
            main_thrust = 90,
            reverse_thrust = 55,
            strafe_thrust = 60,
            max_acceleration = 135,
            max_speed = 180,
            linear_damping = 0.7,
            angular_damping = 0.2,
            targetingTime = 1.4,
        },
        energy = {
            max = 110,
            current = 110,
            regen = 40,
            rechargeDelay = 1.0,
            thrustDrain = 34,
        },
        cargo = {
            capacity = 24,
            items = {
                { weapon = "laser_turret" },
            },
        },
        magnet = {
            radius = 220,
            strength = 280,
            falloff = 0.6,
            collectRadius = 24,
        },
        hull = {
            max = 65,
            current = 65,
            regen = 0,
        },
        shield = {
            max = 35,
            current = 35,
            regen = 1.5,
            rechargeDelay = 5.5,
        },
        modules = {
            defaultType = "utility",
            slots = {
                { type = "utility" },
                { type = "ability" },
            },
        },
        colliders = {
            {
                name = "hull",
                type = "polygon",
                points = physics_polygon,
            },
        },
    },
    weapons = {},
    physics = {
        body = {
            type = "dynamic",
        },
        fixture = {
            friction = 0.16,
            restitution = 0.1,
        },
    },
}
