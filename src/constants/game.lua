-- ============================================================================
-- GAME CONSTANTS
-- ============================================================================
-- Central configuration file for all game-wide constants and settings.
-- This file defines parameters for rendering, physics, world generation,
-- entities, and gameplay mechanics.
-- ============================================================================

local constants = {}

-- ============================================================================
-- LÖVE FRAMEWORK CONFIGURATION
-- ============================================================================
-- Core LÖVE engine settings that control framework behavior and module usage.
-- These settings are applied during love.conf() initialization.
-- ============================================================================
constants.love = {
    identity = "procedural_space",  -- Save directory name for the game
    version = "11.5",                -- Target LÖVE version
    modules = {
        joystick = false,            -- Disable joystick module (not needed)
        physics = true,              -- Enable Box2D physics module
    },
}

-- ============================================================================
-- WINDOW CONFIGURATION
-- ============================================================================
-- Display window settings including resolution, fullscreen mode, and
-- rendering options like VSync and anti-aliasing.
-- ============================================================================
constants.window = {
    title = "Procedural Space",      -- Window title bar text
    width = 1600,                    -- Window width in pixels
    height = 900,                   -- Window height in pixels
    fullscreen = false,              -- Start in windowed mode
    resizable = false,                -- Allow window resizing
    vsync = 0,                       -- Disable vsync (using manual 60 FPS limiting)
    msaa = 0,                        -- Multisample anti-aliasing samples (0 = disabled)
    max_fps = 240,                   -- Manual frame limiter target when vsync is disabled
}

-- View configuration (camera defaults)
constants.view = {
    default_zoom = 1.0,              -- Default camera zoom (native scale)
}

-- ============================================================================
-- PHYSICS CONFIGURATION
-- ============================================================================
-- Box2D physics world settings including scale, gravity, and optimization
-- parameters for the simulation.
-- ============================================================================
constants.physics = {
    meter_scale = 64,                -- Pixels per meter (Box2D works in meters)
    gravity = { x = 0, y = 0 },      -- Zero gravity for space environment
    allow_sleeping = true,           -- Allow physics bodies to sleep when idle (optimization)
}

-- ============================================================================
-- WORLD CONFIGURATION
-- ============================================================================
-- Defines the playable space boundaries and default sector for gameplay.
-- World bounds constrain player movement and entity spawning.
-- ============================================================================
constants.world = {
    bounds = {
        x = 0,                       -- World origin X coordinate
        y = 0,                       -- World origin Y coordinate
        width = 50000,                -- Total world width in pixels
        height = 50000,               -- Total world height in pixels
    },
    default_sector = "default_sector", -- Initial sector to load on game start
}

-- ============================================================================
-- PLAYER CONFIGURATION
-- ============================================================================
-- Player-specific settings including starting ship type and initial state.
-- ============================================================================
constants.player = {
    starter_ship_id = "starter",     -- Blueprint ID for the player's starting ship
}

constants.network = {
    -- Connection settings
    host = "0.0.0.0",
    port = 25565,
    default_client_host = "127.0.0.1",  -- Default host for clients to connect to
    max_clients = 32,                    -- Maximum number of connected clients
    channels = 2,                        -- Number of ENet channels
    
    -- Update rates
    snapshot_rate = 60,        -- Hz: snapshots per second (server -> clients)
    input_rate = 60,           -- Hz: inputs per second (clients -> server)
    
    -- Server timing
    server_startup_delay = 1.0,  -- Seconds to wait before starting snapshots
    
    -- Physics synchronization
    physics_timestep = 1/60,     -- Fixed timestep for deterministic physics (60Hz)
    physics_max_steps = 4,       -- Maximum physics steps per frame (prevent spiral of death)
    
    -- Client-side prediction & interpolation
    interpolation_enabled = true,           -- Enable position drift correction
    interpolation_snap_threshold = 50,      -- Pixels: teleport if drift exceeds this
    interpolation_blend_threshold = 3,      -- Pixels: start blending corrections above this
    interpolation_correction_speed = 20,    -- Blend speed multiplier
    interpolation_rotation_threshold = 0.5, -- Radians: snap rotation if drift exceeds (~30 degrees)
    
    -- Client-side prediction specifics
    client_prediction_enabled = true,       -- Enable client-side prediction and reconciliation
    prediction_buffer_size = 120,           -- Max buffered input snapshots for reconciliation
    prediction_position_threshold = 6,      -- Pixels: acceptable position error before correction
    prediction_velocity_threshold = 4,      -- Pixels/sec: acceptable velocity error before correction
    
    -- Client reconciliation (for local player on client)
    reconciliation_threshold = 12,  -- Pixels: snap local player if server disagrees by this much
    
    -- Chat settings
    chat_max_length = 200,  -- Maximum characters per chat message
}

constants.ships = {
    health_bar = {
        width = 56,
        height = 4,
        offset = 34,
        show_duration = 1.5,
    },
}

