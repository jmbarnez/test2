local constants = require("src.constants.game")

local scale = 8

local hull_points = {
    0, -1.1 * scale,
    0.9 * scale, -0.1 * scale,
    0.55 * scale, 0.9 * scale,
    0, 1.1 * scale,
    -0.55 * scale, 0.9 * scale,
    -0.9 * scale, -0.1 * scale,
}

local core_points = {
    0, -0.75 * scale,
    0.45 * scale, -0.1 * scale,
    0.25 * scale, 0.45 * scale,
    -0.25 * scale, 0.45 * scale,
    -0.45 * scale, -0.1 * scale,
}

local wing_points_left = {
    -0.6 * scale, -0.2 * scale,
    -1.2 * scale, 0.1 * scale,
    -0.7 * scale, 0.55 * scale,
}

local wing_points_right = {
    0.6 * scale, -0.2 * scale,
    1.2 * scale, 0.1 * scale,
    0.7 * scale, 0.55 * scale,
}

local thruster_points = {
    -0.3 * scale, 0.8 * scale,
    0.3 * scale, 0.8 * scale,
    0, 1.3 * scale,
}

local physics_polygon = {
    0, -1.0 * scale,
    0.8 * scale, -0.05 * scale,
    0.5 * scale, 0.85 * scale,
    0, 1.15 * scale,
    -0.5 * scale, 0.85 * scale,
    -0.8 * scale, -0.05 * scale,
}

return {
    category = "ships",
    id = "enemy_drone",
    name = "Enemy Drone",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "enemy_drone",
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
                    fill = { 0.5, 0.08, 0.08, 1 },
                    stroke = { 0.85, 0.16, 0.2, 1 },
                    strokeWidth = 2,
                },
                {
                    name = "core",
                    type = "polygon",
                    points = core_points,
                    fill = { 0.22, 0.05, 0.08, 1 },
                    stroke = { 0.55, 0.12, 0.16, 1 },
                    strokeWidth = 1,
                },
                {
                    name = "wing_left",
                    type = "polygon",
                    points = wing_points_left,
                    fill = { 0.42, 0.06, 0.08, 0.95 },
                    stroke = { 0.78, 0.14, 0.18, 1 },
                    strokeWidth = 1,
                },
                {
                    name = "wing_right",
                    type = "polygon",
                    points = wing_points_right,
                    fill = { 0.42, 0.06, 0.08, 0.95 },
                    stroke = { 0.78, 0.14, 0.18, 1 },
                    strokeWidth = 1,
                },
                {
                    name = "thruster",
                    type = "polygon",
                    points = thruster_points,
                    fill = { 0.95, 0.3, 0.18, 0.9 },
                    stroke = { 1.0, 0.45, 0.25, 0.95 },
                    strokeWidth = 1,
                },
            },
        },
        stats = {
            mass = 2.2,
            main_thrust = 110,
            strafe_thrust = 80,
            reverse_thrust = 70,
            max_acceleration = 160,
            max_speed = 260,
            linear_damping = 0.34,
            angular_damping = 0.11,
        },
        hull = {
            max = 70,
            current = 70,
            regen = 0,
        },
        health = {
            max = 60,
            current = 60,
        },
        ai = {
            behavior = "hunter",
            targetTag = "player",
            engagementRange = 680,
            fireArc = math.pi / 5,
            preferredDistance = 320,
            aggression = 0.85,
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
                    credit_reward = constants.enemies.credit_rewards.enemy_drone,
                    xp_reward = constants.enemies.xp_rewards.enemy_drone,
                },
            },
        },
    },
    weapons = {
        {
            id = "laser_beam",
            overrides = {
                weapon = {
                    damagePerSecond = 16,
                    maxRange = 360,
                    color = { 1, 0.2, 0.25 },
                    glowColor = { 1, 0.45, 0.5 },
                    width = 0.55,
                },
                weaponMount = {
                    anchor = { x = 0, y = 0.6 },
                    inset = 1,
                },
            },
        },
    },
}
