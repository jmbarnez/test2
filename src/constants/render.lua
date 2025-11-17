-- ============================================================================
-- RENDERING CONFIGURATION
-- ============================================================================

return {
    clear_color = { 0.01, 0.01, 0.025 },
    star_cull_margin = 4,
    entity_cull_margin = 200,
    fonts = {
        primary = "assets/fonts/Orbitron-Regular.ttf",
        bold = "assets/fonts/Orbitron-Bold.ttf",
        sizes = {
            small = 12,
            medium = 16,
            large = 24,
            huge = 48,
        },
    },
    particle_limit = 5000,
    trail_segment_limit = 500,
}
