local constants = require("src.constants.game")

-- Tiny, compact enemy with high mass for ramming attacks
local scale = 5

local function default_weapon(id, mount)
    return {
        id = id,
        useDefaultWeapon = true,
        mount = mount,
    }
end

-- Compact triangular hull design
local hull_points = {
    0, -1.3 * scale,
    0.95 * scale, 0.8 * scale,
    0, 0.5 * scale,
    -0.95 * scale, 0.8 * scale,
}

-- Small core
local core_points = {
    0, -0.6 * scale,
    0.4 * scale, 0.25 * scale,
    -0.4 * scale, 0.25 * scale,
}

-- Thruster at rear
local thruster_points = {
    -0.25 * scale, 0.6 * scale,
    0.25 * scale, 0.6 * scale,
    0, 1.1 * scale,
}

-- Physics polygon for collisions
local physics_polygon = {
    0, -1.1 * scale,
    0.85 * scale, 0.7 * scale,
    0, 0.4 * scale,
    -0.85 * scale, 0.7 * scale,
}

return {
    category = "ships",
    id = "enemy_dasher",
    name = "Dasher",
    spawn = {
        strategy = "world_center",
        rotation = 0,
    },
    components = {
        type = "enemy_dasher",
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
                    fill = { 0.65, 0.08, 0.12, 1 },
                    stroke = { 0.95, 0.22, 0.28, 1 },
                    strokeWidth = 2,
                },
                {
                    name = "core",
                    type = "polygon",
                    points = core_points,
                    fill = { 0.92, 0.35, 0.15, 1 },
                    stroke = { 1.0, 0.55, 0.32, 1 },
                    strokeWidth = 1,
                },
                {
                    name = "thruster",
                    type = "polygon",
                    points = thruster_points,
                    fill = { 1.0, 0.4, 0.2, 0.95 },
                    stroke = { 1.0, 0.65, 0.35, 1 },
                    strokeWidth = 1,
                },
            },
        },
        stats = {
            mass = 8.5, -- High mass for ramming
            main_thrust = 200,
            strafe_thrust = 120,
            reverse_thrust = 80,
            max_acceleration = 280,
            max_speed = 350,
            linear_damping = 0.25,
            angular_damping = 0.15,
        },
        hull = {
            max = 45,
            current = 45,
            regen = 0,
        },
        health = {
            max = 40,
            current = 40,
        },
        energy = {
            max = 60,
            current = 60,
            regen = 12,
            rechargeDelay = 0.5,
        },
        ai = {
            behavior = "dasher", -- Custom aggressive ramming behavior
            targetTag = "player",
            engagementRange = 800,
            preferredDistance = 150, -- Get close before dashing
            aggression = 1.2,
            dashCooldown = 2.5,
            dashRange = 400, -- Distance at which to initiate dash
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
                    credit_reward = 40,
                    xp_reward = {
                        amount = 18,
                        category = "combat",
                        skill = "weapons",
                    },
                },
            },
        },
        abilityModules = {
            {
                key = "dash",
                ability = {
                    id = "dash",
                    type = "dash",
                    displayName = "Ram Dash",
                    cooldown = 2.5,
                    energyCost = 25,
                    impulse = 2200, -- Powerful dash
                    speed = 1400,
                    useMass = true,
                    duration = 0.3,
                    dashDamping = 0.08,
                    trailDuration = 0.25,
                    trailFade = 0.18,
                    trailStrength = 1.4,
                },
            },
        },
    },
    weapons = {
        -- Light weapon for occasional shots, but main attack is ramming
        default_weapon("laser_beam", {
            anchor = { x = 0, y = 0.3 },
            inset = 0,
        }),
    },
    physics = {
        body = {
            type = "dynamic",
        },
        fixture = {
            density = 2.5, -- Higher density for more impact
            friction = 0.2,
            restitution = 0.35, -- Bouncy for ramming
        },
    },
}
