local BehaviorRegistry = require("src.abilities.behavior_registry")
local dash_behavior = require("src.abilities.behaviors.dash")

-- Register the dash behavior
BehaviorRegistry.register("dash", dash_behavior)

local blueprint = {
    category = "modules",
    id = "ability_dash",
    name = "Vector Surge Dash",
    slot = "ability",
    rarity = "uncommon",
    description = "Ability module that propels the ship forward in a burst of speed.",
    components = {
        module = {
            ability = {
                id = "dash",
                type = "dash",
                displayName = "Dash",
                cooldown = 1.8,
                energyCost = 18,
                impulse = 1400,
                speed = 1150,
                useMass = true,
                duration = 0.22,
                dashDamping = 0.12,
                trailDuration = 0.18,
                trailFade = 0.16,
                trailStrength = 1.25,
                hotkeyLabel = "SPACE",
                intentIndex = 1,
            },
        },
    },
    icon = {
        kind = "module",
        color = { 0.45, 0.85, 1.0, 1.0 },
        accent = { 0.2, 0.6, 1.0, 1.0 },
        detail = { 0.7, 0.95, 1.0, 1.0 },
        layers = {
            {
                shape = "rounded_rect",
                width = 0.82,
                height = 0.44,
                radius = 0.12,
                color = { 0.08, 0.14, 0.24, 0.92 },
            },
            {
                shape = "rounded_rect",
                width = 0.68,
                height = 0.32,
                radius = 0.1,
                color = { 0.22, 0.52, 0.92, 0.95 },
            },
            {
                shape = "polygon",
                points = { -0.24, -0.18, -0.08, -0.18, 0.0, -0.28, 0.08, -0.18, 0.24, -0.18, 0.28, 0.18, -0.28, 0.18 },
                color = { 0.42, 0.82, 1.0, 0.9 },
            },
            {
                shape = "circle",
                radius = 0.08,
                color = { 0.85, 0.98, 1.0, 0.85 },
                offsetY = -0.06,
            },
            {
                shape = "ring",
                radius = 0.48,
                thickness = 0.05,
                color = { 0.38, 0.72, 1.0, 0.28 },
            },
        },
    },
    item = {
        name = "Vector Surge Dash",
        description = "Trigger with Space to surge forward, consuming energy but instantly accelerating.",
        value = 1450,
        volume = 5,
    },
}

return blueprint
