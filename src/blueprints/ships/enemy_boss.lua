local scale = 28

local hull_outer = {
    0, -1.8 * scale,
    1.1 * scale, -0.9 * scale,
    1.4 * scale, -0.1 * scale,
    1.25 * scale, 1.05 * scale,
    0.6 * scale, 1.8 * scale,
    -0.6 * scale, 1.8 * scale,
    -1.25 * scale, 1.05 * scale,
    -1.4 * scale, -0.1 * scale,
    -1.1 * scale, -0.9 * scale,
}

local hull_inner = {
    0, -1.25 * scale,
    0.7 * scale, -0.55 * scale,
    0.85 * scale, 0.2 * scale,
    0.55 * scale, 0.95 * scale,
    0, 1.3 * scale,
    -0.55 * scale, 0.95 * scale,
    -0.85 * scale, 0.2 * scale,
    -0.7 * scale, -0.55 * scale,
}

local thruster_panel = {
    -0.9 * scale, 1.15 * scale,
    0.9 * scale, 1.15 * scale,
    0.65 * scale, 1.85 * scale,
    -0.65 * scale, 1.85 * scale,
}

local emitter_spines = {
    -0.35 * scale, -1.15 * scale,
    -0.15 * scale, -1.6 * scale,
    0.15 * scale, -1.6 * scale,
    0.35 * scale, -1.15 * scale,
}

local physics_polygon = {
    0, -1.7 * scale,
    1.0 * scale, -0.85 * scale,
    1.25 * scale, -0.05 * scale,
    1.05 * scale, 1.0 * scale,
    0.55 * scale, 1.7 * scale,
    -0.55 * scale, 1.7 * scale,
    -1.05 * scale, 1.0 * scale,
    -1.25 * scale, -0.05 * scale,
    -1.0 * scale, -0.85 * scale,
}

return {
    category = "ships",
    id = "enemy_boss",
    name = "Aegis-class Battleship",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "enemy_boss",
        enemy = true,
        position = { x = 0, y = 0 },
        velocity = { x = 0, y = 0 },
        rotation = 0,
        drawable = {
            type = "ship",
            colors = {
                hull = { 0.32, 0.04, 0.06, 1 },
                accent = { 0.55, 0.08, 0.12, 1 },
                core = { 0.88, 0.22, 0.26, 1 },
                glow = { 0.95, 0.36, 0.26, 0.9 },
                trim = { 0.2, 0.05, 0.06, 1 },
            },
            parts = {
                {
                    name = "hull_outer",
                    type = "polygon",
                    points = hull_outer,
                    highlightBase = true,
                    fill = "hull",
                    stroke = "trim",
                    strokeWidth = 4,
                },
                {
                    name = "hull_inner",
                    type = "polygon",
                    points = hull_inner,
                    fill = "accent",
                    stroke = "trim",
                    strokeWidth = 3,
                },
                {
                    name = "core_glow",
                    type = "ellipse",
                    centerX = 0,
                    centerY = 0.35 * scale,
                    radiusX = 0.55 * scale,
                    radiusY = 0.78 * scale,
                    fill = { 0.9, 0.28, 0.24, 0.32 },
                    stroke = false,
                    blend = "add",
                },
                {
                    name = "thruster_panel",
                    type = "polygon",
                    points = thruster_panel,
                    fill = "accent",
                    stroke = "trim",
                    strokeWidth = 2.5,
                },
                {
                    name = "emitter_spines",
                    type = "polygon",
                    points = emitter_spines,
                    fill = "core",
                    stroke = "glow",
                    strokeWidth = 2,
                    mirror = true,
                },
            },
        },
        stats = {
            mass = 26,
            main_thrust = 70,
            strafe_thrust = 55,
            reverse_thrust = 45,
            max_acceleration = 90,
            max_speed = 140,
            linear_damping = 0.48,
            angular_damping = 0.16,
        },
        hull = {
            max = 950,
            current = 950,
            regen = 4,
        },
        shield = {
            max = 1200,
            current = 1200,
            regen = 28,
            rechargeDelay = 4.5,
        },
        energy = {
            max = 600,
            current = 600,
            regen = 120,
            rechargeDelay = 1.2,
        },
        ai = {
            behavior = "hunter",
            targetTag = "player",
            engagementRange = 1000,
            fireArc = math.pi / 4,
            preferredDistance = 420,
            aggression = 1.0,
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
                    credit_reward = constants.enemies.credit_rewards.enemy_boss,
                },
            },
        },
    },
    weapons = {
        {
            id = "shock_burst_launcher",
            overrides = {
                weapon = {
                    fireRate = 1.8,
                    damage = 16,
                    energyPerShot = 48,
                    projectileBlueprint = {
                        projectile = {
                            damage = 16,
                        },
                        drawable = {
                            size = 3.2,
                        },
                    },
                    shotgunPatternConfig = {
                        count = 22,
                        spreadDegrees = 28,
                        baseJitterDegrees = 14,
                        lateralJitter = 32,
                        speedMultiplierMin = 0.9,
                        speedMultiplierMax = 1.3,
                    },
                },
                weaponMount = {
                    anchor = { x = 0, y = 0.9 },
                    inset = 0,
                },
            },
        },
    },
    physics = {
        body = {
            type = "dynamic",
        },
        fixture = {
            density = 1.6,
            friction = 0.22,
            restitution = 0.08,
        },
    },
}
