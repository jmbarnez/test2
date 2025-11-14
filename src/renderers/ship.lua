---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
local vector = require("src.util.vector")

local TWO_PI = math.pi * 2

local ship_renderer = {}
local ship_bar_defaults = constants.ships and constants.ships.health_bar or {}

ship_renderer.SHIELD_RING_COLOR = { 0.35, 0.95, 1.0, 0.85 }
ship_renderer.SHIELD_GLOW_COLOR = { 0.18, 0.7, 1.0, 0.9 }
ship_renderer.SHIELD_IMPACT_COLOR = { 0.82, 0.98, 1.0, 1.0 }
ship_renderer.HULL_GLOW_COLOR = { 1.0, 0.25, 0.15, 0.9 }

local function normalize_angle(angle)
    local wrapped = (angle + math.pi) % TWO_PI
    if wrapped < 0 then
        wrapped = wrapped + TWO_PI
    end
    return wrapped - math.pi
end

local function draw_wrapped_arc(radius, startAngle, endAngle, lineWidth)
    if not radius or radius <= 0 or not lineWidth or lineWidth <= 0 then
        return
    end

    local span = endAngle - startAngle
    if span <= 0 then
        return
    end

    love.graphics.setLineWidth(lineWidth)

    if span >= TWO_PI - 1e-3 then
        love.graphics.circle("line", 0, 0, radius)
        return
    end

    local start = startAngle
    local stop = endAngle

    if stop < start then
        local turns = math.ceil((start - stop) / TWO_PI)
        stop = stop + turns * TWO_PI
    end

    local currentStart = start
    while currentStart < stop do
        local currentEnd = math.min(stop, currentStart + TWO_PI)
        local segmentStart = normalize_angle(currentStart)
        local segmentEnd = segmentStart + (currentEnd - currentStart)
        love.graphics.arc("line", "open", 0, 0, radius, segmentStart, segmentEnd)
        currentStart = currentEnd
    end
end

local function resolve_shield(entity)
    if not entity then
        return nil
    end

    local shield = entity.shield
    if type(shield) == "table" then
        return shield
    end

    if entity.health and type(entity.health.shield) == "table" then
        return entity.health.shield
    end

    return nil
end

local function resolve_entity_level(entity)
    if not entity then
        return nil
    end

    local level = entity.level
    if type(level) == "table" then
        level = level.current or level.value or level.level
    end

    if not level and entity.pilot and type(entity.pilot.level) == "table" then
        level = entity.pilot.level.current or entity.pilot.level.value or entity.pilot.level.level
    end

    if type(level) == "number" then
        local rounded = math.floor(level + 0.5)
        if rounded > 0 then
            return rounded
        end
    end

    return nil
end

