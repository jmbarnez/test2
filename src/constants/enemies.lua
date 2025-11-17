-- ============================================================================
-- ENEMY CONFIGURATION
-- ============================================================================

return {
    credit_rewards = {
        enemy_scout = 60,
        enemy_drone = 45,
        enemy_boss = 500,
        enemy_ram_tiny = 80,
    },
    xp_rewards = {
        enemy_scout = {
            amount = 25,
            category = "combat",
            skill = "weapons",
        },
        enemy_drone = {
            amount = 20,
            category = "combat",
            skill = "weapons",
        },
        enemy_boss = {
            amount = 150,
            category = "combat",
            skill = "weapons",
        },
        enemy_ram_tiny = {
            amount = 32,
            category = "combat",
            skill = "weapons",
        },
    },
    level_scaling = {
        hull = 0.18,
        health = 0.18,
        shield = 0.18,
        damage = 0.12,
        speed = 0.04,
        credits = 0.12,
        xp = 0.16,
    },
}
