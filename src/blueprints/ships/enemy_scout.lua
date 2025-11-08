local constants = require("src.constants.game")

local scale = 12

local hull_points = {
    0, -1.2 * scale,
    0.9 * scale, -0.1 * scale,
    0.5 * scale, 1.1 * scale,
    -0.5 * scale, 1.1 * scale,
    -0.9 * scale, -0.1 * scale,
}

local core_points = {
    0, -0.9 * scale,
    0.45 * scale, -0.2 * scale,
    0.3 * scale, 0.6 * scale,
    -0.3 * scale, 0.6 * scale,
    -0.45 * scale, -0.2 * scale,
}

local engine_points = {
    -0.35 * scale, 0.9 * scale,
    0.35 * scale, 0.9 * scale,
    0, 1.4 * scale,
}

local physics_polygon = {
    0, -1.0 * scale,
    0.8 * scale, -0.05 * scale,
    0.45 * scale, 0.9 * scale,
    -0.45 * scale, 0.9 * scale,
    -0.8 * scale, -0.05 * scale,
}

return {
    category = "ships",
    id = "enemy_scout",
    name = "Enemy Scout",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "enemy_scout",
        enemy = true,
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        drawable = {
            type = "ship",
            parts = {
                {
                    name = "hull",
                    type = "polygon",
                    points = hull_points,
                    fill = { 0.65, 0.18, 0.22, 1 },
                    stroke = { 0.9, 0.4, 0.45, 1 },
                    strokeWidth = 2,
                },
                {
                    name = "core",
                    type = "polygon",
                    points = core_points,
                    fill = { 0.8, 0.3, 0.35, 1 },
                    stroke = { 1, 0.55, 0.6, 1 },
                    strokeWidth = 1,
                },
                {
                    name = "engine",
                    type = "polygon",
                    points = engine_points,
                    fill = { 1, 0.6, 0.2, 0.85 },
                    stroke = { 1, 0.75, 0.4, 0.9 },
                    strokeWidth = 1,
                },
            },
        },
        stats = {
            mass = 4,
            main_thrust = 150,
            strafe_thrust = 95,
            reverse_thrust = 110,
            rotation_torque = 780,
            max_acceleration = 100,
            max_speed = 160,
            linear_damping = 0.36,
            angular_damping = 0.1,
        },
        hull = {
            max = 120,
            current = 120,
            regen = 0,
        },
        health = {
            max = 90,
            current = 90,
        },
        ai = {
            behavior = "hunter",
            targetTag = "player",
            engagementRange = 720,
            fireArc = math.pi / 6,
            preferredDistance = 360,
        },
        colliders = {
            {
                name = "hull",
                type = "polygon",
                points = physics_polygon,
            },
        },
    },
    weapons = {
        {
            id = "laser_beam",
            overrides = {
                weapon = {
                    damagePerSecond = constants.weapons.laser.damage_per_second * 0.6,
                    offset = 1.2 * scale,
                    color = { 1, 0.2, 0.25 },
                    glowColor = { 1, 0.45, 0.5 },
                    alwaysFire = false,
                },
                weaponMount = {
                    anchor = { x = 0, y = 1.0 },
                    inset = 0,
                },
            },
        },
    },
    physics = {
        body = {
            type = "dynamic",
            fixedRotation = false,
        },
        fixture = {
            density = 1,
            friction = 0.3,
            restitution = 0.15,
        },
    },
}
