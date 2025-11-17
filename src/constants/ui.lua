-- ============================================================================
-- UI CONFIGURATION
-- ============================================================================

return {
    health_bar = {
        width = 56,
        height = 4,
        offset = 34,
        show_duration = 1.5,
        background_color = { 0.2, 0.2, 0.2, 0.8 },
        health_color = { 0.2, 0.8, 0.3 },
        damage_color = { 0.9, 0.2, 0.2 },
    },
    minimap = {
        size = 200,
        position = { x = 20, y = 20 },
        background_alpha = 0.5,
        zoom = 0.05,
    },
    hotbar = {
        slot_count = 10,
        slot_size = 48,
        spacing = 4,
        position = "bottom_center",
    },
    currency_panel = {
        width = 180,
        height = 62,
        base_y = 122,
        offset_y = 22,
        gain_visible_duration = 2.6,
        gain_anim_duration = 0.45,
        minimap_diameter = 120,
        minimap_margin = 24,
        gap = 16,
    },
    floating_text = {
        xp = {
            color = { 0.3, 0.9, 0.4, 1 },
            rise = 40,
            scale = 1.1,
            font = "bold",
        },
        credits = {
            color = { 1.0, 0.9, 0.2, 1 },
            rise = 40,
            scale = 1.1,
            font = "bold",
            offset_y = 22,
            icon = "currency",
        },
    },
    shop = {
        scrollbar_width = 10,
        scroll_step = 60,
        row_spacing = 60,
        min_sort_button_width = 110,
        search_width_threshold = 120,
    },
    damage_numbers = {
        defaults = {
            color = { 0.92, 0.36, 0.32, 1 },
            duration = 1.05,
            rise = 32,
            batchWindow = 0.18,
            refreshBuffer = 0.3,
        },
        presets = {
            hull = {
                color = { 0.92, 0.36, 0.32, 1 },
            },
            shield = {
                color = { 0.4, 0.7, 1.0, 1.0 },
            },
            crit = {
                color = { 1.0, 0.9, 0.2, 1.0 },
                scale = 1.15,
            },
        },
    },
    notifications = {
        quest_complete = {
            duration = 3.5,
            accent = { 0.3, 0.78, 0.46, 1 },
        },
    },
}
