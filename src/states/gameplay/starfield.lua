---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
local math_util = require("src.util.math")

local love = love

local Starfield = {}

local random_range = math_util.random_float_range
local random_int_range = math_util.random_int_range

local nebulaShader = love.graphics.newShader([[
    extern float nebulaSeed;
    extern float time;
    extern float intensity;
    extern float hueShift;
    extern float saturation;
    extern float finalAlpha;
    
    vec3 hsv2rgb(vec3 c) {
        vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = screen_coords / love_ScreenSize.xy;
        
        // Enhanced parameters with more variation
        float scale = 2.2 + sin(nebulaSeed * 3.14) * 0.8;
        float warp = 1.8 + cos(nebulaSeed * 2.71) * 0.6;
        float contrast = 2.4 + sin(nebulaSeed * 4.33) * 0.8;
        float baseAlpha = 0.7 + cos(nebulaSeed * 5.67) * 0.2;
        float exposure = 1.4 + sin(nebulaSeed * 7.89) * 0.4;
        float paletteShift = sin(nebulaSeed * 12.34) * 0.5;
        float speed = 0.035;
        
        // Multi-layer time animation
        float t1 = time * speed + nebulaSeed * 123.456;
        float t2 = time * speed * 0.7 - nebulaSeed * 87.321;
        float t3 = time * speed * 1.3 + nebulaSeed * 45.678;
        
        // Base coordinates with enhanced seed variation
        vec2 p = uv * scale + vec2(nebulaSeed * 23.45, nebulaSeed * 34.56);
        
        // Multi-layer domain warping
        vec2 q1 = vec2(
            sin(p.x * 0.9 + t1 * 0.4 + nebulaSeed * 6.78) * cos(p.y * 0.7 + t1 * 0.3 + nebulaSeed * 8.90),
            cos(p.x * 0.8 - t1 * 0.35 + nebulaSeed * 4.32) * sin(p.y * 1.1 + t1 * 0.45 + nebulaSeed * 9.87)
        ) * warp;
        
        vec2 q2 = vec2(
            sin(p.x * 1.3 + t2 * 0.25 + nebulaSeed * 11.22) * cos(p.y * 0.85 + t2 * 0.15 + nebulaSeed * 13.44),
            cos(p.x * 0.95 + t2 * 0.3 + nebulaSeed * 15.66) * sin(p.y * 1.25 + t2 * 0.2 + nebulaSeed * 17.88)
        ) * warp * 0.6;
        
        vec2 r = vec2(
            sin(p.x * 1.5 + q1.x * 2.2 + t3 * 0.5 + nebulaSeed * 19.01),
            cos(p.y * 1.4 + q1.y * 2.4 - t3 * 0.4 + nebulaSeed * 21.23)
        ) * warp * 0.4;
        
        // Enhanced multi-octave noise with more layers
        float noise1 = 0.0;
        float noise2 = 0.0;
        float amplitude = 1.0;
        vec2 freq1 = p + q1 + r;
        vec2 freq2 = p + q2 + r * 0.7;
        
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            // Primary noise layer
            noise1 += sin(freq1.x + nebulaSeed * fi * 3.14) * cos(freq1.y + nebulaSeed * fi * 2.71) * amplitude;
            // Secondary noise layer
            noise2 += cos(freq2.x + nebulaSeed * fi * 4.33) * sin(freq2.y + nebulaSeed * fi * 5.67) * amplitude;
            
            freq1 = freq1 * 2.1 + vec2(sin(t1 * 0.12 + nebulaSeed * 1.73), cos(t1 * 0.18 + nebulaSeed * 2.36));
            freq2 = freq2 * 1.9 + vec2(cos(t2 * 0.08 + nebulaSeed * 2.94), sin(t2 * 0.14 + nebulaSeed * 3.57));
            amplitude *= 0.55;
        }
        
        // Combine noise layers
        float combinedNoise = mix(noise1, noise2, 0.6) * 0.5 + 0.5;
        
        // Apply enhanced contrast with variation
        combinedNoise = pow(combinedNoise, contrast);
        
        // Multi-layer distance falloff
        vec2 center = vec2(0.5, 0.5);
        float dist = length(uv - center);
        float falloff1 = 1.0 - smoothstep(0.05, 0.95, dist);
        float falloff2 = 1.0 - smoothstep(0.2, 0.8, dist * 1.2);
        float combinedFalloff = mix(falloff1, falloff2, 0.4);
        
        // Enhanced density calculation
        float density = combinedNoise * combinedFalloff * baseAlpha * intensity;
        
        // Dynamic color palette based on hueShift
        float hue1 = density + paletteShift + hueShift + sin(nebulaSeed * 8.91) * 0.3;
        float hue2 = density * 1.5 + paletteShift + hueShift + cos(nebulaSeed * 10.12) * 0.25;
        
        vec3 deepSpace = vec3(0.01, 0.005, 0.08);
        vec3 color1 = hsv2rgb(vec3(mod(hueShift, 1.0), saturation * 0.8, 0.4));
        vec3 color2 = hsv2rgb(vec3(mod(hueShift + 0.2, 1.0), saturation, 0.7));
        vec3 color3 = hsv2rgb(vec3(mod(hueShift + 0.4, 1.0), saturation * 0.9, 0.9));
        vec3 color4 = hsv2rgb(vec3(mod(hueShift + 0.6, 1.0), saturation * 0.6, 0.8));
        
        // Multi-step color mixing
        vec3 mixedColor1 = mix(deepSpace, color1, sin(hue1 * 6.28) * 0.5 + 0.5);
        vec3 mixedColor2 = mix(mixedColor1, color2, cos(hue1 * 4.5) * 0.4 + 0.4);
        vec3 mixedColor3 = mix(mixedColor2, color3, sin(hue2 * 3.2) * 0.3 + 0.3);
        vec3 mixedColor4 = mix(mixedColor3, color4, smoothstep(0.6, 0.9, density));
        vec3 finalColor = mix(mixedColor4, vec3(1.0, 0.9, 0.8), smoothstep(0.85, 1.0, density));
        
        // Enhanced exposure with subtle variation
        finalColor *= exposure * (1.0 + sin(hue1 * 2.0) * 0.1);
        
        // Add subtle sparkle effect
        float sparkle = sin(freq1.x * 20.0) * cos(freq1.y * 20.0);
        sparkle = smoothstep(0.95, 1.0, sparkle) * 0.3;
        finalColor += vec3(sparkle);
        
        float outputAlpha = density * finalAlpha;
        return vec4(finalColor * finalAlpha, outputAlpha);
    }
]])

