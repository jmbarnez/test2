---@diagnostic disable-next-line: undefined-global
local love = love
local math_util = require("src.util.math")

local generator = {}

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local function adjust_color(color, delta, alpha)
    local base = color or { 1, 1, 1, 1 }
    local r = base[1] or 1
    local g = base[2] or r
    local b = base[3] or r
    local a = base[4] or 1

    if delta and delta ~= 0 then
        if delta > 0 then
            r = r + (1 - r) * delta
            g = g + (1 - g) * delta
            b = b + (1 - b) * delta
        else
            local factor = 1 + delta
            r = r * factor
            g = g * factor
            b = b * factor
        end
    end

    if alpha ~= nil then
        a = alpha
    end

    return {
        clamp(r, 0, 1),
        clamp(g, 0, 1),
        clamp(b, 0, 1),
        clamp(a, 0, 1),
    }
end

local function random_bool(chance)
    return love.math.random() < (chance or 0.5)
end

local TAU = math_util.TAU

-- Color palettes for variety
local COLOR_PALETTES = {
    -- Aggressive red
    {
        hull = { 0.52, 0.08, 0.1, 1 },
        core = { 0.3, 0.06, 0.08, 1 },
        accent = { 0.85, 0.18, 0.22, 1 },
        engine = { 0.95, 0.32, 0.18, 0.9 },
    },
    -- Cool blue
    {
        hull = { 0.08, 0.15, 0.4, 1 },
        core = { 0.05, 0.1, 0.25, 1 },
        accent = { 0.15, 0.35, 0.7, 1 },
        engine = { 0.3, 0.6, 1.0, 0.9 },
    },
    -- Toxic green
    {
        hull = { 0.12, 0.28, 0.1, 1 },
        core = { 0.08, 0.18, 0.06, 1 },
        accent = { 0.25, 0.6, 0.2, 1 },
        engine = { 0.4, 0.9, 0.3, 0.9 },
    },
    -- Purple/magenta
    {
        hull = { 0.3, 0.08, 0.35, 1 },
        core = { 0.18, 0.05, 0.2, 1 },
        accent = { 0.6, 0.15, 0.7, 1 },
        engine = { 0.9, 0.3, 1.0, 0.9 },
    },
    -- Orange/amber
    {
        hull = { 0.4, 0.2, 0.05, 1 },
        core = { 0.25, 0.12, 0.03, 1 },
        accent = { 0.8, 0.45, 0.1, 1 },
        engine = { 1.0, 0.65, 0.2, 0.9 },
    },
    -- Dark gray/steel
    {
        hull = { 0.2, 0.22, 0.25, 1 },
        core = { 0.12, 0.13, 0.15, 1 },
        accent = { 0.35, 0.4, 0.45, 1 },
        engine = { 0.6, 0.7, 0.8, 0.9 },
    },
}