local function mirror_points(points)
    local mirrored = {}
    for i = 1, #points, 2 do
        mirrored[#mirrored + 1] = -points[i]
        mirrored[#mirrored + 1] = points[i + 1]
    end
    return mirrored
end

local function normalise_color(color, fallback)
    fallback = fallback or { 1, 1, 1, 1 }
    if type(color) ~= "table" then
        return { fallback[1], fallback[2], fallback[3], fallback[4] }
    end

    return {
        color[1] ~= nil and color[1] or fallback[1],
        color[2] ~= nil and color[2] or fallback[2],
        color[3] ~= nil and color[3] or fallback[3],
        color[4] ~= nil and color[4] or fallback[4],
    }
end

local function resolve_color(palette, spec, fallback)
    local fallback_color = normalise_color(fallback)
    if type(spec) == "table" and #spec >= 3 then
        return normalise_color(spec, fallback_color)
    elseif type(spec) == "string" and palette and palette[spec] then
        local color = palette[spec]
        if type(color) == "table" and #color >= 3 then
            return normalise_color(color, fallback_color)
        end
    end

    return fallback_color
end

local function apply_transform(part)
    local has_transform = false
    if part.offset then
        love.graphics.translate(part.offset.x or 0, part.offset.y or 0)
        has_transform = true
    end
    if part.rotation then
        love.graphics.rotate(part.rotation)
        has_transform = true
    end
    if part.scale then
        if type(part.scale) == "table" then
            love.graphics.scale(part.scale.x or 1, part.scale.y or 1)
        else
            love.graphics.scale(part.scale, part.scale)
        end
        has_transform = true
    end

    return has_transform
end

local function compute_polygon_radius(points)
    local maxRadius = 0
    if type(points) ~= "table" then
        return maxRadius
    end

    for i = 1, #points, 2 do
        local x = points[i] or 0
        local y = points[i + 1] or 0
        local radius = vector.length(x, y)
        if radius > maxRadius then
            maxRadius = radius
        end
    end

    return maxRadius
end

local function compute_part_radius(part)
    if part.type == "ellipse" then
        local rx = part.radiusX or (part.width and part.width * 0.5) or part.radius or 0
        local ry = part.radiusY or (part.height and part.height * 0.5) or part.length or rx
        return math.max(math.abs(rx), math.abs(ry))
    end

    local points = part.points
    if type(points) ~= "table" then
        return 0
    end

    return compute_polygon_radius(points)
end

local function part_has_transform(part)
    if not part then
        return false
    end

    if part.offset then
        return true
    end

    if part.rotation then
        return true
    end

    if part.scale then
        return true
    end

    return false
end

local function score_polygon_part(part, radius)
    if not part or not radius or radius <= 0 then
        return -math.huge
    end

    local score = radius

    if part.name == "hull" or part.tag == "hull" then
        score = score + radius * 0.5
    end

    if not part_has_transform(part) then
        score = score + radius * 0.25
    end

    return score
end

local function select_base_polygon(drawable)
    local parts = drawable and drawable.parts
    if type(parts) ~= "table" or #parts == 0 then
        return nil
    end

    local explicit_points
    local best_points
    local best_score = -math.huge

    for i = 1, #parts do
        local part = parts[i]
        if part and (part.type == nil or part.type == "polygon") then
            local points = part.points
            if type(points) == "table" and #points >= 6 then
                if not explicit_points then
                    local tag = part.tag
                    if part.highlightBase or part.basePolygon or tag == "base" then
                        explicit_points = points
                    end
                end

                local radius = compute_polygon_radius(points)
                local score = score_polygon_part(part, radius)
                if score > best_score then
                    best_score = score
                    best_points = points
                end
            end
        end
    end

    return explicit_points or best_points
end

local function ensure_base_polygon(drawable)
    if not drawable then
        return
    end

    if type(drawable.polygon) == "table" and #drawable.polygon >= 6 then
        drawable._basePolygonCache = drawable.polygon
        return
    end

    if drawable._basePolygonCache ~= nil then
        if drawable._basePolygonCache ~= false then
            drawable.polygon = drawable._basePolygonCache
        end
        return
    end

    local polygon = select_base_polygon(drawable)
    if polygon then
        drawable._basePolygonCache = polygon
        drawable.polygon = polygon
    else
        drawable._basePolygonCache = false
    end
end

local function resolve_drawable_radius(drawable)
    if not drawable then
        return 0
    end

    if drawable._lightingRadius then
        return drawable._lightingRadius
    end

    local parts = drawable.parts
    if type(parts) ~= "table" then
        drawable._lightingRadius = 0
        return 0
    end

    local maxRadius = 0
    for i = 1, #parts do
        local part = parts[i]
        if part then
            local radius = compute_part_radius(part)
            if radius > maxRadius then
                maxRadius = radius
            end
        end
    end

    drawable._lightingRadius = maxRadius
    return maxRadius
end

local function draw_polygon_part(part, palette, defaults)
    local points = part.points
    if type(points) ~= "table" or #points < 6 then
        return
    end

    love.graphics.push()
    apply_transform(part)

    local base_color = resolve_color(palette, part.fill or part.tag or "default", defaults.fill)
    local fill_alpha = part.alpha or base_color[4] or defaults.alpha or 1
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], fill_alpha)
    local mode = part.mode or "fill"
    love.graphics.polygon(mode, points)

    if part.stroke ~= false and mode ~= "line" then
        local stroke_color = resolve_color(palette, part.stroke or "outline", defaults.stroke)
        local stroke_alpha = part.strokeAlpha or stroke_color[4] or fill_alpha
        love.graphics.setColor(stroke_color[1], stroke_color[2], stroke_color[3], stroke_alpha)
        love.graphics.setLineWidth(part.strokeWidth or defaults.strokeWidth or 2)
        love.graphics.polygon("line", points)
    end

    love.graphics.pop()
end