local function generate_stars(count, bounds, sizeRange, alphaRange, colorVariation)
    local stars = {}
    local width = bounds.width
    local height = bounds.height
    local defaults = constants.stars.defaults
    local minSize = sizeRange and sizeRange[1] or defaults.size_range[1]
    local maxSize = sizeRange and sizeRange[2] or defaults.size_range[2]
    local sizeSpan = math.max(maxSize - minSize, 0)
    local minAlpha = alphaRange and alphaRange[1] or defaults.alpha_range[1]
    local maxAlpha = alphaRange and alphaRange[2] or defaults.alpha_range[2]
    local alphaSpan = math.max(maxAlpha - minAlpha, 0)

    for _ = 1, count do
        local temp = 0.3 + love.math.random() * 0.7
        local hue = love.math.random() * (colorVariation or 0.1)
        local size = minSize + love.math.random() * sizeSpan
        
        local r, g, b
        if temp < 0.4 then
            r = 1.0
            g = 0.4 + temp * 0.8
            b = 0.1 + temp * 0.3
        elseif temp < 0.6 then
            r = 1.0
            g = 0.8 + temp * 0.4
            b = 0.3 + temp * 0.5
        else
            r = 0.8 + temp * 0.4
            g = 0.9 + temp * 0.2
            b = 1.0
        end
        
        stars[#stars + 1] = {
            x = love.math.random() * width,
            y = love.math.random() * height,
            size = size,
            alpha = minAlpha + love.math.random() * alphaSpan,
            r = math.min(1, r + hue),
            g = math.min(1, g + hue * 0.5),
            b = math.min(1, b + hue * 0.8),
            twinklePhase = love.math.random() * math_util.TAU,
            twinkleSpeed = 0.3 + love.math.random() * 1.0,
            brightness = 0.7 + love.math.random() * 0.6,
        }
    end

    return stars
end