-- Hull shape templates
local HULL_TEMPLATES = {
    -- Triangle (fighter-like)
    triangle = function(scale)
        local nose = 1.1 + love.math.random() * 0.3
        local tail = 0.9 + love.math.random() * 0.2
        local wing = 0.6 + love.math.random() * 0.2
        return {
            0, -nose * scale,
            wing * scale, tail * scale,
            -wing * scale, tail * scale,
        }
    end,
    -- Pentagon (interceptor-like)
    pentagon = function(scale)
        local side = 0.8 + love.math.random() * 0.2
        local rear = 0.9 + love.math.random() * 0.2
        return {
            0, -1.2 * scale,
            side * scale, -0.3 * scale,
            0.6 * scale, rear * scale,
            -0.6 * scale, rear * scale,
            -side * scale, -0.3 * scale,
        }
    end,
    -- Diamond (scout-like)
    diamond = function(scale)
        local nose = 1.2 + love.math.random() * 0.2
        local span = 0.75 + love.math.random() * 0.15
        local tail = 1.2 + love.math.random() * 0.2
        return {
            0, -nose * scale,
            span * scale, 0,
            0, tail * scale,
            -span * scale, 0,
        }
    end,
    -- Arrow (aggressive)
    arrow = function(scale)
        local wing_tip = 0.75 + love.math.random() * 0.2
        local mid = 0.45 + love.math.random() * 0.15
        local tail = 1.1 + love.math.random() * 0.25
        return {
            0, -1.4 * scale,
            mid * scale, -0.4 * scale,
            wing_tip * scale, 0.6 * scale,
            0.4 * scale, tail * scale,
            -0.4 * scale, tail * scale,
            -wing_tip * scale, 0.6 * scale,
            -mid * scale, -0.4 * scale,
        }
    end,
    -- Wedge (bulky)
    wedge = function(scale)
        local hull_width = 0.9 + love.math.random() * 0.2
        local shoulder = 1.1 + love.math.random() * 0.2
        return {
            0, -1.0 * scale,
            shoulder * scale, 0.2 * scale,
            hull_width * scale, 1.0 * scale,
            -hull_width * scale, 1.0 * scale,
            -shoulder * scale, 0.2 * scale,
        }
    end,
    -- Spearhead (long interceptor)
    spearhead = function(scale)
        local nose = 1.25 + love.math.random() * 0.3
        local shoulder = 0.45 + love.math.random() * 0.2
        local tail_width = 0.25 + love.math.random() * 0.2
        local tail = 1.1 + love.math.random() * 0.25
        return {
            0, -nose * scale,
            shoulder * scale, -0.1 * scale,
            tail_width * scale, tail * scale,
            -tail_width * scale, tail * scale,
            -shoulder * scale, -0.1 * scale,
        }
    end,
    -- Boomerang (swept wing)
    boomerang = function(scale)
        local wing_span = 1.1 + love.math.random() * 0.3
        local sweep = 0.25 + love.math.random() * 0.2
        local tail = 1.05 + love.math.random() * 0.25
        local tail_width = 0.45 + love.math.random() * 0.2
        return {
            0, -1.05 * scale,
            wing_span * scale, (-0.2 - sweep) * scale,
            (wing_span + 0.1) * scale, (0.2 + sweep) * scale,
            tail_width * scale, tail * scale,
            -tail_width * scale, tail * scale,
            -(wing_span + 0.1) * scale, (0.2 + sweep) * scale,
            -wing_span * scale, (-0.2 - sweep) * scale,
        }
    end,
    -- Manta (broad wings)
    manta = function(scale)
        local span = 1.3 + love.math.random() * 0.3
        local mid = 0.55 + love.math.random() * 0.2
        local tail = 1.0 + love.math.random() * 0.2
        return {
            0, -1.1 * scale,
            span * scale, -0.25 * scale,
            0.9 * scale, mid * scale,
            0.5 * scale, (tail + 0.2) * scale,
            -0.5 * scale, (tail + 0.2) * scale,
            -0.9 * scale, mid * scale,
            -span * scale, -0.25 * scale,
        }
    end,
    -- Hammerhead (heavy brawler)
    hammerhead = function(scale)
        local head_width = 1.2 + love.math.random() * 0.3
        local head_depth = 0.4 + love.math.random() * 0.2
        local mid = 0.6 + love.math.random() * 0.15
        local tail = 1.1 + love.math.random() * 0.25
        return {
            0, -1.25 * scale,
            head_width * scale, -head_depth * scale,
            mid * scale, -0.1 * scale,
            0.6 * scale, tail * scale,
            -0.6 * scale, tail * scale,
            -mid * scale, -0.1 * scale,
            -head_width * scale, -head_depth * scale,
        }
    end,
    -- Kite (balanced cruiser)
    kite = function(scale)
        local nose = 1.3 + love.math.random() * 0.2
        local shoulder = 0.65 + love.math.random() * 0.2
        local waist = 0.28 + love.math.random() * 0.15
        local tail = 1.2 + love.math.random() * 0.25
        return {
            0, -nose * scale,
            shoulder * scale, -0.3 * scale,
            waist * scale, 0.5 * scale,
            shoulder * scale, tail * scale,
            -shoulder * scale, tail * scale,
            -waist * scale, 0.5 * scale,
            -shoulder * scale, -0.3 * scale,
        }
    end,
    -- Chevron (wide striker)
    chevron = function(scale)
        local spread = 0.8 + love.math.random() * 0.18
        local mid = 0.5 + love.math.random() * 0.12
        local tail = 1.1 + love.math.random() * 0.24
        return {
            0, -1.25 * scale,
            spread * scale, -0.25 * scale,
            mid * scale, 0.0 * scale,
            0.55 * scale, tail * scale,
            -0.55 * scale, tail * scale,
            -mid * scale, 0.0 * scale,
            -spread * scale, -0.25 * scale,
        }
    end,
    -- Hexagon (armored platform)
    hexagon = function(scale)
        local width = 0.92 + love.math.random() * 0.16
        local upper = 0.45 + love.math.random() * 0.12
        local tail = 1.05 + love.math.random() * 0.2
        return {
            0, -1.05 * scale,
            width * scale, -0.38 * scale,
            width * scale, upper * scale,
            0.45 * scale, tail * scale,
            -0.45 * scale, tail * scale,
            -width * scale, upper * scale,
            -width * scale, -0.38 * scale,
        }
    end,
    -- Trident (split prow)
    trident = function(scale)
        local nose = 1.3 + love.math.random() * 0.2
        local inner = 0.36 + love.math.random() * 0.12
        local outer = 0.78 + love.math.random() * 0.18
        local tail = 1.05 + love.math.random() * 0.22
        return {
            0, -nose * scale,
            inner * scale, -0.55 * scale,
            outer * scale, 0.15 * scale,
            0.52 * scale, tail * scale,
            -0.52 * scale, tail * scale,
            -outer * scale, 0.15 * scale,
            -inner * scale, -0.55 * scale,
        }
    end,
    -- Blade (long interceptor)
    blade = function(scale)
        local nose = 1.45 + love.math.random() * 0.25
        local waist = 0.22 + love.math.random() * 0.08
        local mid = 0.42 + love.math.random() * 0.1
        local tail = 1.1 + love.math.random() * 0.24
        return {
            0, -nose * scale,
            waist * scale, -0.25 * scale,
            mid * scale, tail * scale,
            -mid * scale, tail * scale,
            -waist * scale, -0.25 * scale,
        }
    end,
    -- X-wing (cross guard)
    x_wing = function(scale)
        local wing = 1.0 + love.math.random() * 0.2
        local mid = 0.5 + love.math.random() * 0.12
        local tail = 1.15 + love.math.random() * 0.2
        return {
            0, -1.15 * scale,
            wing * scale, -0.45 * scale,
            mid * scale, -0.1 * scale,
            0.7 * scale, tail * scale,
            -0.7 * scale, tail * scale,
            -mid * scale, -0.1 * scale,
            -wing * scale, -0.45 * scale,
        }
    end,
}

