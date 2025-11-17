-- ============================================================================
-- PHYSICS CONFIGURATION
-- ============================================================================

return {
    meter_scale = 64,
    gravity = { x = 0, y = 0 },
    allow_sleeping = true,
    fixed_timestep = 1 / 60,
    max_steps = 4,
    velocity_iterations = 8,
    position_iterations = 3,
}
