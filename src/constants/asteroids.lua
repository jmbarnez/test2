-- ============================================================================
-- ASTEROID CONFIGURATION
-- ============================================================================

return {
    radius = { min = 32, max = 80 },
    sides = { min = 6, max = 11 },
    scale = { min = 0.82, max = 1.18 },
    color = { 0.68, 0.62, 0.55 },
    durability = { min = 160, max = 320 },
    friction = 0.85,
    restitution = 0.05,
    damping = {
        linear = 0.18,
        angular = 0.12,
    },
    health_bar = {
        show_duration = 1.5,
        height = 4,
        padding = 6,
    },
    loot = {
        rolls = 2,
        entries = {
            {
                id = "resource:stone",
                chance = 0.85,
                quantity = { min = 1, max = 3 },
                scatter = 26,
            },
            {
                id = "resource:rare_crystal",
                chance = 0.12,
                quantity = { min = 1, max = 1 },
                scatter = 18,
            },
        },
    },
    mining_xp = {
        base = 24,
        chunk = 12,
    },
    chunks = {
        enabled = true,
        inherit_loot = false,
        max_levels = 2,
        min_radius = 18,
        min_health = 12,
        count = { min = 2, max = 4 },
        size_scale = { min = 0.32, max = 0.55 },
        health_scale = { min = 0.25, max = 0.4 },
        offset = { min = 12, max = 46 },
        speed = { min = 70, max = 180 },
        angular_velocity = { min = -2.8, max = 2.8 },
        loot_drop = {
            id = "resource:stone",
            count = { min = 1, max = 2 },
            quantity = { min = 1, max = 3 },
            scatter = { min = 10, max = 32 },
            velocity = { min = 40, max = 140 },
            lifetime = 18,
            collectRadius = 26,
            size = 18,
        },
        metal_rich = {
            chance = 0.35,
            id = "resource:ferrosite_ore",
            count = { min = 1, max = 2 },
            quantity = { min = 2, max = 4 },
            color = { 0.58, 0.7, 0.86 },
        },
        gold_rich = {
            chance = 0.06,
            id = "resource:gold",
            count = { min = 1, max = 1 },
            quantity = { min = 1, max = 2 },
            color = { 0.96, 0.82, 0.36 },
        },
    },
}