local function draw_ellipse_part(part, palette, defaults)
    local radius_x = part.radiusX or (part.width and part.width * 0.5) or part.radius or defaults.ellipseRadius or 5
    local radius_y = part.radiusY or (part.height and part.height * 0.5) or part.length or radius_x

    love.graphics.push()
    apply_transform(part)

    local blend = part.blend
    if blend then
        love.graphics.setBlendMode(blend)
    end

    local base_color = resolve_color(palette, part.fill or part.tag or "default", defaults.fill)
    local fill_alpha = part.alpha or base_color[4] or defaults.alpha or 1
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], fill_alpha)
    love.graphics.ellipse(part.mode or "fill", part.centerX or 0, part.centerY or 0, radius_x, radius_y)

    if part.stroke and part.stroke ~= false then
        local stroke_color = resolve_color(palette, part.stroke, defaults.stroke)
        local stroke_alpha = part.strokeAlpha or stroke_color[4] or fill_alpha
        love.graphics.setColor(stroke_color[1], stroke_color[2], stroke_color[3], stroke_alpha)
        love.graphics.setLineWidth(part.strokeWidth or defaults.strokeWidth or 1)
        love.graphics.ellipse("line", part.centerX or 0, part.centerY or 0, radius_x, radius_y)
    end

    if blend then
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

local function ensure_palette(drawable, entity)
    if not drawable.colors or not next(drawable.colors) then
        drawable.colors = {
            hull = { 0.2, 0.3, 0.5, 1 },
            outline = { 0.1, 0.15, 0.3, 1 },
            cockpit = { 0.15, 0.25, 0.45, 1 },
            wing = { 0.25, 0.35, 0.55, 1 },
            accent = { 0.5, 0.3, 0.8, 1 },
            core = { 0.7, 0.5, 1, 0.95 },
            engine = { 0.8, 0.4, 0.6, 1 },
            spike = { 0.3, 0.4, 0.7, 1 },
            fin = { 0.35, 0.45, 0.65, 1 },
            default = { 0.2, 0.3, 0.5, 1 },
        }
    end
    
    if not drawable.colors.default then
        drawable.colors.default = drawable.colors.hull or { 0.2, 0.3, 0.5, 1 }
    end
end

local function draw_ship_generic(entity, context)
    local drawable = entity.drawable
    local parts = drawable and drawable.parts
    if type(parts) ~= "table" or #parts == 0 then
        return false
    end

    ensure_palette(drawable, entity)
    local palette = drawable.colors
    
    local default_fill = normalise_color(palette.hull or { 0.2, 0.3, 0.5, 1 })
    local default_stroke = normalise_color(palette.outline or { 0.1, 0.15, 0.3, 1 })
    
    local defaults = {
        fill = default_fill,
        stroke = default_stroke,
        strokeWidth = drawable.defaultStrokeWidth or 2,
        ellipseRadius = drawable.defaultEllipseRadius or 5,
        alpha = 1,
    }

    local radius = resolve_drawable_radius(drawable)

    ensure_base_polygon(drawable)

    love.graphics.push("all")

    love.graphics.translate(entity.position.x, entity.position.y)
    love.graphics.rotate(entity.rotation or 0)

    for i = 1, #parts do
        local part = parts[i]
        local part_type = part.type or "polygon"

        if part_type == "polygon" then
            draw_polygon_part(part, palette, defaults)

            local mirror = part.mirror or part.mirrorX or part.mirrorHorizontal
            if mirror then
                local mirrored = {}
                for key, value in pairs(part) do
                    mirrored[key] = value
                end
                mirrored.points = mirror_points(part.points)
                mirrored.mirror = nil
                mirrored.mirrorX = nil
                mirrored.mirrorHorizontal = nil
                draw_polygon_part(mirrored, palette, defaults)
            end
        elseif part_type == "ellipse" then
            draw_ellipse_part(part, palette, defaults)
        end
    end

    love.graphics.pop()

    return true
end

