local BehaviorRegistry = require("src.abilities.behavior_registry")
local temporal_field_behavior = require("src.abilities.behaviors.temporal_field")

-- Register the temporal field behavior
BehaviorRegistry.register("temporal_field", temporal_field_behavior)

local blueprint = {
    category = "modules",
    id = "ability_temporal_field",
    name = "Temporal Lag Field",
    slot = "ability",
    rarity = "rare",
    description = "Projects a slow-time bubble around the ship, reducing projectile speed and enemy fire rate inside it.",
    components = {
        module = {
            ability = {
                id = "temporal_field",
                type = "temporal_field",
                displayName = "Temporal Field",
                cooldown = 18.0,
                energyCost = 55,
                duration = 6.0,
                
                -- Temporal field parameters
                radius = 250,
                projectileSlowFactor = 0.35, -- Projectiles move at 35% speed
                cooldownReductionRate = 0.18, -- Faster cooldown recovery while active
                
                -- Visual parameters
                bubbleColor = { 0.4, 0.7, 1.0, 0.3 },
                bubbleRimColor = { 0.5, 0.85, 1.0, 0.7 },
                
                -- Audio
                sfx = "sfx:laser_turret_fire",
                sfxPitch = 0.7,
                sfxVolume = 0.6,
                
                hotkeyLabel = "SPACE",
                intentIndex = 1,
            },
        },
    },
    icon = {
        kind = "module",
        color = { 0.4, 0.75, 1.0, 1.0 },
        accent = { 0.25, 0.55, 0.95, 1.0 },
        detail = { 0.65, 0.9, 1.0, 1.0 },
        layers = {
            {
                shape = "rounded_rect",
                width = 0.84,
                height = 0.48,
                radius = 0.14,
                color = { 0.08, 0.12, 0.28, 0.94 },
            },
            {
                shape = "circle",
                radius = 0.38,
                color = { 0.15, 0.35, 0.75, 0.85 },
            },
            {
                shape = "ring",
                radius = 0.38,
                thickness = 0.06,
                color = { 0.45, 0.75, 1.0, 0.9 },
            },
            {
                shape = "ring",
                radius = 0.48,
                thickness = 0.04,
                color = { 0.35, 0.65, 0.95, 0.6 },
            },
            {
                shape = "ring",
                radius = 0.56,
                thickness = 0.03,
                color = { 0.5, 0.8, 1.0, 0.4 },
            },
            {
                shape = "polygon",
                points = { -0.12, -0.08, 0.12, -0.08, 0.0, 0.12 },
                color = { 0.7, 0.95, 1.0, 0.75 },
                offsetY = -0.15,
            },
            {
                shape = "polygon",
                points = { -0.12, 0.08, 0.12, 0.08, 0.0, -0.12 },
                color = { 0.7, 0.95, 1.0, 0.75 },
                offsetY = 0.15,
            },
        },
    },
    item = {
        name = "Temporal Lag Field",
        description = "Trigger with Space to deploy a temporal bubble that slows incoming projectiles and hastens your other ability cooldowns for a short duration.",
        value = 3200,
        volume = 8,
    },
}

return blueprint
