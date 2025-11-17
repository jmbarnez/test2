local math_util = require("src.util.math")

---@diagnostic disable-next-line: undefined-global
local love = love

local WreckageFactory = {}

local unpack = table.unpack or unpack

local DEFAULT_COLORS = {
    { 0.35, 0.45, 0.55, 1.0 },
    { 0.42, 0.52, 0.62, 1.0 },
    { 0.28, 0.32, 0.40, 1.0 },
}

local palette_keys = {
    "hull",
    "accent",
    "trim",
    "wing",
    "fin",
    "engine",
    "core",
    "default",
}

local function jitter_color(color, variation)
    color = color or DEFAULT_COLORS[1]
    local v = variation or 0.12

    local r = math_util.clamp((color[1] or 0.5) * (1 + (love.math.random() * 2 - 1) * v), 0, 1)
    local g = math_util.clamp((color[2] or 0.5) * (1 + (love.math.random() * 2 - 1) * v), 0, 1)
    local b = math_util.clamp((color[3] or 0.5) * (1 + (love.math.random() * 2 - 1) * v), 0, 1)
    local a = math_util.clamp(color[4] or 1, 0, 1)

    return { r, g, b, a }
end

local function choose_palette_color(palette)
    if type(palette) ~= "table" then
        return jitter_color(DEFAULT_COLORS[love.math.random(1, #DEFAULT_COLORS)])
    end

    local options = {}
    for _, key in ipairs(palette_keys) do
        local value = palette[key]
        if type(value) == "table" and #value >= 3 then
            options[#options + 1] = value
        end
    end

    if #options == 0 then
        for _, value in pairs(palette) do
            if type(value) == "table" and #value >= 3 then
                options[#options + 1] = value
            end
        end
    end

    if #options == 0 then
        return jitter_color(DEFAULT_COLORS[love.math.random(1, #DEFAULT_COLORS)])
    end

    return jitter_color(options[love.math.random(1, #options)])
end

-- Transform a point by offset, rotation, and scale
local function transform_point(x, y, offset, rotation, scale)
    local sx = scale and scale.x or scale or 1
    local sy = scale and scale.y or scale or 1
    
    -- Apply scale
    local tx = x * sx
    local ty = y * sy
    
    -- Apply rotation
    if rotation and rotation ~= 0 then
        local cos_r = math.cos(rotation)
        local sin_r = math.sin(rotation)
        local rotx = tx * cos_r - ty * sin_r
        local roty = tx * sin_r + ty * cos_r
        tx = rotx
        ty = roty
    end
    
    -- Apply offset
    if offset then
        tx = tx + (offset.x or 0)
        ty = ty + (offset.y or 0)
    end
    
    return tx, ty
end

-- Extract transformed points from a polygon part
local function extract_part_points(part)
    if not part or not part.points or #part.points < 6 then
        return nil
    end
    
    local points = {}
    local offset = part.offset
    local rotation = part.rotation
    local scale = part.scale
    
    for i = 1, #part.points, 2 do
        local x = part.points[i]
        local y = part.points[i + 1]
        local tx, ty = transform_point(x, y, offset, rotation, scale)
        points[#points + 1] = tx
        points[#points + 1] = ty
    end
    
    return points
end

-- Calculate centroid of a polygon
local function calculate_centroid(points)
    if not points or #points < 6 then
        return 0, 0
    end
    
    local cx, cy = 0, 0
    local count = #points / 2
    
    for i = 1, #points, 2 do
        cx = cx + points[i]
        cy = cy + points[i + 1]
    end
    
    return cx / count, cy / count
end

-- Slice a polygon into fragments
local function slice_polygon(points, num_slices)
    if not points or #points < 6 or num_slices < 2 then
        return { points }
    end
    
    local cx, cy = calculate_centroid(points)
    local fragments = {}
    
    -- Create radial slices from centroid
    local slice_angle = math_util.TAU / num_slices
    local base_angle = love.math.random() * math_util.TAU
    
    for slice_idx = 1, num_slices do
        local angle1 = base_angle + (slice_idx - 1) * slice_angle
        local angle2 = base_angle + slice_idx * slice_angle
        
        local fragment = { cx, cy }
        
        -- Add points that fall within this slice
        for i = 1, #points, 2 do
            local x = points[i]
            local y = points[i + 1]
            local dx = x - cx
            local dy = y - cy
            local point_angle = math.atan2(dy, dx)
            
            -- Normalize point angle to 0-TAU range
            while point_angle < 0 do point_angle = point_angle + math_util.TAU end
            while point_angle >= math_util.TAU do point_angle = point_angle - math_util.TAU end
            
            local a1_norm = angle1 % math_util.TAU
            local a2_norm = angle2 % math_util.TAU
            
            -- Check if point is in the angular slice
            local in_slice = false
            if a1_norm < a2_norm then
                in_slice = point_angle >= a1_norm - slice_angle * 0.3 and point_angle <= a2_norm + slice_angle * 0.3
            else
                in_slice = point_angle >= a1_norm - slice_angle * 0.3 or point_angle <= a2_norm + slice_angle * 0.3
            end
            
            if in_slice then
                fragment[#fragment + 1] = x
                fragment[#fragment + 1] = y
            end
        end
        
        -- Add edge points along slice boundaries
        local radius = 0
        for i = 1, #points, 2 do
            local dx = points[i] - cx
            local dy = points[i + 1] - cy
            local r = math.sqrt(dx * dx + dy * dy)
            if r > radius then radius = r end
        end
        
        radius = radius * (0.9 + love.math.random() * 0.15)
        fragment[#fragment + 1] = cx + math.cos(angle2) * radius
        fragment[#fragment + 1] = cy + math.sin(angle2) * radius
        
        if #fragment >= 6 then
            fragments[#fragments + 1] = fragment
        end
    end
    
    return #fragments > 0 and fragments or { points }
end

-- Break a polygon into irregular chunks
local function break_polygon(points, target_pieces)
    if not points or #points < 6 then
        return { points }
    end
    
    -- For small target counts, use slicing
    if target_pieces <= 3 then
        return slice_polygon(points, target_pieces)
    end
    
    -- For larger counts, create sub-polygons around random points
    local fragments = {}
    local cx, cy = calculate_centroid(points)
    
    -- Calculate radius
    local max_radius = 0
    for i = 1, #points, 2 do
        local dx = points[i] - cx
        local dy = points[i + 1] - cy
        local r = math.sqrt(dx * dx + dy * dy)
        if r > max_radius then max_radius = r end
    end
    
    -- Create random fragment centers
    for piece_idx = 1, target_pieces do
        local angle = (piece_idx - 1) * math_util.TAU / target_pieces + (love.math.random() - 0.5) * 0.8
        local dist = max_radius * (0.3 + love.math.random() * 0.4)
        local fcx = cx + math.cos(angle) * dist
        local fcy = cy + math.sin(angle) * dist
        
        -- Create small polygon around this center
        local frag = {}
        local frag_radius = max_radius * (0.25 + love.math.random() * 0.35)
        local sides = love.math.random(3, 5)
        
        for i = 0, sides - 1 do
            local a = i * math_util.TAU / sides + (love.math.random() - 0.5) * 0.6
            local r = frag_radius * (0.7 + love.math.random() * 0.3)
            frag[#frag + 1] = fcx + math.cos(a) * r
            frag[#frag + 1] = fcy + math.sin(a) * r
        end
        
        if #frag >= 6 then
            fragments[#fragments + 1] = frag
        end
    end
    
    return #fragments > 0 and fragments or { points }
end

-- Extract ship geometry parts with colors
local function extract_ship_geometry(ship)
    local drawable = ship.drawable
    if not drawable or not drawable.parts or #drawable.parts == 0 then
        return nil
    end
    
    local geometry = {}
    local parts = drawable.parts
    
    for i = 1, #parts do
        local part = parts[i]
        if part and (part.type == nil or part.type == "polygon") and part.points then
            local points = extract_part_points(part)
            if points and #points >= 6 then
                geometry[#geometry + 1] = {
                    points = points,
                    name = part.name or part.tag or "hull",
                    fill = part.fill,
                    stroke = part.stroke,
                    strokeWidth = part.strokeWidth or 1,
                }
            end
        end
    end
    
    return #geometry > 0 and geometry or nil
end

local function random_between(min_value, max_value)
    if min_value > max_value then
        min_value, max_value = max_value, min_value
    end
    local span = max_value - min_value
    if span <= 0 then
        return min_value
    end
    return min_value + love.math.random() * span
end

local function compute_reference_radius(entity)
    if entity.mountRadius and entity.mountRadius > 0 then
        return entity.mountRadius
    end

    local hull = entity.hullSize
    if type(hull) == "table" then
        local size_x = math.abs(hull.x or 0)
        local size_y = math.abs(hull.y or 0)
        local avg = (size_x + size_y) * 0.25
        if avg > 0 then
            return avg
        end
    end

    local collider = entity.collider
    if type(collider) == "table" and type(collider.radius) == "number" then
        return collider.radius
    end

    return 26
end

local function collect_palette(entity)
    if entity.drawable and type(entity.drawable.colors) == "table" then
        return entity.drawable.colors
    end
    return nil
end

local function gather_base_motion(entity)
    local vx, vy = 0, 0
    local angular = 0

    local body = entity.body
    if body and not body:isDestroyed() then
        vx, vy = body:getLinearVelocity()
        angular = body:getAngularVelocity()
    elseif entity.velocity then
        vx = entity.velocity.x or 0
        vy = entity.velocity.y or 0
    end

    return vx, vy, angular
end

local function compute_reference_area(entity, radius)
    local hull = entity.hullSize
    if type(hull) == "table" and (hull.x or 0) ~= 0 and (hull.y or 0) ~= 0 then
        return math.abs((hull.x or 0) * (hull.y or 0))
    end

    return math.pi * radius * radius
end

local function build_scrap_loot(piece_radius)
    local min_quantity = math.max(1, math.floor(piece_radius * 0.08 + 0.5))
    local max_quantity = math.max(min_quantity, math.floor(piece_radius * 0.12 + 1))

    return {
        rolls = 1,
        entries = {
            {
                id = "resource:hull_scrap",
                quantity = {
                    min = min_quantity,
                    max = max_quantity,
                },
                chance = 1,
                scatter = piece_radius * 0.35,
            },
        },
    }
end

local function create_wreckage_piece(context, params)
    local position = params.position
    local polygon = params.polygon

    local physics_world = context.physicsWorld
    if not physics_world then
        return
    end

    local body = love.physics.newBody(physics_world, position.x, position.y, "dynamic")
    local rotation = params.rotation
    body:setAngle(rotation)
    body:setLinearDamping(params.linearDamping)
    body:setAngularDamping(params.angularDamping)
    body:setLinearVelocity(params.velocity.x, params.velocity.y)
    body:setAngularVelocity(params.angularVelocity)

    local shape = love.physics.newPolygonShape(unpack(polygon))
    local density = math_util.clamp(params.density or 0.35, 0.05, 6)
    local fixture = love.physics.newFixture(body, shape, density)
    fixture:setFriction(0.85)
    fixture:setRestitution(0.08)

    local radius = params.pieceRadius or 12
    local baseHealth = math_util.clamp((radius * 0.9) + 12, 18, 140)
    local health = params.health or baseHealth

    local piece_radius = params.pieceRadius or 16

    local health_bar_config = params.healthBar or {}
    local health_bar = {
        width = health_bar_config.width or (piece_radius * 1.8),
        height = health_bar_config.height or 5,
        offset = health_bar_config.offset or (piece_radius + 8),
        showDuration = health_bar_config.showDuration or health_bar_config.show_duration or 1.5,
    }

    local entity = {
        position = { x = position.x, y = position.y },
        velocity = { x = params.velocity.x, y = params.velocity.y },
        rotation = rotation,
        health = {
            current = health,
            max = health,
            showTimer = 0,
        },
        healthBar = health_bar,
        drawable = {
            type = "wreckage",
            polygon = polygon,
            color = params.fillColor,
            outline = params.outlineColor,
            alpha = 1,
            lineWidth = params.lineWidth,
        },
        wreckage = {
            lifetime = params.lifetime,
            fadeDuration = params.fadeDuration,
            age = 0,
            alpha = 1,
            pieceRadius = piece_radius,
        },
        loot = params.loot,
        armorType = "wreckage",
        mass = params.density or 0.5,
        body = body,
        shape = shape,
        fixture = fixture,
    }

    body:setUserData(entity)
    fixture:setUserData({ type = "wreckage", entity = entity })

    entity.onDamaged = function(target, amount)
        if not target.health then
            return
        end
        target.health.current = math.max(0, (target.health.current or target.health.max or 0) - amount)
        if target.healthBar then
            target.health.showTimer = target.healthBar.showDuration or 0
        end

        if target.health.current <= 0 then
            target.pendingDestroy = true
        end
    end

    entity.onDestroyed = function(target)
    end

    context.world:add(entity)
end

function WreckageFactory.spawn(ship, context)
    if not (ship and context and context.world and context.physicsWorld) then
        return
    end

    -- Extract actual ship geometry
    local ship_geometry = extract_ship_geometry(ship)
    local palette = collect_palette(ship)
    local radius = math.max(12, compute_reference_radius(ship))
    local base_position = ship.position or { x = 0, y = 0 }
    local vx, vy, angular_velocity = gather_base_motion(ship)

    -- If we have ship geometry, use it to create realistic fragments
    if ship_geometry and #ship_geometry > 0 then
        local ship_rotation = ship.rotation or 0
        
        -- Determine how many pieces total
        local total_pieces = love.math.random(3, 6)
        local pieces_per_part = math.max(1, math.floor(total_pieces / #ship_geometry))
        
        for _, geom in ipairs(ship_geometry) do
            -- Decide how to break this part
            local fragment_count = love.math.random(1, pieces_per_part + 1)
            local fragments = break_polygon(geom.points, fragment_count)
            
            for _, fragment_points in ipairs(fragments) do
                -- Calculate fragment properties
                local fcx, fcy = calculate_centroid(fragment_points)
                local frag_radius = 0
                for i = 1, #fragment_points, 2 do
                    local dx = fragment_points[i] - fcx
                    local dy = fragment_points[i + 1] - fcy
                    local r = math.sqrt(dx * dx + dy * dy)
                    if r > frag_radius then frag_radius = r end
                end
                frag_radius = math.max(frag_radius, 8)
                
                -- Recentre fragment points around origin
                local centered_points = {}
                for i = 1, #fragment_points, 2 do
                    centered_points[#centered_points + 1] = fragment_points[i] - fcx
                    centered_points[#centered_points + 1] = fragment_points[i + 1] - fcy
                end
                
                -- Transform fragment center to world space
                local world_cx, world_cy = transform_point(
                    fcx, fcy, nil, ship_rotation, nil
                )
                world_cx = world_cx + base_position.x
                world_cy = world_cy + base_position.y
                
                -- Scatter velocity
                local scatter_angle = math.atan2(fcy, fcx) + ship_rotation
                local scatter_speed = random_between(40, 140)
                local velocity = {
                    x = vx + math.cos(scatter_angle) * scatter_speed,
                    y = vy + math.sin(scatter_angle) * scatter_speed,
                }
                
                -- Use original part colors with variation
                local fill_color = geom.fill and jitter_color(geom.fill, 0.1) or choose_palette_color(palette)
                local outline_color = geom.stroke and jitter_color(geom.stroke, 0.1) or {
                    math_util.clamp(fill_color[1] * 0.55, 0, 1),
                    math_util.clamp(fill_color[2] * 0.55, 0, 1),
                    math_util.clamp(fill_color[3] * 0.55, 0, 1),
                    fill_color[4] or 1,
                }
                
                local line_width = geom.strokeWidth or math_util.clamp(frag_radius * 0.1, 1, 2.5)
                local rotation = ship_rotation + love.math.random() * 0.6 - 0.3
                local angular = angular_velocity + random_between(-4.5, 4.5)
                local density = math_util.clamp(frag_radius * 0.1, 0.1, 3)
                local pieceHealth = math_util.clamp((frag_radius * 1.5) + 20, 25, 180)
                
                create_wreckage_piece(context, {
                    position = { x = world_cx, y = world_cy },
                    polygon = centered_points,
                    rotation = rotation,
                    velocity = velocity,
                    angularVelocity = angular,
                    linearDamping = random_between(2.0, 3.0),
                    angularDamping = random_between(1.5, 2.5),
                    density = density,
                    lifetime = random_between(4.5, 7.0),
                    fadeDuration = random_between(1.3, 2.0),
                    fillColor = fill_color,
                    outlineColor = outline_color,
                    lineWidth = line_width,
                    pieceRadius = frag_radius,
                    health = pieceHealth,
                    loot = build_scrap_loot(frag_radius),
                })
            end
        end
    else
        -- Fallback to generic polygon generation if no geometry available
        local piece_count = love.math.random(2, 4)
        local offset_radius = radius * 0.55
        
        for i = 1, piece_count do
            local piece_radius = radius * (0.5 + love.math.random() * 0.4)
            
            -- Generate simple polygon
            local sides = love.math.random(3, 5)
            local polygon = {}
            for j = 0, sides - 1 do
                local angle = j * math_util.TAU / sides + (love.math.random() - 0.5) * 0.5
                local r = piece_radius * (0.7 + love.math.random() * 0.3)
                polygon[#polygon + 1] = math.cos(angle) * r
                polygon[#polygon + 1] = math.sin(angle) * r
            end
            
            local angle = love.math.random() * math_util.TAU
            local distance = random_between(piece_radius * 0.5, offset_radius)
            local px = base_position.x + math.cos(angle) * distance
            local py = base_position.y + math.sin(angle) * distance
            
            local scatter_speed = random_between(60, 180)
            local scatter_angle = angle + (love.math.random() - 0.5) * 0.9
            
            local velocity = {
                x = vx + math.cos(scatter_angle) * scatter_speed,
                y = vy + math.sin(scatter_angle) * scatter_speed,
            }
            
            local fill_color = choose_palette_color(palette)
            local outline_color = {
                math_util.clamp(fill_color[1] * 0.55, 0, 1),
                math_util.clamp(fill_color[2] * 0.55, 0, 1),
                math_util.clamp(fill_color[3] * 0.55, 0, 1),
                fill_color[4] or 1,
            }
            
            create_wreckage_piece(context, {
                position = { x = px, y = py },
                polygon = polygon,
                rotation = love.math.random() * math_util.TAU,
                velocity = velocity,
                angularVelocity = angular_velocity + random_between(-5, 5),
                linearDamping = random_between(2.2, 3.3),
                angularDamping = random_between(1.8, 2.6),
                density = 0.5,
                lifetime = random_between(4.2, 6.5),
                fadeDuration = random_between(1.2, 1.9),
                fillColor = fill_color,
                outlineColor = outline_color,
                lineWidth = math_util.clamp(piece_radius * 0.12, 1.2, 2.4),
                pieceRadius = piece_radius,
                health = math_util.clamp((piece_radius * 1.25) + 24, 30, 200),
                loot = build_scrap_loot(piece_radius),
            })
        end
    end
end

return WreckageFactory
