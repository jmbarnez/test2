-- ============================================================================
-- STARFIELD CONFIGURATION
-- ============================================================================

return {
    defaults = {
        size_range = { 0.5, 2.5 },
        alpha_range = { 40 / 255, 200 / 255 },
    },
    nebula = {
        intensity_range = { 0.18, 0.32 },
        alpha_range = { 0.32, 0.55 },
    },
    layers = {
        {
            parallax = 0.003,
            count = 78000,
            size_range = { 0.7, 1.4 },
            alpha_range = { 0.45, 0.7 },
        },
        {
            parallax = 0.018,
            count = 2000,
            size_range = { 1.0, 2.0 },
            alpha_range = { 0.6, 0.85 },
        },
        {
            parallax = 0.055,
            count = 6000,
            size_range = { 1.4, 2.8 },
            alpha_range = { 0.75, 1.0 },
        },
    },
    background_props = {
        planets = {
            count = 3,
            parallax = 0.001,
            radius_range = { 140, 280 },
            color_palette = {
                { 0.24, 0.42, 0.86 },
                { 0.82, 0.31, 0.46 },
                { 0.38, 0.78, 0.68 },
                { 0.88, 0.67, 0.28 },
                { 0.58, 0.36, 0.84 },
            },
            brightness_range = { 0.35, 0.75 },
            highlight_strength = { 0.15, 0.35 },
            ring_probability = 0.55,
            ring_thickness = { 6, 14 },
            ring_scale = { 1.4, 1.9 },
            ring_alpha = { 0.15, 0.3 },
        },
        comets = {
            parallax = 0.005,
            spawn_interval = { 12, 28 },
            spawn_margin = 400,
            speed_range = { 90, 160 },
            drift_range = { -24, 24 },
            radius_range = { 10, 18 },
            brightness_range = { 0.6, 1.0 },
            tail_length = 26,
            tail_segment_spacing = 18,
            tail_fade = 0.06,
            head_color = { 1.0, 0.95, 0.8 },
            tail_color = { 0.6, 0.8, 1.0 },
        },
    },
}
