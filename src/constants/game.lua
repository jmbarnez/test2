-- ============================================================================
-- GAME CONSTANTS
-- ============================================================================
-- Central configuration file for all game-wide constants and settings.
-- This file defines parameters for rendering, physics, world generation,
-- and gameplay mechanics. Entity-specific defaults belong in their blueprints.
-- ============================================================================

local constants = {}

-- ============================================================================
-- LÖVE FRAMEWORK CONFIGURATION
-- ============================================================================
constants.love = {
    identity = "procedural_space",
    version = "11.5",
    modules = {
        joystick = false,
        physics = true,
    },
}

-- ============================================================================
-- WINDOW CONFIGURATION
-- ============================================================================
constants.window = {
    title = "Novus",
    width = 1600,
    height = 900,
    fullscreen = false,
    resizable = true,
    vsync = 0,
    msaa = 0,
    max_fps = 240,
}

constants.view = {
    default_zoom = 1.0,
    min_zoom = 0.3,
    max_zoom = 2.5,
    zoom_step = 0.1,
}

-- ============================================================================
-- PHYSICS CONFIGURATION
-- ============================================================================
constants.physics = {
    meter_scale = 64,
    gravity = { x = 0, y = 0 },
    allow_sleeping = true,
    fixed_timestep = 1/60,
    max_steps = 4,
    velocity_iterations = 8,
    position_iterations = 3,
}

-- ============================================================================
-- WORLD CONFIGURATION
-- ============================================================================
constants.world = {
    bounds = {
        x = 0,
        y = 0,
        width = 50000,
        height = 50000,
    },
    default_sector = "default_sector",
    chunk_size = 2048,
    unload_distance = 4096,
}

-- ============================================================================
-- ASTEROID CONFIGURATION
-- ============================================================================
constants.asteroids = {
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
                id = "resource:ore_chunk",
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
        inherit_loot = true,
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
            id = "resource:ore_chunk",
            count = { min = 1, max = 2 },
            quantity = { min = 1, max = 3 },
            scatter = { min = 10, max = 32 },
            velocity = { min = 40, max = 140 },
            lifetime = 18,
            collectRadius = 26,
            size = 18,
        },
    },
}

-- ============================================================================
-- PLAYER CONFIGURATION
-- ============================================================================
constants.player = {
    starter_ship_id = "starter",
    starting_currency = 10000,
    starting_position = { x = 25000, y = 25000 },
    respawn_invulnerability = 3.0,
    max_interaction_distance = 200,
}

-- =========================================================================
-- ENEMY CONFIGURATION
-- =========================================================================
constants.enemies = {
    credit_rewards = {
        enemy_scout = 60,
        enemy_drone = 45,
        enemy_boss = 500,
    },
}

-- ============================================================================
-- UI CONFIGURATION
-- ============================================================================
constants.ui = {
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
}

-- ============================================================================
-- RENDERING CONFIGURATION
-- ============================================================================
constants.render = {
    clear_color = { 0.01, 0.01, 0.025 },
    star_cull_margin = 4,
    entity_cull_margin = 200,
    fonts = {
        primary = "assets/fonts/Orbitron-Regular.ttf",
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

-- ============================================================================
-- STARFIELD CONFIGURATION
-- ============================================================================
constants.stars = {
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

-- ============================================================================
-- DAMAGE SYSTEM
-- ============================================================================
constants.damage = {
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

-- ============================================================================
-- ECONOMY & PROGRESSION
-- ============================================================================
constants.economy = {
    base_sell_multiplier = 0.6,
    base_buy_multiplier = 1.0,
    reputation_discount_per_level = 0.02,
    max_reputation_discount = 0.2,
}

constants.progression = {
    base_exp_per_level = 1000,
    exp_scaling = 1.15,
    max_level = 50,
}

-- ============================================================================
-- AUDIO
-- ============================================================================
constants.audio = {
    master_volume = 1.0,
    music_volume = 0.7,
    sfx_volume = 0.8,
    max_simultaneous_sounds = 32,
    sound_falloff_distance = 1500,
    sound_max_distance = 3000,
}

-- ============================================================================
-- PERFORMANCE
-- ============================================================================
constants.performance = {
    max_active_entities = 1000,
    entity_pool_size = 2000,
    spatial_grid_cell_size = 512,
    update_distance = 3000,
    collision_distance = 2000,
}

-- ============================================================================
-- DEBUG
-- ============================================================================
constants.debug = {
    show_fps = false,
    show_physics = false,
    show_bounds = false,
    show_grid = false,
    god_mode = false,
}

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================
return constants
