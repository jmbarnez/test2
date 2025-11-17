local BehaviorRegistry = require("src.abilities.behavior_registry")
local shield_burst_behavior = require("src.abilities.behaviors.shield_burst")

-- Register the shield burst behavior
BehaviorRegistry.register("shield_burst", shield_burst_behavior)

local blueprint = {
    category = "modules",
    id = "ability_shield_burst",
    name = "Aegis Shield Burst",
    slot = "ability",
    rarity = "epic",
    description = "Releases a powerful shockwave that damages nearby enemies while restoring your shields.",
    components = {
        module = {
            ability = {
                id = "shield_burst",
                type = "shield_burst",
                displayName = "Shield Burst",
                cooldown = 12.0,
                energyCost = 45,
                
                -- Shield burst parameters
                radius = 250,
                damage = 75,
                shieldRestore = 50,
                knockback = 800,
                visualDuration = 0.5,
                
                -- Audio
                sfx = "sfx:shield_burst",
                sfxPitch = 1.1,
                sfxVolume = 0.9,
                
                hotkeyLabel = "SPACE",
                intentIndex = 1,
            },
        },
    },
    icon = {
        kind = "module",
        color = { 0.5, 0.9, 1.0, 1.0 },
        accent = { 0.3, 0.7, 1.0, 1.0 },
        detail = { 0.8, 1.0, 1.0, 1.0 },
        layers = {
            {
                shape = "rounded_rect",
                width = 0.86,
                height = 0.48,
                radius = 0.14,
                color = { 0.08, 0.14, 0.28, 0.94 },
            },
            {
                shape = "circle",
                radius = 0.32,
                color = { 0.2, 0.5, 0.9, 0.9 },
            },
            {
                shape = "ring",
                radius = 0.32,
                thickness = 0.08,
                color = { 0.5, 0.85, 1.0, 0.95 },
            },
            {
                shape = "ring",
                radius = 0.44,
                thickness = 0.04,
                color = { 0.4, 0.75, 1.0, 0.7 },
            },
            {
                shape = "ring",
                radius = 0.54,
                thickness = 0.03,
                color = { 0.6, 0.9, 1.0, 0.5 },
            },
            {
                shape = "circle",
                radius = 0.12,
                color = { 0.9, 1.0, 1.0, 0.85 },
            },
        },
    },
    item = {
        name = "Aegis Shield Burst",
        description = "Trigger with Space to release an expanding shockwave that damages enemies within range while restoring your shield integrity.",
        value = 4200,
        volume = 7,
    },
}

return blueprint
