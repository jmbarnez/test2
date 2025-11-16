---@diagnostic disable: undefined-global

local drawable_helpers = require("src.renderers.drawable_helpers")
local ship_renderer = require("src.renderers.ship")

local love = love

local warpgate_renderer = {}

local function load_shader(label, source)
    local ok, shaderOrError = pcall(love.graphics.newShader, source)
    if not ok then
        print(string.format("[warpgate_renderer] Failed to load %s shader: %s", label, shaderOrError))
        return nil
    end
    return shaderOrError
end

local offline_shader = load_shader("offline", [[
    extern vec2 portalCenter;
    extern float radius;
    extern float time;
    extern vec4 innerColor;
    extern vec4 outerColor;
    extern vec4 rimColor;
    extern float energy;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 rel = (screen_coords - portalCenter) / max(radius, 0.0001);
        float r = length(rel);
        float angle = atan(rel.y, rel.x);
        float swirl = sin(angle * 3.0 - time * 0.7);
        float ripple = sin(r * 18.0 - time * 1.4 + swirl * 0.25);
        float fade = smoothstep(1.0, 0.2, r);
        float flux = 0.35 + 0.25 * sin(time * 0.8 + ripple * 0.6);
        float pulse = pow(max(0.0, 1.0 - r), 1.6) * (0.7 + 0.3 * energy);
        vec3 base = mix(outerColor.rgb, innerColor.rgb, clamp(pulse + swirl * 0.05 + flux * 0.2, 0.0, 1.0));
        float alpha = (innerColor.a * pulse + outerColor.a * fade * 0.35) * (0.65 + energy * 0.2);
        float rim = smoothstep(1.0, 0.85, r) * rimColor.a * 0.8;
        vec3 colorMix = mix(base, rimColor.rgb, rim);
        return vec4(colorMix, clamp(alpha + rim, 0.0, 1.0));
    }
]])

local online_shader = load_shader("online", [[
    extern vec2 portalCenter;
    extern float radius;
    extern float time;
    extern vec4 innerColor;
    extern vec4 outerColor;
    extern vec4 rimColor;
    extern float energy;

    float noise(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }

    float fbm(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        vec2 shift = vec2(100.0);
        mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
        for (int i = 0; i < 4; ++i) {
            v += a * noise(p);
            p = rot * p * 2.0 + shift;
            a *= 0.5;
        }
        return v;
    }

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 rel = (screen_coords - portalCenter) / max(radius, 0.0001);
        float r = length(rel);
        float angle = atan(rel.y, rel.x);
        float swirl = sin(angle * 5.0 + time * 2.2);
        float spiral = sin(r * 22.0 - time * 6.5 + swirl);
        float turbulence = fbm(rel * 3.5 + time * 0.35);
        float flux = 0.6 + 0.4 * sin(time * (3.0 + energy * 4.0) + turbulence * 3.5);
        float core = pow(max(0.0, 1.0 - r), 1.2 + energy * 0.6);
        float band = smoothstep(0.95, 0.2, r);
        float intensity = clamp(core + spiral * 0.15 + turbulence * 0.25 + flux * 0.3, 0.0, 1.0);
        vec3 base = mix(outerColor.rgb, innerColor.rgb, intensity);
        float alpha = (innerColor.a * core + outerColor.a * band * 0.6) * (0.8 + energy * 0.4);
        float rim = smoothstep(1.02, 0.8, r) * rimColor.a;
        vec3 colorMix = mix(base, rimColor.rgb, rim * (0.7 + 0.3 * energy));
        return vec4(colorMix, clamp(alpha + rim, 0.0, 1.0));
    }
]])

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

local function resolve_defaults(drawable, palette)
    return {
        fill = palette.frame,
        stroke = palette.trim,
        strokeWidth = drawable.defaultStrokeWidth or 3,
        ellipseRadius = drawable.defaultEllipseRadius or 5,
        alpha = 1,
    }
end

local function draw_structure(entity, palette, defaults)
    local drawable = entity.drawable
    if not drawable or type(drawable.parts) ~= "table" then
        return
    end

    drawable_helpers.draw_parts(drawable.parts, palette, defaults)
end

local function draw_portal(entity, palette)
    local warpgate = entity.warpgate or {}
    local online = warpgate.online and warpgate.status ~= "offline"
    local radius = entity.portalRadius or (entity.mountRadius and entity.mountRadius * 0.45) or 120
    local shader = online and online_shader or offline_shader

    local energyCurrent = warpgate.energy or (online and warpgate.energyMax) or 0
    local energyMax = warpgate.energyMax or (warpgate.maxEnergy) or 1
    local energy = math.max(0, math.min(1, energyCurrent / math.max(energyMax, 1)))
    if online and energy <= 0 then
        energy = 0.65
    end

    local innerColor = online and palette.portalCore or palette.portalOffline
    local outerColor = online and palette.portal or palette.spine
    local rimColor = palette.portalRim or palette.accent

    love.graphics.push()
    local centerX, centerY = love.graphics.transformPoint(0, 0)

    if shader then
        shader:send("portalCenter", { centerX, centerY })
        shader:send("radius", radius)
        shader:send("time", love.timer.getTime())
        shader:send("innerColor", innerColor)
        shader:send("outerColor", outerColor)
        shader:send("rimColor", rimColor)
        shader:send("energy", energy)
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", 0, 0, radius * 1.05)
        love.graphics.setShader()
    else
        love.graphics.setColor(innerColor[1], innerColor[2], innerColor[3], innerColor[4] or 1)
        love.graphics.circle("fill", 0, 0, radius)
    end

    love.graphics.setLineWidth(math.max(2, radius * 0.08))
    love.graphics.setColor(rimColor[1], rimColor[2], rimColor[3], rimColor[4] or 1)
    love.graphics.circle("line", 0, 0, radius * 1.08)

    if online then
        love.graphics.setBlendMode("add")
        local arcColor = palette.glow or palette.portal
        love.graphics.setColor(arcColor[1], arcColor[2], arcColor[3], (arcColor[4] or 1) * 0.85)
        local arcRadius = radius * 1.18
        local span = math.pi * 0.7
        local time = love.timer.getTime()
        for i = 1, 3 do
            local offset = (time * 0.4 + i * 2.1) % (math.pi * 2)
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

    draw_portal(entity, palette)
    draw_structure(entity, palette, defaults)

    love.graphics.pop()

    ship_renderer.draw_shield_pulses(entity)
    ship_renderer.draw_health_bar(entity)
end

return warpgate_renderer