local HULL_TEMPLATE_KEYS = {
    "triangle",
    "pentagon",
    "diamond",
    "arrow",
    "wedge",
    "spearhead",
    "boomerang",
    "manta",
    "hammerhead",
    "kite",
    "chevron",
    "hexagon",
    "trident",
    "blade",
    "x_wing",
}

local function random_choice(tbl)
    return tbl[love.math.random(1, #tbl)]
end

local function scale_points(points, scale_factor)
    local scaled = {}
    for i = 1, #points do
        scaled[i] = points[i] * scale_factor
    end
    return scaled
end

local function shrink_polygon(points, factor)
    -- Shrink polygon toward center
    local scaled = {}
    for i = 1, #points do
        scaled[i] = points[i] * factor
    end
    return scaled
end

local function generate_hull_shape(size_class)
    local hull_type = random_choice(HULL_TEMPLATE_KEYS)

    local base_scale = 10
    if size_class == "small" then
        base_scale = love.math.random(8, 12)
    elseif size_class == "medium" then
        base_scale = love.math.random(12, 18)
    elseif size_class == "large" then
        base_scale = love.math.random(18, 26)
    end
    
    local template = HULL_TEMPLATES[hull_type]
    return template(base_scale), base_scale
end

local function generate_engine_points(hull_points, scale)
    -- Create a small triangular engine at the rear
    local rear_width = love.math.random() * 0.3 + 0.3 -- 0.3 to 0.6
    local engine_length = love.math.random() * 0.5 + 0.3 -- 0.3 to 0.8
    
    return {
        -rear_width * scale, 0.8 * scale,
        rear_width * scale, 0.8 * scale,
        0, (0.8 + engine_length) * scale,
    }, engine_length
end

local function add_decals(parts, palette, scale)
    palette = palette or {}

    if random_bool(0.65) then
        local stripe_width = (0.22 + love.math.random() * 0.18) * scale
        local stripe_top = (0.25 + love.math.random() * 0.35) * scale
        local stripe_bottom = (0.55 + love.math.random() * 0.35) * scale

        parts[#parts + 1] = {
            name = "stripe_primary",
            type = "polygon",
            points = {
                -stripe_width, -stripe_top,
                stripe_width, -stripe_top,
                stripe_width * 0.65, stripe_bottom,
                -stripe_width * 0.65, stripe_bottom,
            },
            fill = adjust_color(palette.accent, 0.18, 0.78),
            stroke = adjust_color(palette.core, -0.1, 0.9),
            strokeWidth = 1.2,
        }
    end

    if random_bool(0.45) then
        local tip_length = (0.18 + love.math.random() * 0.2) * scale
        local tip_width = (0.24 + love.math.random() * 0.12) * scale

        parts[#parts + 1] = {
            name = "nose_cap",
            type = "polygon",
            points = {
                0, -(1.05 + tip_length) * scale,
                tip_width * 0.5, -1.0 * scale,
                -tip_width * 0.5, -1.0 * scale,
            },
            fill = adjust_color(palette.core, 0.25, 0.85),
            stroke = adjust_color(palette.accent, 0.15, 0.9),
            strokeWidth = 1.1,
        }
    end

    if random_bool(0.5) then
        local side_anchor = (0.6 + love.math.random() * 0.2) * scale
        local side_width = (0.08 + love.math.random() * 0.06) * scale
        local side_top = (0.1 + love.math.random() * 0.25) * scale
        local side_bottom = (0.55 + love.math.random() * 0.25) * scale

        parts[#parts + 1] = {
            name = "side_stripe",
            type = "polygon",
            mirror = true,
            points = {
                side_anchor - side_width, -side_top,
                side_anchor + side_width, -side_top * 0.7,
                side_anchor + side_width * 0.8, side_bottom,
                side_anchor - side_width * 0.6, side_bottom,
            },
            fill = adjust_color(palette.hull, 0.1, 0.65),
            stroke = adjust_color(palette.accent, 0.05, 0.75),
            strokeWidth = 0.9,
        }
    end
end

local function add_greebles(parts, palette, scale)
    palette = palette or {}

    if random_bool(0.55) then
        local base = (0.65 + love.math.random() * 0.18) * scale
        local tip = base + (0.16 + love.math.random() * 0.1) * scale
        local front_y = (0.18 + love.math.random() * 0.18) * scale
        local back_y = (0.6 + love.math.random() * 0.25) * scale

        parts[#parts + 1] = {
            name = "wing_fin",
            type = "polygon",
            mirror = true,
            points = {
                base, front_y,
                tip, front_y + 0.08 * scale,
                tip - 0.04 * scale, back_y,
                base - 0.06 * scale, back_y - 0.12 * scale,
            },
            fill = adjust_color(palette.hull, -0.08, 0.92),
            stroke = adjust_color(palette.accent, 0.12, 0.85),
            strokeWidth = 1.1,
        }
    end

    if random_bool(0.35) then
        local mast_base = (1.02 + love.math.random() * 0.12) * scale
        local mast_tip = mast_base + (0.24 + love.math.random() * 0.12) * scale

        parts[#parts + 1] = {
            name = "nose_antenna",
            type = "polygon",
            points = {
                -0.05 * scale, -mast_base,
                0.05 * scale, -mast_base,
                0.02 * scale, -mast_tip,
                -0.02 * scale, -mast_tip,
            },
            fill = adjust_color(palette.accent, 0.22, 0.7),
            stroke = false,
        }
    end
end

local function add_thruster_layers(parts, palette, scale, engine_length)
    palette = palette or {}
    engine_length = engine_length or 0.4

    local base_y = (0.8 + engine_length) * scale

    local glow_color = adjust_color(palette.engine, 0.35, 0.45)
    local glow_radius_x = (0.24 + love.math.random() * 0.12) * scale
    local glow_radius_y = (0.32 + engine_length * 0.6 + love.math.random() * 0.08) * scale

    parts[#parts + 1] = {
        name = "engine_glow",
        type = "ellipse",
        centerX = 0,
        centerY = base_y,
        radiusX = glow_radius_x,
        radiusY = glow_radius_y,
        fill = glow_color,
        stroke = false,
        blend = "add",
    }

    if random_bool(0.85) then
        local core_color = adjust_color(palette.engine, 0.55, 0.85)
        local core_radius = (0.1 + love.math.random() * 0.08) * scale

        parts[#parts + 1] = {
            name = "engine_core",
            type = "ellipse",
            centerX = 0,
            centerY = base_y + 0.04 * scale,
            radiusX = core_radius,
            radiusY = core_radius * (1.2 + love.math.random() * 0.4),
            fill = core_color,
            stroke = false,
            blend = "add",
        }
    end

    if random_bool(0.55) then
        local trail_length = (0.4 + engine_length * 0.6 + love.math.random() * 0.2) * scale
        local trail_width = (0.12 + love.math.random() * 0.05) * scale

        parts[#parts + 1] = {
            name = "engine_trail",
            type = "polygon",
            points = {
                -trail_width, base_y,
                trail_width, base_y,
                0, base_y + trail_length,
            },
            fill = adjust_color(palette.engine, 0.5, 0.28),
            stroke = false,
            blend = "add",
        }
    end
end

local function generate_ship_parts(hull_points, scale, palette)
    local parts = {}
    
    -- Hull (outer shell)
    table.insert(parts, {
        name = "hull",
        type = "polygon",
        points = hull_points,
        fill = palette.hull,
        stroke = palette.accent,
        strokeWidth = 2,
    })
    
    -- Core (inner polygon, slightly smaller)
    local core_factor = love.math.random() * 0.2 + 0.6 -- 0.6 to 0.8
    local core_points = shrink_polygon(hull_points, core_factor)
    table.insert(parts, {
        name = "core",
        type = "polygon",
        points = core_points,
        fill = palette.core,
        stroke = palette.accent,
        strokeWidth = 1,
    })
    
    -- Engine glow
    local engine_points, engine_length = generate_engine_points(hull_points, scale)
    table.insert(parts, {
        name = "engine",
        type = "polygon",
        points = engine_points,
        fill = palette.engine,
        stroke = palette.accent,
        strokeWidth = 1,
    })

    add_decals(parts, palette, scale)
    add_greebles(parts, palette, scale)
    add_thruster_layers(parts, palette, scale, engine_length)

    return parts
end

local function generate_stats(size_class, difficulty)
    local stats = {}
    
    -- Base stats vary by size class
    if size_class == "small" then
        stats.mass = love.math.random() * 2 + 2 -- 2-4
        stats.main_thrust = love.math.random() * 40 + 60 -- 60-100
        stats.strafe_thrust = stats.main_thrust * 0.65
        stats.reverse_thrust = stats.main_thrust * 0.7
        stats.max_acceleration = love.math.random() * 50 + 80 -- 80-130
        stats.max_speed = love.math.random() * 60 + 140 -- 140-200
        stats.linear_damping = love.math.random() * 0.2 + 0.3 -- 0.3-0.5
        stats.angular_damping = 0.1
    elseif size_class == "medium" then
        stats.mass = love.math.random() * 3 + 4 -- 4-7
        stats.main_thrust = love.math.random() * 30 + 50 -- 50-80
        stats.strafe_thrust = stats.main_thrust * 0.6
        stats.reverse_thrust = stats.main_thrust * 0.65
        stats.max_acceleration = love.math.random() * 40 + 60 -- 60-100
        stats.max_speed = love.math.random() * 50 + 100 -- 100-150
        stats.linear_damping = love.math.random() * 0.15 + 0.35 -- 0.35-0.5
        stats.angular_damping = 0.12
    else -- large
        stats.mass = love.math.random() * 4 + 7 -- 7-11
        stats.main_thrust = love.math.random() * 25 + 40 -- 40-65
        stats.strafe_thrust = stats.main_thrust * 0.55
        stats.reverse_thrust = stats.main_thrust * 0.6
        stats.max_acceleration = love.math.random() * 30 + 40 -- 40-70
        stats.max_speed = love.math.random() * 40 + 70 -- 70-110
        stats.linear_damping = love.math.random() * 0.15 + 0.4 -- 0.4-0.55
        stats.angular_damping = 0.15
    end
    
    -- Difficulty modifies stats
    local diff_mult = 1.0
    if difficulty == "easy" then
        diff_mult = 0.8
    elseif difficulty == "hard" then
        diff_mult = 1.3
    elseif difficulty == "extreme" then
        diff_mult = 1.6
    end
    
    for k, v in pairs(stats) do
        if k ~= "linear_damping" and k ~= "angular_damping" then
            stats[k] = v * diff_mult
        end
    end
    
    return stats
end

local function generate_health(size_class, difficulty)
    local base_health, base_hull
    
    if size_class == "small" then
        base_health = love.math.random(60, 100)
        base_hull = love.math.random(80, 120)
    elseif size_class == "medium" then
        base_health = love.math.random(100, 160)
        base_hull = love.math.random(120, 200)
    else -- large
        base_health = love.math.random(160, 260)
        base_hull = love.math.random(200, 320)
    end
    
    -- Difficulty modifies health
    local diff_mult = 1.0
    if difficulty == "easy" then
        diff_mult = 0.7
    elseif difficulty == "hard" then
        diff_mult = 1.4
    elseif difficulty == "extreme" then
        diff_mult = 2.0
    end
    
    base_health = math.floor(base_health * diff_mult)
    base_hull = math.floor(base_hull * diff_mult)
    
    return {
        max = base_health,
        current = base_health,
    }, {
        max = base_hull,
        current = base_hull,
        regen = 0,
    }
end

local function generate_weapon_mount(scale)
    -- Mount weapon at front-center
    local inset = love.math.random(0, 4)
    local forward_offset = love.math.random() * 0.3 + 0.7 -- 0.7 to 1.0
    
    return {
        anchor = { x = 0, y = forward_offset },
        inset = inset,
    }
end

local WEAPON_LOADOUTS = {
    {
        id = "laser_turret", -- Pulse laser turret
        weight = 5,
    },
    {
        id = "laser_beam",
        weight = 2,
        min_size = "medium",
    },
    {
        id = "cannon",
        weight = 3,
        min_size = "small",
    },
}

local SIZE_ORDER = {
    small = 1,
    medium = 2,
    large = 3,
}

local function choose_weapon(size_class)
    local class_rank = SIZE_ORDER[size_class] or 2
    local total = 0
    for i = 1, #WEAPON_LOADOUTS do
        local loadout = WEAPON_LOADOUTS[i]
        local min_rank = loadout.min_size and SIZE_ORDER[loadout.min_size] or 1
        if class_rank >= min_rank then
            total = total + (loadout.weight or 1)
        end
    end

    if total <= 0 then
        return "laser_turret"
    end

    local roll = love.math.random() * total
    local cumulative = 0
    for i = 1, #WEAPON_LOADOUTS do
        local loadout = WEAPON_LOADOUTS[i]
        local min_rank = loadout.min_size and SIZE_ORDER[loadout.min_size] or 1
        if class_rank >= min_rank then
            cumulative = cumulative + (loadout.weight or 1)
            if roll <= cumulative then
                return loadout.id
            end
        end
    end

    return "laser_turret"
end

local function generate_ai_params(size_class)
    local ai = {
        behavior = "hunter",
        targetTag = "player",
    }
    
    if size_class == "small" then
        ai.engagementRange = love.math.random(500, 800)
        ai.fireArc = math.pi / love.math.random(4, 7)
        ai.preferredDistance = love.math.random(250, 400)
    elseif size_class == "medium" then
        ai.engagementRange = love.math.random(600, 900)
        ai.fireArc = math.pi / love.math.random(5, 8)
        ai.preferredDistance = love.math.random(300, 500)
    else -- large
        ai.engagementRange = love.math.random(700, 1000)
        ai.fireArc = math.pi / love.math.random(6, 10)
        ai.preferredDistance = love.math.random(400, 650)
    end
    
    return ai
end

-- Generate a complete procedural ship blueprint
function generator.generate(params)
    params = params or {}
    
    -- Parameters
    local size_class = params.size_class or random_choice({ "small", "medium", "large" })
    local difficulty = params.difficulty or "normal"
    local seed = params.seed or love.math.random(1, 999999)
    
    -- Use seed for reproducibility if provided
    if params.use_seed then
        love.math.setRandomSeed(seed)
    end
    
    -- Generate visual design
    local palette = random_choice(COLOR_PALETTES)
    local hull_points, scale = generate_hull_shape(size_class)
    local parts = generate_ship_parts(hull_points, scale, palette)
    
    -- Generate physics collider (slightly smaller than hull for gameplay feel)
    local physics_points = shrink_polygon(hull_points, 0.85)
    
    -- Generate stats
    local stats = generate_stats(size_class, difficulty)
    local health, hull = generate_health(size_class, difficulty)
    local ai = generate_ai_params(size_class)
    
    -- Generate weapon mount
    local weapon_mount = generate_weapon_mount(scale)
    local weapon_id = choose_weapon(size_class)
    
    -- Generate unique ID
    local ship_id = string.format("proc_ship_%s_%d", size_class, seed)
    local ship_name = string.format("Procedural %s %d", size_class:gsub("^%l", string.upper), seed)
    
    -- Build blueprint
    return {
        category = "ships",
        id = ship_id,
        name = ship_name,
        _procedural = true,
        _seed = seed,
        _size_class = size_class,
        spawn = {
            strategy = "world_center",
            rotation = 0,
        },
        components = {
            type = "procedural_ship",
            enemy = true,
            level = {
                base = difficulty == "easy" and 1 or (difficulty == "hard" and 3 or (difficulty == "extreme" and 5 or 2)),
                current = difficulty == "easy" and 1 or (difficulty == "hard" and 3 or (difficulty == "extreme" and 5 or 2)),
            },
            position = { x = 0, y = 0 },
            velocity = { x = 0, y = 0 },
            rotation = 0,
            drawable = {
                type = "ship",
                parts = parts,
            },
            stats = stats,
            hull = hull,
            health = health,
            ai = ai,
            colliders = {
                {
                    name = "hull",
                    type = "polygon",
                    points = physics_points,
                },
            },
            loot = {
                entries = {
                    {
                        credit_reward = size_class == "small" and 50 or (size_class == "medium" and 100 or 200),
                        xp_reward = size_class == "small" and 15 or (size_class == "medium" and 30 or 60),
                    },
                },
            },
        },
        weapons = {
            {
                id = weapon_id,
                useDefaultWeapon = true,
                mount = weapon_mount,
            },
        },
        physics = {
            body = {
                type = "dynamic",
            },
            fixture = {
                density = 1,
                friction = 0.3,
                restitution = 0.15,
            },
        },
    }
end

-- Generate multiple ships at once
function generator.generate_batch(count, params)
    local ships = {}
    for i = 1, count do
        local ship_params = params or {}
        -- Ensure unique seeds
        if not ship_params.seed then
            ship_params.seed = love.math.random(1, 999999)
        else
            ship_params.seed = ship_params.seed + i
        end
        ships[i] = generator.generate(ship_params)
    end
    return ships
end

return generator
