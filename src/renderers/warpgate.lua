---@diagnostic disable: undefined-global
-- Warpgate renderer
-- Renders warpgate structures and the portal visual. Uses a pair of
-- shader effects (online/offline) and a structured drawable for the body.
local drawable_helpers = require("src.renderers.drawable_helpers")
local ship_renderer = require("src.renderers.ship")

local love = love

local warpgate_renderer = {}

--- Create a shader from source with error handling.
local function load_shader(label, source)
    local ok, shaderOrError = pcall(love.graphics.newShader, source)
    if not ok then
        print(string.format("[warpgate_renderer] Failed to load %s shader: %s", label, shaderOrError))
        return nil
    end
    return shaderOrError
end

local portal_shader = load_shader("portal", [[
    extern vec2 portalCenter;
    extern float radius;
    extern float time;
    extern float energy;
    extern vec4 coreColor;
    extern vec4 midColor;
    extern vec4 rimColor;

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
    }

    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float a = hash(i);
        float b = hash(i + vec2(1.0, 0.0));
        float c = hash(i + vec2(0.0, 1.0));
        float d = hash(i + vec2(1.0, 1.0));
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }

    float fbm(vec2 p) {
        float value = 0.0;
        float amplitude = 0.5;
        mat2 rot = mat2(0.8660254, 0.5, -0.5, 0.8660254);
        for (int i = 0; i < 4; ++i) {
            value += amplitude * noise(p);
            p = rot * p * 2.0 + vec2(40.0);
            amplitude *= 0.5;
        }
        return value;
    }

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 rel = (screen_coords - portalCenter) / max(radius, 0.0001);
        float r = length(rel);
        if (r > 1.12) {
            return vec4(0.0);
        }

        float angle = atan(rel.y, rel.x);
        float swirlSpeed = 0.8 + energy * 0.6;
        float swirl = angle * (3.0 + energy * 2.0) - time * swirlSpeed;

        float turbulence = fbm(rel * (3.6 + energy * 1.4) + time * 0.25);
        float bands = sin(r * (18.0 + energy * 4.0) - time * (2.4 + energy * 1.2) + swirl);
        float sparks = sin(angle * 12.0 + time * 3.0 + fbm(rel * 8.0));

        float core = exp(-r * (3.6 - energy * 0.5));
        float pulse = 0.65 + 0.35 * sin(time * (1.7 + energy * 1.3));
        float intensity = clamp(core * (1.1 + energy * 0.7) + turbulence * 0.35 + bands * 0.12, 0.0, 1.2);
        intensity = mix(intensity, 1.0, pow(max(0.0, 1.0 - r), 6.0) * (0.5 + energy * 0.5));

        vec3 base = mix(midColor.rgb, coreColor.rgb, clamp(intensity, 0.0, 1.0));
        base += (0.08 + 0.15 * energy) * (sparks * 0.5 + turbulence * 0.4);

        float rim = smoothstep(0.82, 0.98, r) * rimColor.a;
        vec3 colorMix = mix(base, rimColor.rgb, rim * (0.6 + 0.2 * energy));
        float alpha = clamp(core * coreColor.a * (1.0 + energy * 0.5) + pulse * 0.25, 0.0, 1.0);
        alpha += rim * 0.4;
        alpha *= (1.0 - smoothstep(1.0, 1.12, r));

        colorMix = clamp(colorMix, 0.0, 1.0);

        return vec4(colorMix, alpha) * color;
    }
]])

--- Ensure the drawable's palette contains all expected keys with
--- sensible fallbacks.
local function ensure_palette(drawable)
    if type(drawable.colors) ~= "table" then
        drawable.colors = {}
    end

    local colors = drawable.colors
    colors.frame = colors.frame or { 0.08, 0.13, 0.2, 1 }
    colors.trim = colors.trim or { 0.32, 0.52, 0.92, 1 }
    colors.glow = colors.glow or { 0.36, 0.86, 1.0, 0.9 }
    colors.conduit = colors.conduit or { 0.18, 0.6, 0.92, 1 }
    colors.spine = colors.spine or { 0.12, 0.16, 0.24, 1 }
    colors.accent = colors.accent or { 0.62, 0.92, 1.0, 0.85 }
    colors.portal = colors.portal or { 0.3, 0.86, 1.0, 0.9 }
    colors.portalRim = colors.portalRim or { 0.78, 0.98, 1.0, 1.0 }
    colors.portalOffline = colors.portalOffline or { 0.12, 0.18, 0.3, 0.95 }
    colors.portalCore = colors.portalCore or { 0.42, 0.74, 1.0, 0.95 }
    colors.default = colors.default or colors.frame
    return colors
