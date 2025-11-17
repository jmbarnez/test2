-- ============================================================================
-- DAMAGE SYSTEM CONFIGURATION
-- ============================================================================

return {
    default_type = "default",
    default_armor = "default",
    multipliers = {
        default = { default = 1.0 },
        laser = { default = 0.85, rock = 1.2 },
        kinetic = { default = 1.0, rock = 0.9, shield = 0.75 },
        explosive = { default = 1.05, rock = 1.3, shield = 0.6 },
        energy = { default = 0.95, shield = 1.15 },
    },
    crit_chance = 0.05,
    crit_multiplier = 2.0,
}
