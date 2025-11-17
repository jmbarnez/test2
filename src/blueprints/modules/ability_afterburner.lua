local BehaviorRegistry = require("src.abilities.behavior_registry")
local afterburner_behavior = require("src.abilities.behaviors.afterburner")

-- Register the afterburner behavior
BehaviorRegistry:register("afterburner", afterburner_behavior)

local blueprint = {
    category = "modules",
    id = "ability_afterburner",
    name = "Aurora Afterburner",
    slot = "ability",
    rarity = "rare",
    description = "Ability module that floods the engines for a sustained afterburn boost.",
    components = {
        module = {
            ability = {
                id = "afterburner",
                type = "afterburner",
                displayName = "Afterburner",
                continuous = true,
                duration = 0.35,
                energyPerSecond = 32,
                thrustMultiplier = 1.65,
                strafeMultiplier = 1.4,
                reverseMultiplier = 1.25,
                accelerationMultiplier = 1.6,
                maxSpeedMultiplier = 1.55,
                trailDuration = 0.5,
                trailFade = 0.4,
                trailStrength = 1.6,
                trailBurstParticles = 200,
                trailBurstStrength = 1.4,
                trailColors = {
                    1.0, 0.96, 0.45, 1.0,
                    1.0, 0.88, 0.28, 0.88,
                    1.0, 0.78, 0.18, 0.7,
                    1.0, 0.66, 0.1, 0.52,
                    1.0, 0.54, 0.05, 0.32,
                    1.0, 0.42, 0.02, 0.18,
                },
                trailDrawColor = { 1.0, 0.9, 0.3, 1.0 },
                zoomTarget = 0.35,
                minZoom = 0.3,
                maxZoom = 2.5,
                zoomReturnSpeed = 8,
                sfx = "sfx:engine_afterburn",
                sfxPitch = 1.05,
                sfxVolume = 0.95,
                hotkeyLabel = "SPACE",
                intentIndex = 1,
            },
        },
    },
    icon = {
        kind = "module",
        color = { 0.25, 0.6, 1.0, 1.0 },
        accent = { 0.12, 0.32, 0.85, 1.0 },
        detail = { 0.72, 0.92, 1.0, 1.0 },
        layers = {
            {
                shape = "rounded_rect",
                width = 0.86,
                height = 0.48,
                radius = 0.14,
                color = { 0.06, 0.1, 0.18, 0.92 },
            },
            {
                shape = "rounded_rect",
                width = 0.72,
                height = 0.36,
                radius = 0.12,
                color = { 0.18, 0.38, 0.76, 0.95 },
            },
            {
                shape = "polygon",
                points = { -0.14, -0.28, 0.14, -0.28, 0.32, 0.22, -0.32, 0.22 },
                color = { 0.32, 0.68, 1.0, 0.88 },
            },
            {
                shape = "rectangle",
                width = 0.12,
                height = 0.22,
                color = { 0.72, 0.92, 1.0, 0.75 },
                offsetY = 0.08,
            },
            {
                shape = "ring",
                radius = 0.52,
                thickness = 0.05,
                color = { 0.42, 0.76, 1.0, 0.28 },
            },
        },
    },
    item = {
        name = "Aurora Afterburner",
        description = "Trigger to overcharge your thrusters, boosting speed and widening tactical view.",
        value = 3200,
        volume = 6,
    },
}

return blueprint
