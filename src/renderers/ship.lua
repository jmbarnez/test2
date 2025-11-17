---@diagnostic disable: undefined-global

-- Ship renderer
-- Responsible for drawing ship body parts, shields and hull VFX. This uses
-- a shader to render shield impacts and provides fallback rendering when
-- shader support isn't available. It also exposes a few color constants
-- to keep shield/hull color values consistent across the codebase.
local constants = require("src.constants.game")
local vector = require("src.util.vector")
local drawable_helpers = require("src.renderers.drawable_helpers")
local shield_renderer = require("src.renderers.shield_renderer")
local hud_health_bar = require("src.renderers.hud_health_bar")
local table_util = require("src.util.table")

local normalise_color = drawable_helpers.normalise_color

local TWO_PI = math.pi * 2

local ship_renderer = {}
local ship_bar_defaults = constants.ships and constants.ships.health_bar or {}
local weapon_draw_defaults = constants.weapons and constants.weapons.render or {}

local CHARGE_PREVIEW_COLOR = weapon_draw_defaults.gravitronChargeColor or { 0.5, 0.8, 1.0, 0.35 }
local CHARGE_PREVIEW_GLOW = weapon_draw_defaults.gravitronChargeGlow or { 0.5, 0.9, 1.0, 0.22 }
local CHARGE_PREVIEW_OUTLINE = weapon_draw_defaults.gravitronChargeOutline or { 0.2, 0.6, 1.0, 0.55 }
local CHARGE_PREVIEW_MIN_RADIUS = weapon_draw_defaults.gravitronChargeMinRadius or 12

ship_renderer.SHIELD_RING_COLOR = { 0.35, 0.95, 1.0, 0.85 }
ship_renderer.SHIELD_GLOW_COLOR = { 0.18, 0.7, 1.0, 0.9 }
ship_renderer.SHIELD_IMPACT_COLOR = { 0.82, 0.98, 1.0, 1.0 }
ship_renderer.HULL_GLOW_COLOR = { 0.85, 0.9, 1.0, 0.85 }

local shieldImpactShader
do
    local shaderSource = [[
        extern vec2 shipCenter;
        extern mat2 invShipMatrix;
        extern vec2 impactLocal;
        extern float shieldRadius;
        extern float waveRadius;
        extern float waveThickness;
        extern float impactIntensity;
        extern float glowAlpha;
        extern float waveAlpha;
        extern float ringAlpha;
        extern float coreAlpha;
        extern float progress;
        extern float time;
        extern vec4 glowColor;
        extern vec4 impactColor;

        float saturate(float value) {
            return clamp(value, 0.0, 1.0);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec2 localPos = invShipMatrix * (screen_coords - shipCenter);
            float distCenter = length(localPos);
            float shieldEdgeDist = distCenter - shieldRadius;
            float shieldScale = max(0.0001, shieldRadius);

            vec2 impactVec = localPos - impactLocal;
            float impactDist = length(impactVec);

            float rimWidth = max(0.0025 * shieldScale, shieldRadius * 0.15);
            float rim = exp(-pow(shieldEdgeDist / max(0.0001, rimWidth), 2.0));

            float waveBand = 1.0 - smoothstep(
                waveRadius - waveThickness,
                waveRadius + waveThickness,
                distCenter
            );

            float directionalFalloff = exp(-pow(impactDist / max(0.0001, shieldScale * 0.55), 2.0));
            float impactFlash = exp(-pow(impactDist / max(0.0001, shieldScale * 0.3), 2.0));

            float pulseFade = saturate(1.0 - progress * 1.05);

            float glowTerm = glowAlpha * rim * (0.2 + directionalFalloff * 0.8);
            float ringTerm = ringAlpha * rim * directionalFalloff;
            float waveTerm = waveAlpha * waveBand * directionalFalloff;
            float coreTerm = coreAlpha * impactFlash;

            float intensity = glowTerm * 0.35 + ringTerm * 0.9 + waveTerm * 1.1 + coreTerm;
            intensity *= (0.35 + impactIntensity * 0.8);

            float flicker = 0.9 + 0.1 * sin(dot(localPos, vec2(3.71, 4.23)) + time * 18.0);
            intensity *= flicker;

            intensity *= pulseFade;
            intensity = clamp(intensity, 0.0, 1.5);

            vec3 baseColor = mix(glowColor.rgb, impactColor.rgb, saturate(impactIntensity * 1.2));
            float alpha = saturate(intensity) * impactColor.a;

            return vec4(baseColor * intensity, alpha);
        }
    ]]

    local ok, shaderOrError = pcall(love.graphics.newShader, shaderSource)
    if ok then
        shieldImpactShader = shaderOrError
    else
        print("Failed to load shield impact shader:", shaderOrError)
    end
end

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