local function draw_impact_pulses(entity)
    if not entity or not entity.position then
        return
    end

    local pulses = entity.impactPulses
    if type(pulses) ~= "table" or #pulses == 0 then
        return
    end

    local shield = resolve_shield(entity)

    local px = entity.position.x or 0
    local py = entity.position.y or 0
    local rotation = entity.rotation or 0
    local fallbackRadius = shield.visualRadius
        or entity.mountRadius
        or resolve_drawable_radius(entity.drawable)
        or entity.radius
        or 48

    love.graphics.push("all")
    love.graphics.translate(px, py)
    love.graphics.rotate(rotation)
    love.graphics.setBlendMode("add")

    for i = 1, #pulses do
        local pulse = pulses[i]
        local radius = math.max(pulse.radius or fallbackRadius, fallbackRadius)
        local waveRadius = pulse.waveRadius or radius
        local waveThickness = pulse.waveThickness or 3
        local waveAlpha = pulse.waveAlpha or 0
        local ringAlpha = pulse.ringAlpha or 0
        local glowAlpha = pulse.glowAlpha or 0
        local coreAlpha = pulse.coreAlpha or 0
        local coreRadius = pulse.coreRadius or 4
        local impactX = pulse.impactX or 0
        local impactY = pulse.impactY or 0

        if glowAlpha > 0.01 then
            local pulseType = pulse.pulseType or "shield"
            local glowColor = pulseType == "hull" and ship_renderer.HULL_GLOW_COLOR or ship_renderer.SHIELD_GLOW_COLOR
            
            love.graphics.setColor(
                glowColor[1],
                glowColor[2],
                glowColor[3],
                glowAlpha * 0.35
            )
            love.graphics.circle("fill", 0, 0, radius * 1.12)
            
            love.graphics.setColor(
                glowColor[1],
                glowColor[2],
                glowColor[3],
                glowAlpha * 0.2
            )
            love.graphics.circle("fill", 0, 0, radius * 1.25)
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

ship_renderer.draw_shield_pulses = draw_impact_pulses

local function draw_health_bar(entity)
    local health = entity.health
    if not (health and health.max and health.max > 0) then
        return
    end

    local bar = entity.healthBar or ship_bar_defaults
    if not bar or entity.player then
        return
    end

    local showTimer = health.showTimer or 0
    local showDuration = bar.showDuration or ship_bar_defaults.show_duration or 0
    if showDuration > 0 then
        if showTimer <= 0 then
            return
        end
    end

    local pct = math.max(0, math.min(1, (health.current or 0) / health.max))
    local baseWidth = bar.width or ship_bar_defaults.width or 60
    local width = baseWidth * 0.5
    local height = bar.height or ship_bar_defaults.height or 5
    local offset = math.abs(bar.offset or ship_bar_defaults.offset or 32)
    local halfWidth = width * 0.5

    local alpha
    if showDuration > 0 then
        alpha = math.min(1, showTimer / showDuration)
    else
        alpha = 1
    end

    if alpha <= 0 then
        return
    end

    love.graphics.push()
    love.graphics.translate(entity.position.x, entity.position.y - offset)

    love.graphics.setColor(0, 0, 0, 0.55 * alpha)
    love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width, height)

    if pct > 0 then
        love.graphics.setColor(0.35, 1, 0.6, alpha)
        love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width * pct, height)
    end

    love.graphics.setColor(0, 0, 0, 0.9 * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", -halfWidth, -height * 0.5, width, height)

    local level = resolve_entity_level(entity)
    if level then
        local font = love.graphics.getFont()
        local text = tostring(level)
        local paddingX, paddingY = 3, 2
        local textWidth = font and font:getWidth(text) or (#text * 6)
        local textHeight = font and font:getHeight() or 10
        local badgeWidth = textWidth + paddingX * 2
        local badgeHeight = math.max(textHeight + paddingY * 2, height)
        local badgeX = halfWidth + 6
        local badgeY = -badgeHeight * 0.5

        love.graphics.setColor(0, 0, 0, 0.55 * alpha)
        love.graphics.rectangle("fill", badgeX, badgeY, badgeWidth, badgeHeight)

        love.graphics.setColor(0, 0, 0, 0.9 * alpha)
        love.graphics.rectangle("line", badgeX, badgeY, badgeWidth, badgeHeight)

        love.graphics.setColor(0.82, 0.88, 0.93, alpha)
        love.graphics.print(text, badgeX + paddingX, badgeY + paddingY)
    end

    love.graphics.pop()
end

function ship_renderer.draw_body(entity, context)
    local drawable = entity.drawable
    if not drawable then
        return false
    end

    return draw_ship_generic(entity, context)
end

function ship_renderer.draw(entity, context)
    if not ship_renderer.draw_body(entity, context) then
        return
    end

    draw_impact_pulses(entity)
    draw_health_bar(entity)
end

return ship_renderer
