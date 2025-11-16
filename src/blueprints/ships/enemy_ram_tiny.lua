local constants = require("src.constants.game")

local scale = 5.5

local hull_points = {
    0, -1.4 * scale,
    0.9 * scale, 0.2 * scale,
    0, 1.1 * scale,
    -0.9 * scale, 0.2 * scale,
}

local core_points = {
    0, -0.7 * scale,
    0.45 * scale, 0.1 * scale,
    0, 0.6 * scale,
    -0.45 * scale, 0.1 * scale,
}

local fin_points = {
    -0.55 * scale, 0.25 * scale,
    -1.0 * scale, -0.35 * scale,
    -0.35 * scale, -0.65 * scale,
}

local thruster_points = {
    -0.25 * scale, 0.7 * scale,
    0.25 * scale, 0.7 * scale,
    0, 1.35 * scale,
}

local physics_polygon = {
    0, -1.3 * scale,
    0.85 * scale, 0.1 * scale,
    0, 0.95 * scale,
    -0.85 * scale, 0.1 * scale,
}

return {
    category = "ships",
    id = "enemy_ram_tiny",
    name = "Needle Rammer",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "enemy_ram_tiny",
        enemy = true,
        level = {
            base = 1,
            current = 1,
        },
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        drawable = {
            type = "ship",
            colors = {
                hull = { 0.42, 0.05, 0.1, 1 },
                accent = { 0.7, 0.1, 0.16, 1 },
                trim = { 0.18, 0.02, 0.05, 1 },
                core = { 0.95, 0.45, 0.25, 1 },
                thruster = { 1.0, 0.58, 0.32, 0.92 },
            },
            parts = {
                {
                    name = "hull",
                    type = "polygon",
                    points = hull_points,
                    fill = "hull",
                    stroke = "trim",
                    strokeWidth = 1.6,
                },
                {
                    name = "core",
                    type = "polygon",
                    points = core_points,
                    fill = "core",
                    stroke = { 1.0, 0.75, 0.4, 0.85 },
                    strokeWidth = 1.2,
                },
                {
                    name = "fin_left",
                    type = "polygon",
                    points = fin_points,
                    fill = "accent",
                    stroke = "trim",
                    strokeWidth = 1.1,
                },
                {
                    name = "fin_right",
                    type = "polygon",
                    points = fin_points,
                    mirror = true,
                    fill = "accent",
                    stroke = "trim",
                    strokeWidth = 1.1,
                },
                {
                    name = "thruster",
                    type = "polygon",
                    points = thruster_points,
                    fill = "thruster",
                    stroke = { 1.0, 0.8, 0.5, 0.95 },
                    strokeWidth = 1.0,
                },
            },
        },
        stats = {
            mass = 28,
            main_thrust = 380,
            strafe_thrust = 120,
            reverse_thrust = 90,
            max_acceleration = 760,
            max_speed = 340,
            linear_damping = 0.22,
            angular_damping = 0.12,
        },
        hull = {
            max = 35,
            current = 35,
            regen = 0,
        },
        health = {
            max = 70,
            current = 70,
        },
        ai = {
            behavior = "rammer",
            targetTag = "player",
            detectionRange = 720,
            engagementRange = 720,
            aggression = 1.0,
            ramDamage = 45,
            ramCooldown = 3,
            ramSpeed = 340,
            ramAcceleration = 780,
            ramMaxSpeed = 360,
            ramCooldownDamping = 8,
        },
        colliders = {
            {
                name = "hull",
                type = "polygon",
                points = physics_polygon,
            },
        },
        loot = {
            entries = {
                {
                    credit_reward = constants.enemies.credit_rewards.enemy_ram_tiny,
                    xp_reward = constants.enemies.xp_rewards.enemy_ram_tiny,
                },
            },
        },
    },
}