--- Generic ship body drawing. This will render shape parts and colors
-- according to the drawable layout. It does not render shield pulses
-- or overlays; those are handled separately.
-- @param entity table
-- @param context table
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

    local dispatcher = drawable._partDispatcher
    if not dispatcher then
        dispatcher = {
            polygon = function(part, pal, def)
                drawable_helpers.draw_polygon_part(part, pal, def)

                local mirror = part.mirror or part.mirrorX or part.mirrorHorizontal
                if not mirror then
                    return true
                end

                local mirrored = drawable_helpers.clone_part(part)
                mirrored.points = drawable_helpers.mirror_points(part.points)
                mirrored.mirror = nil
                mirrored.mirrorX = nil
                mirrored.mirrorHorizontal = nil
                drawable_helpers.draw_polygon_part(mirrored, pal, def)

                return true
            end,
            ellipse = function(part, pal, def)
                drawable_helpers.draw_ellipse_part(part, pal, def)
                return true
            end,
        }
        drawable._partDispatcher = dispatcher
    end

    drawable_helpers.draw_parts_with_dispatcher(parts, palette, defaults, dispatcher, context)

    love.graphics.pop()

    return true
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

    ship_renderer.draw_weapon_charge_preview(entity, context)
    ship_renderer.draw_shield_pulses(entity)
    ship_renderer.draw_health_bar(entity)
end

local function draw_charge_preview_circle(x, y, radius, innerRadius)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(CHARGE_PREVIEW_GLOW[1], CHARGE_PREVIEW_GLOW[2], CHARGE_PREVIEW_GLOW[3], CHARGE_PREVIEW_GLOW[4])
    love.graphics.circle("fill", x, y, radius)

    love.graphics.setColor(CHARGE_PREVIEW_COLOR[1], CHARGE_PREVIEW_COLOR[2], CHARGE_PREVIEW_COLOR[3], CHARGE_PREVIEW_COLOR[4])
    love.graphics.circle("fill", x, y, innerRadius)

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(CHARGE_PREVIEW_OUTLINE[1], CHARGE_PREVIEW_OUTLINE[2], CHARGE_PREVIEW_OUTLINE[3], CHARGE_PREVIEW_OUTLINE[4])
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, radius)
    love.graphics.setLineWidth(1)
end

local function resolve_weapon_charge_preview(entity)
    if not (entity and entity.weapon) then
        return nil
    end

    local weapon = entity.weapon
    if weapon.constantKey ~= "gravitron_orb" then
        return nil
    end

    local scale = weapon._chargeScale
    if not scale or scale <= 0 then
        return nil
    end

    local mount = entity.weaponMount or {}
    local offsetForward = mount.forward or mount.length or (weapon.offset or 0)
    local offsetLateral = mount.lateral or 0
    local offsetVertical = mount.vertical or 0
    local offsetX = mount.offsetX or 0
    local offsetY = mount.offsetY or 0

    local position = entity.position or { x = 0, y = 0 }
    local rotation = entity.rotation or 0
    local cosRot = math.cos(rotation)
    local sinRot = math.sin(rotation)

    local muzzleX = position.x
    local muzzleY = position.y

    muzzleX = muzzleX + cosRot * (offsetForward - offsetVertical) - sinRot * (offsetLateral + offsetX)
    muzzleY = muzzleY + sinRot * (offsetForward - offsetVertical) + cosRot * (offsetLateral + offsetX)
    muzzleX = muzzleX + cosRot * offsetY
    muzzleY = muzzleY + sinRot * offsetY

    local baseSize = weapon.projectileSize or 3.2
    local drawable = weapon.projectileBlueprint and weapon.projectileBlueprint.drawable
    if drawable and drawable.size then
        baseSize = drawable.size
    end

    local radius = math.max(CHARGE_PREVIEW_MIN_RADIUS, (baseSize * 4) * scale)
    local innerRadius = radius * 0.6

    return {
        x = muzzleX,
        y = muzzleY,
        radius = radius,
        innerRadius = innerRadius,
    }
end

function ship_renderer.draw_weapon_charge_preview(entity, context)
    local preview = resolve_weapon_charge_preview(entity)
    if not preview then
        return
    end

    love.graphics.push("all")
    draw_charge_preview_circle(preview.x, preview.y, preview.radius, preview.innerRadius)
    love.graphics.pop()
end

local function draw_shield_pulses(entity)
    shield_renderer.draw(entity, {
        shader = shieldImpactShader,
        resolveDrawableRadius = function(_, drawable)
            return resolve_drawable_radius(drawable)
        end,
        hullGlowColor = ship_renderer.HULL_GLOW_COLOR,
        shieldGlowColor = ship_renderer.SHIELD_GLOW_COLOR,
        shieldImpactColor = ship_renderer.SHIELD_IMPACT_COLOR,
    })
end

local function draw_health_bar(entity)
    hud_health_bar.draw(entity, {
        defaults = {
            width = ship_bar_defaults.width or 60,
            height = ship_bar_defaults.height or 5,
            offset = math.abs(ship_bar_defaults.offset or 32),
            showDuration = ship_bar_defaults.show_duration or 0,
            backgroundColor = { 0, 0, 0, 0.55 },
            fillColor = { 0.35, 1, 0.6, 1 },
            borderColor = { 0, 0, 0, 0.9 },
        },
    })
end

ship_renderer.draw_shield_pulses = draw_shield_pulses
ship_renderer.draw_health_bar = draw_health_bar

return ship_renderer