local function generate_asteroid_belts(state)
    local background_props = constants.stars.background_props or {}
    local config = background_props.asteroid_belts
    if not config then
        return {}
    end

    local bounds = state.worldBounds
    if not bounds then
        return {}
    end

    local chance = config.spawn_chance or 0
    if chance <= 0 or love.math.random() >= chance then
        return {}
    end

    local belts = {}
    local count = math.max(0, random_int_range(config.count, 0))
    local base_color = config.color or { 0.6, 0.55, 0.5 }
    local highlight_color = config.highlight or { 0.9, 0.85, 0.8 }

    local cam = state.camera
    local viewport = state.viewport
    local margin = config.spawn_margin or 0
    local marginX = margin
    local marginY = margin

    local function clamp_to_bounds(value, min_val, max_val)
        if value < min_val then
            return min_val
        elseif value > max_val then
            return max_val
        end
        return value
    end

    local centerX = bounds.x + bounds.width * 0.5
    local centerY = bounds.y + bounds.height * 0.5

    if cam and viewport then
        local camCenterX = cam.x + (cam.width or viewport.width) * 0.5
        local camCenterY = cam.y + (cam.height or viewport.height) * 0.5
        centerX = camCenterX
        centerY = camCenterY
    end

    for _ = 1, count do
        local parallax = random_range(config.parallax_range, 0.012)
        local radius = random_range(config.radius_range, 600)
        local thickness = random_range(config.thickness_range, 100)
        local squash = random_range(config.squash_range, 0.75)
        local arc_fraction = random_range(config.arc_span, 0.6)
        local arc_span = math_util.TAU * math.max(0, math.min(arc_fraction, 1))
        local orientation = love.math.random() * math_util.TAU
        local start_angle = orientation - arc_span * 0.5
        local segment_count = math.max(1, random_int_range(config.segment_count, 90))

        local segment_size_range = config.segment_size or { 4, 8 }
        local alpha_range = config.alpha_range or { 0.25, 0.4 }
        local flicker_range = config.flicker_speed or { 0.6, 1.2 }

        local spawnRadiusX = math.max(marginX, radius + thickness * 0.5)
        local spawnRadiusY = math.max(marginY, (radius + thickness * 0.5) * squash)

        local offsetX = (love.math.random() * 2 - 1) * spawnRadiusX
        local offsetY = (love.math.random() * 2 - 1) * spawnRadiusY

        local center_x = clamp_to_bounds(centerX + offsetX, bounds.x, bounds.x + bounds.width)
        local center_y = clamp_to_bounds(centerY + offsetY, bounds.y, bounds.y + bounds.height)

        local segments = {}
        for i = 1, segment_count do
            local t = (i - 0.5) / segment_count
            local jitter = (love.math.random() - 0.5) * (arc_span / math.max(segment_count, 1)) * 0.6
            local angle = start_angle + t * arc_span + jitter
            local radial_offset = (love.math.random() - 0.5) * thickness
            local local_radius = radius + radial_offset
            local cos_a = math.cos(angle)
            local sin_a = math.sin(angle)
            local point_x = cos_a * local_radius
            local point_y = sin_a * local_radius * squash

            segments[#segments + 1] = {
                x = center_x + point_x,
                y = center_y + point_y,
                size = random_range(segment_size_range, 6),
                alpha = random_range(alpha_range, 0.3),
                flickerSpeed = random_range(flicker_range, 1.0),
                phase = love.math.random() * math_util.TAU,
                highlightScale = 0.4 + love.math.random() * 0.35,
                highlightAlpha = 0.45 + love.math.random() * 0.25,
            }
        end

        belts[#belts + 1] = {
            parallax = parallax,
            segments = segments,
            color = { base_color[1], base_color[2], base_color[3] },
            highlight = { highlight_color[1], highlight_color[2], highlight_color[3] },
        }
    end

    return belts
end

local function draw_asteroid_belts(belts, camRelX, camRelY, viewportWidth, viewportHeight, time)
    if not belts then
        return
    end

    for i = 1, #belts do
        local belt = belts[i]
        local offsetX = camRelX * (belt.parallax or 0)
        local offsetY = camRelY * (belt.parallax or 0)
        local color = belt.color or { 0.6, 0.55, 0.5 }
        local highlight = belt.highlight or { 0.9, 0.85, 0.8 }
        local segments = belt.segments

        for j = 1, #segments do
            local segment = segments[j]
            local radius = segment.size
            local sx = segment.x - offsetX
            local sy = segment.y - offsetY

            if sx >= -radius and sx <= viewportWidth + radius and
               sy >= -radius and sy <= viewportHeight + radius then
                local flicker_speed = segment.flickerSpeed or 0
                local flicker_phase = segment.phase or 0
                local flicker = 0.85 + 0.15 * math.sin(time * flicker_speed + flicker_phase)
                local alpha = (segment.alpha or 0.3) * flicker

                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.circle("fill", sx, sy, radius)

                local highlight_alpha = alpha * (segment.highlightAlpha or 0.5)
                love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight_alpha)
                love.graphics.circle("fill", sx, sy, radius * (segment.highlightScale or 0.55))
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Starfield.generateLayers(bounds)
    local layers = constants.stars.layers
    local generated = {}

    for i = 1, #layers do
        local layer = layers[i]
        generated[#generated + 1] = {
            parallax = layer.parallax,
            stars = generate_stars(layer.count, bounds, layer.size_range, layer.alpha_range, layer.color_variation),
        }
    end

    return generated
