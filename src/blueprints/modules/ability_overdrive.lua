local BehaviorRegistry = require("src.abilities.behavior_registry")
local overdrive_behavior = require("src.abilities.behaviors.overdrive")

-- Register the overdrive behavior
BehaviorRegistry:register("overdrive", overdrive_behavior)

local blueprint = {
    category = "modules",
    id = "ability_overdrive",
    name = "Cyclone Overdrive",
    slot = "ability",
    rarity = "epic",
    description = "Ability module that floods the engines for an intense thrust burst, leaving an extended speed wake.",
    components = {
        module = {
            ability = {
                id = "overdrive",
                type = "overdrive",
                displayName = "Overdrive",
                cooldown = 14,
                energyCost = 45,
                duration = 2.6,
                thrustDuration = 0.8,
                maxSpeedDuration = 2.6,
                thrustMultiplier = 2.3,
                strafeMultiplier = 1.85,
                reverseMultiplier = 1.5,
                accelerationMultiplier = 2.0,
                maxSpeedMultiplier = 1.75,
                thrustForceMultiplier = 2.1,
                forwardImpulse = 760,
                dampingMultiplier = 0.6,
                trailDuration = 2.4,
                trailFade = 0.6,
                trailStrength = 1.8,
                trailKeepAlive = 1.2,
                trailBurstParticles = 260,
                trailBurstStrength = 1.6,
                trailColors = {
                    1.0, 0.45, 0.12, 1.0,
                    1.0, 0.55, 0.18, 0.92,
                    1.0, 0.68, 0.25, 0.78,
                    1.0, 0.8, 0.38, 0.58,
                },
                trailDrawColor = { 1.0, 0.72, 0.28, 1.0 },
                sfx = "sfx:engine_afterburn",
                sfxPitch = 1.25,
                sfxVolume = 1.05,
                intentIndex = 1,
            },
        },
    },
    icon = {
        kind = "module",
        color = { 1.0, 0.52, 0.18, 1.0 },
        accent = { 0.26, 0.1, 0.62, 1.0 },
        detail = { 1.0, 0.84, 0.36, 1.0 },
        layers = {
            {
                shape = "rounded_rect",
                width = 0.88,
                height = 0.5,
                radius = 0.16,
                color = { 0.08, 0.06, 0.18, 0.92 },
            },
            {
                shape = "rounded_rect",
                width = 0.72,
                height = 0.32,
                radius = 0.12,
                color = { 0.38, 0.2, 0.78, 0.96 },
            },
            {
                shape = "polygon",
                points = { -0.18, -0.28, 0.18, -0.28, 0.36, 0.22, -0.36, 0.22 },
                color = { 1.0, 0.52, 0.18, 0.9 },
            },
            {
                shape = "rectangle",
                width = 0.14,
                height = 0.24,
                color = { 1.0, 0.84, 0.36, 0.78 },
                offsetY = 0.1,
            },
            {
                shape = "ring",
                radius = 0.56,
                thickness = 0.06,
                color = { 1.0, 0.62, 0.24, 0.28 },
            },
        },
    },
    item = {
        name = "Cyclone Overdrive Module",
        description = "Surge your engines with a violent thrust spike, then ride the velocity wave for several seconds.",
        value = 5200,
        volume = 7,
    },
}

return blueprint
