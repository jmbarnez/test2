-- Explosion renderer
-- Provides a shader-based (and fallback) rendering for explosion effects,
-- including core color, glow and ring. The shader parameters are driven
-- by explosion instance data (position, radius, color, progress).
local love = love
local lg = love.graphics

local explosion_renderer = {}

local explosionShader
do
    local shaderSource = [[
        extern vec2 explosionCenter;
        extern float innerRadius;
        extern float outerRadius;
        extern float ringRadius;
        extern float ringWidth;
        extern float progress;
        extern float time;
        extern float intensityScale;
        extern vec4 coreColor;
        extern vec4 glowColor;
        extern vec4 ringColor;

        float saturate(float value) {
            return clamp(value, 0.0, 1.0);
        }

        float hash(vec2 p) {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec2 rel = screen_coords - explosionCenter;
            float dist = length(rel);
            if (dist > outerRadius * 1.8) {
                return vec4(0.0);
            }

            float inner = max(innerRadius, 0.0001);
            float outer = max(outerRadius, inner + 0.0001);
            float normalized = dist / outer;

            float heat = exp(-pow(dist / inner, 1.35));
            float glow = exp(-pow(normalized * 1.18, 3.1));

            float effectiveRingWidth = max(ringWidth, 0.0025 * outer);
            float ringFalloff = exp(-pow((dist - ringRadius) / effectiveRingWidth, 2.0));
            float shock = saturate(1.0 - abs(dist - ringRadius * (0.75 + progress * 0.25)) / (effectiveRingWidth * 1.5));

            vec2 noiseCoord = rel * 0.035 + vec2(time * 0.22, time * -0.17) + vec2(progress * 1.3, progress * 2.1);
            float noiseVal = hash(noiseCoord);
            float flicker = 0.88 + 0.12 * sin(time * 14.0 + noiseVal * 6.28318);
            float band = 0.82 + 0.18 * sin(dot(rel, vec2(5.3, -3.7)) * 0.025 + time * 9.0);

            float lifeFade = saturate(1.0 - progress * 0.85);
            float brightness = (heat * 1.35 + glow * 0.8) * (lifeFade + 0.2);
            brightness += ringFalloff * (0.4 + shock * 0.6);
            brightness *= intensityScale * flicker * band;

            float alpha = saturate(brightness);

            vec3 colorOut = coreColor.rgb * (heat * 1.2) + glowColor.rgb * (glow * 0.9) + ringColor.rgb * (ringFalloff * 0.85);
            colorOut = clamp(colorOut, vec3(0.0), vec3(1.35));

            float finalAlpha = alpha * max(coreColor.a, max(glowColor.a, ringColor.a));
            return vec4(colorOut, saturate(finalAlpha));
        }
    ]]

    local ok, shaderOrError = pcall(lg.newShader, shaderSource)
    if ok then
        explosionShader = shaderOrError
    else
        print("Failed to load explosion shader:", shaderOrError)
    end
end

local DEFAULT_CORE_COLOR = { 1.0, 0.62, 0.26, 0.95 }
local DEFAULT_RING_COLOR = { 1.0, 0.82, 0.48, 0.82 }

--- Clamp a number to [0, 1]
local function clamp01(value)
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

--- Ensure an RGBA color table exists; fall back to the provided default.
-- @param src table|nil color source
-- @param fallback table default RGBA
local function ensure_color(src, fallback)
    local base = src or fallback
    local fb = fallback
    return {
        base[1] or fb[1] or 1,
        base[2] or fb[2] or 1,
        base[3] or fb[3] or 1,
        base[4] or fb[4] or 1,
    }
end

--- Heuristically derive a glow color from core and ring colors.
local function derive_glow_color(coreColor, ringColor)
    return {
        clamp01(coreColor[1] * 0.55 + 0.45),
        clamp01(coreColor[2] * 0.55 + 0.45),
        clamp01((ringColor[3] * 0.6) + (coreColor[3] * 0.25) + 0.15),
        clamp01(math.max(coreColor[4], ringColor[4]) * 0.6),
    }
end

--- Draw a table of explosion entries. This handles both shader and
--- non-shader fallback rendering. Each explosion entry should contain
--- x,y position and radius, as well as optional color fields and timing.
-- @param explosions table array of explosion entries
function explosion_renderer.draw(explosions)
    if not (explosions and #explosions > 0) then
        return
    end

    lg.push("all")
    lg.setBlendMode("add")

    local shader = explosionShader
    local currentTime
    if shader then
        currentTime = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
        shader:send("time", currentTime)
    end

    for i = 1, #explosions do
        local e = explosions[i]
        local radius = e.radius or 0
        if radius > 0 then
            if shader then
                local baseColor = ensure_color(e.color, DEFAULT_CORE_COLOR)
                local ringColor = ensure_color(e.ringColor, DEFAULT_RING_COLOR)
                local glowColor = ensure_color(e.glowColor, derive_glow_color(baseColor, ringColor))

                local innerRadius = math.max(e.startRadius or radius * 0.6, radius * 0.35)
                local outerRadius = radius
                local ringRadius = e.ringRadius or outerRadius * 0.95
                local ringWidth = math.max(e.ringWidth or outerRadius * 0.15, outerRadius * 0.08)
                local progress = 1 - math.max(0, (e.lifetime or 0) / (e.maxLifetime or 1))
                local intensityScale = math.max(0.05, e.baseAlpha or baseColor[4] or 1)

                shader:send("explosionCenter", { e.x or 0, e.y or 0 })
                shader:send("innerRadius", innerRadius)
                shader:send("outerRadius", outerRadius)
                shader:send("ringRadius", ringRadius)
                shader:send("ringWidth", ringWidth)
                shader:send("progress", progress)
                shader:send("intensityScale", intensityScale)
                shader:send("coreColor", baseColor)
                shader:send("glowColor", glowColor)
                shader:send("ringColor", ringColor)

                lg.setShader(shader)
                lg.setColor(1, 1, 1, 1)
                local renderRadius = outerRadius + ringWidth * 2.2
                renderRadius = math.max(renderRadius, innerRadius * 1.35)
                lg.rectangle("fill", (e.x or 0) - renderRadius, (e.y or 0) - renderRadius, renderRadius * 2, renderRadius * 2)
                lg.setShader()
            else
                if e.color then
                    lg.setColor(e.color[1] or 1, e.color[2] or 1, e.color[3] or 1, e.color[4] or 1)
                else
                    lg.setColor(1, 1, 1, 0.8)
                end
                lg.circle("fill", e.x or 0, e.y or 0, radius)

                if e.ringColor then
                    lg.setColor(e.ringColor[1] or 1, e.ringColor[2] or 1, e.ringColor[3] or 1, e.ringColor[4] or 1)
                    local ringRadiusFallback = e.ringRadius or radius * 0.85
                    local lineWidth = e.ringWidth or math.max(2, radius * 0.1)
                    lg.setLineWidth(lineWidth)
                    lg.circle("line", e.x or 0, e.y or 0, ringRadiusFallback)
                end
            end
        end
    end

    lg.pop()
end

return explosion_renderer