end

function Starfield.initialize(state)
    if not state.worldBounds then
        return
    end

    local bounds = state.worldBounds

    state.starLayers = Starfield.generateLayers(bounds)
    state.nebulaSeed = love.math.random() * 1000
    local nebula_config = constants.stars.nebula or {}
    state.nebulaIntensity = random_range(nebula_config.intensity_range, 0.3)
    state.nebulaAlpha = random_range(nebula_config.alpha_range, 0.4)
    state.starfieldTime = 0
    state.nebulaHueShift = love.math.random()
    state.nebulaSaturation = 0.7 + love.math.random() * 0.3
    state.asteroidBelts = generate_asteroid_belts(bounds)
end

function Starfield.refresh(state)
    if not state.worldBounds then
        return
    end

    local bounds = state.worldBounds

    state.starLayers = Starfield.generateLayers(bounds)
    state.nebulaSeed = love.math.random() * 1000
    local nebula_config = constants.stars.nebula or {}
    state.nebulaIntensity = random_range(nebula_config.intensity_range, 0.3)
    state.nebulaAlpha = random_range(nebula_config.alpha_range, 0.4)
    state.nebulaHueShift = love.math.random()
    state.nebulaSaturation = 0.7 + love.math.random() * 0.3
    state.asteroidBelts = generate_asteroid_belts(bounds)
end

function Starfield.update(state, dt)
    state.starfieldTime = (state.starfieldTime or 0) + dt
end

function Starfield.draw(state)
    local layers = state.starLayers
    local cam = state.camera
    local viewport = state.viewport
    local bounds = state.worldBounds

    if not (layers and cam and viewport and bounds) then
        return
    end

    local vw, vh = viewport.width, viewport.height
    local camRelX = cam.x - bounds.x
    local camRelY = cam.y - bounds.y
    local time = state.starfieldTime or 0

    love.graphics.push("all")
    
    love.graphics.setShader(nebulaShader)
    nebulaShader:send("nebulaSeed", state.nebulaSeed or 0)
    nebulaShader:send("time", time)
    nebulaShader:send("intensity", state.nebulaIntensity or 0.3)
    nebulaShader:send("hueShift", state.nebulaHueShift or 0)
    nebulaShader:send("saturation", state.nebulaSaturation or 0.8)
    nebulaShader:send("finalAlpha", state.nebulaAlpha or 0.4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
    love.graphics.setShader()

    draw_asteroid_belts(state.asteroidBelts, camRelX, camRelY, vw, vh, time)
    
    love.graphics.setBlendMode("add")

    for i = 1, #layers do
        local layer = layers[i]
        local parallax = layer.parallax or 1
        local offsetX = camRelX * parallax
        local offsetY = camRelY * parallax
        local stars = layer.stars

        for j = 1, #stars do
            local star = stars[j]
            local sx = star.x - offsetX
            local sy = star.y - offsetY
            local radius = star.size * 0.5
            local maxGlowRadius = radius * 2

            if sx >= -maxGlowRadius and sx <= vw + maxGlowRadius and 
               sy >= -maxGlowRadius and sy <= vh + maxGlowRadius then
                local twinkle = math.sin(time * star.twinkleSpeed + star.twinklePhase) * 0.15 + 0.85
                local alpha = star.alpha * star.brightness * twinkle
                
                love.graphics.setColor(star.r, star.g, star.b, alpha)
                love.graphics.circle("fill", sx, sy, radius)
                
                love.graphics.setColor(1, 1, 1, alpha * 0.8)
                love.graphics.circle("fill", sx, sy, radius * 0.3)
                
                if star.brightness > 0.6 then
                    love.graphics.setColor(star.r, star.g, star.b, alpha * 0.3)
                    love.graphics.circle("fill", sx, sy, maxGlowRadius)
                end
            end
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return Starfield