-- ============================================================================
-- RENDERING CONFIGURATION
-- ============================================================================
-- Visual rendering settings including background colors and culling margins
-- for performance optimization.
-- ============================================================================
constants.render = {
    clear_color = { 0.01, 0.01, 0.025 }, -- Background color (dark blue-black space)
    star_cull_margin = 4,            -- Extra pixels beyond viewport to render stars (prevents pop-in)
    fonts = {
        primary = "assets/fonts/Orbitron-Regular.ttf",
    },
}

-- ============================================================================
-- STARFIELD CONFIGURATION
-- ============================================================================
-- Multi-layered parallax starfield settings. Each layer has different
-- parallax speed, star count, size, and opacity to create depth illusion.
-- ============================================================================
constants.stars = {
    defaults = {
        size_range = { 0.5, 2.5 },   -- Default min/max star size in pixels
        alpha_range = { 40 / 255, 200 / 255 }, -- Default min/max star opacity (0-1)
    },
    layers = {
        -- Far background layer (slowest parallax)
        {
            parallax = 0.003,        -- Parallax multiplier (lower = slower, farther away)
            count = 780,             -- Number of stars in this layer
            size_range = { 0.7, 1.4 }, -- Min/max star size for this layer
            alpha_range = { 0.45, 0.7 }, -- Min/max opacity for this layer
        },
        -- Middle layer (moderate parallax)
        {
            parallax = 0.018,        -- Medium parallax speed
            count = 660,             -- Star count for middle layer
            size_range = { 1.0, 2.0 }, -- Slightly larger stars
            alpha_range = { 0.6, 0.85 }, -- More visible than background
        },
        -- Foreground layer (fastest parallax)
        {
            parallax = 0.055,        -- Fastest parallax (closest to camera)
            count = 600,             -- Foreground star count
            size_range = { 1.4, 2.8 }, -- Largest stars for depth effect
            alpha_range = { 0.75, 1.0 }, -- Most visible/brightest stars
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
-- ASTEROID CONFIGURATION
-- ============================================================================
-- Parameters for procedurally generated asteroids including size, shape,
-- physics properties, durability, and visual feedback settings.
-- ============================================================================
constants.asteroids = {
    radius = { min = 22, max = 64 }, -- Min/max asteroid radius in pixels
    sides = { min = 6, max = 8 },    -- Number of polygon sides for shape generation
    scale = { min = 0.85, max = 1.1 }, -- Random scale variation per vertex (creates irregular shapes)
    damping = {
        linear = 0.45,               -- Linear velocity damping (friction in space)
        angular = 0.12,              -- Angular velocity damping (rotation slowdown)
    },
    durability = {
        min = 120,                   -- Minimum asteroid health points
        max = 220,                   -- Maximum asteroid health points
    },
    color = { 0.7, 0.65, 0.6 },      -- Base color (RGB, grayish-brown rock)
    health_bar = {
        show_duration = 1.5,         -- Seconds to show health bar after taking damage
        height = 4,                  -- Health bar height in pixels
        padding = 6,                 -- Vertical padding above asteroid
    },
    loot = {
        rolls = 1,
        entries = {
            {
                id = "resource:ore_chunk",
                chance = 0.9,
                quantity = { min = 1, max = 3 },
            },
            {
                id = "resource:rare_crystal",
                chance = 0.1,
                quantity = 1,
            },
        },
    },
    field = {
        count = { min = 30, max = 50 }, -- Number of asteroids to spawn in a field
    },
}

-- ============================================================================
-- WEAPONS CONFIGURATION
-- ============================================================================
-- Weapon system parameters including damage, range, visual effects, and
-- firing mechanics for different weapon types.
-- ============================================================================
constants.weapons = {
    laser = {
        max_range = 720,             -- Maximum laser beam distance in pixels
        width = 1.2,                 -- Laser beam width in pixels
        damage_per_second = 32,      -- Damage dealt per second of continuous fire
        fade_time = 0.08,            -- Beam fade-out duration in seconds
        color = { 1, 0.3, 0.6 },     -- Primary laser color (RGB, pink-red)
        glow_color = { 1, 0.7, 0.9 }, -- Glow/highlight color for visual effect
    },
    laser_turret = {
        projectile_speed = 840,      -- Speed of each pulse projectile (pixels/sec)
        projectile_lifetime = 0.28,  -- Lifetime to approximate short beam reach
        projectile_size = 5,         -- Visual size of the bolt
        damage = 22,                 -- Damage per pulse hit
        fire_rate = 0.32,            -- Time between pulses (seconds)
        color = { 1, 0.45, 0.3 },    -- Warmer turret bolt color
        glow_color = { 1, 0.8, 0.6 }, -- Glow color to match
        offset = 26,                 -- Default muzzle offset
        forward = 28,                -- Default mount forward offset
    },
}

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================
return constants