end

--- Resolve default drawing options from the palette (stroke width, alpha etc.)
local function resolve_defaults(drawable, palette)
    return {
        fill = palette.frame,
        stroke = palette.trim,
        strokeWidth = drawable.defaultStrokeWidth or 3,
        ellipseRadius = drawable.defaultEllipseRadius or 5,
        alpha = 1,
    }
end

--- Draw static warpgate structure from drawable parts.
local function draw_structure(entity, palette, defaults)
    local drawable = entity.drawable
    if not drawable or type(drawable.parts) ~= "table" then
        return
    end

    drawable_helpers.draw_parts(drawable.parts, palette, defaults)
end

--- Draw warpgate portal using shader or fallback mode.
local function draw_portal(entity, palette)
    local warpgate = entity.warpgate or {}
    local radius = entity.portalRadius or (entity.mountRadius and entity.mountRadius * 0.45) or 120
    local shader = portal_shader

    local energyCurrent = warpgate.energy or warpgate.energyMax or warpgate.maxEnergy or 0
    local energyMax = warpgate.energyMax or warpgate.maxEnergy or 1
    local energy = 0
    if energyMax > 0 then
        energy = energyCurrent / energyMax
    end
    if warpgate.status == "offline" then
        energy = 0
    end
    energy = math.max(0, math.min(1, energy))
    local shaderEnergy = 0.25 + energy * 0.75

    local coreColor = drawable_helpers.normalise_color(palette.portalCore, { 0.55, 0.92, 1.0, 1.0 })
    local midColor = drawable_helpers.normalise_color(palette.portal or palette.portalOffline, { 0.16, 0.42, 0.94, 0.92 })
    local rimColor = drawable_helpers.normalise_color(palette.portalRim or palette.accent, { 0.7, 0.95, 1.0, 1.0 })

    love.graphics.push()
    local centerX, centerY = love.graphics.transformPoint(0, 0)

    if shader then
        shader:send("portalCenter", { centerX, centerY })
        shader:send("radius", radius)
        shader:send("time", love.timer.getTime())
        shader:send("energy", shaderEnergy)
        shader:send("coreColor", coreColor)
        shader:send("midColor", midColor)
        shader:send("rimColor", rimColor)
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", 0, 0, radius * 1.1)
        love.graphics.setShader()
    else
        love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], coreColor[4] or 1)
        love.graphics.circle("fill", 0, 0, radius)
    end

    love.graphics.setLineWidth(math.max(2, radius * 0.06))
    love.graphics.setColor(rimColor[1], rimColor[2], rimColor[3], (rimColor[4] or 1) * 0.85)
    love.graphics.circle("line", 0, 0, radius * 1.05)

    if energy > 0.05 then
        love.graphics.setBlendMode("add")
        local arcColor = coreColor
        love.graphics.setColor(arcColor[1], arcColor[2], arcColor[3], (arcColor[4] or 1) * 0.3)
        local arcRadius = radius * 1.18
        local span = math.pi * 0.55
        local time = love.timer.getTime()
        for i = 1, 4 do
            local offset = (time * (0.35 + i * 0.05) + i * 1.42) % (math.pi * 2)
            love.graphics.arc("line", "open", 0, 0, arcRadius, offset, offset + span)
        end
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

function warpgate_renderer.draw(entity, context)
    if not (entity and entity.position and entity.drawable) then
        return
    end

    love.graphics.push("all")
    love.graphics.translate(entity.position.x or 0, entity.position.y or 0)
    love.graphics.rotate(entity.rotation or 0)

    local palette = ensure_palette(entity.drawable)
    local defaults = resolve_defaults(entity.drawable, palette)

    draw_structure(entity, palette, defaults)
    draw_portal(entity, palette)

    love.graphics.pop()

    ship_renderer.draw_shield_pulses(entity)
end

return warpgate_renderer
