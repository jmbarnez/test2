-- Temporal Field Renderer
-- Draws a shader-based slow-time bubble effect around entities with active temporal fields

local love = love
local lg = love.graphics

local temporalShader
local shaderLoaded = false

local function init_shader()
    if shaderLoaded then
        return
    end

    local shaderSource = [[
        extern float time;
        extern vec2 center;
        extern float radius;
        extern vec4 bubbleColor;
        extern vec4 rimColor;
        
        // Noise function for distortion
        float noise(vec2 p) {
            return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
        }
        
        float smoothNoise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            
            float a = noise(i);
            float b = noise(i + vec2(1.0, 0.0));
            float c = noise(i + vec2(0.0, 1.0));
            float d = noise(i + vec2(1.0, 1.0));
            
            return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
        }
        
        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec2 toCenter = screen_coords - center;
            float dist = length(toCenter);
            
            // Early exit if outside field
            if (dist > radius) {
                return vec4(0.0);
            }
            
            // Normalized position
            float normalizedDist = dist / radius;
            
            // Animated ripple effect
            float rippleSpeed = 2.0;
            float rippleFreq = 8.0;
            float ripple = sin((normalizedDist * rippleFreq - time * rippleSpeed) * 3.14159) * 0.5 + 0.5;
            ripple = pow(ripple, 2.0) * 0.3;
            
            // Flowing energy waves
            vec2 angle = normalize(toCenter);
            float rotation = atan(angle.y, angle.x);
            float wave1 = sin(rotation * 6.0 + time * 1.5 + normalizedDist * 4.0) * 0.5 + 0.5;
            float wave2 = sin(rotation * 4.0 - time * 2.0 + normalizedDist * 6.0) * 0.5 + 0.5;
            float waves = (wave1 * 0.6 + wave2 * 0.4) * 0.2;
            
            // Distortion for a "time warping" effect
            vec2 noiseCoord = screen_coords * 0.01 + vec2(time * 0.1, time * 0.15);
            float distortion = smoothNoise(noiseCoord) * 0.3;
            
            // Edge glow (brightest at the rim)
            float edgeFalloff = 1.0 - normalizedDist;
            float rimGlow = pow(1.0 - abs(normalizedDist - 0.95) * 20.0, 4.0);
            rimGlow = clamp(rimGlow, 0.0, 1.0);
            
            // Pulsing effect
            float pulse = sin(time * 2.5) * 0.15 + 0.85;
            
            // Inner volume glow
            float innerGlow = pow(edgeFalloff, 1.5) * 0.4;
            
            // Combine effects
            float totalIntensity = (innerGlow + ripple + waves + distortion) * pulse;
            totalIntensity += rimGlow * 0.8;
            
            // Color mixing
            vec4 finalColor = mix(bubbleColor, rimColor, rimGlow);
            finalColor.a *= totalIntensity;
            
            // Add subtle chromatic shimmer at the edge
            if (normalizedDist > 0.85) {
                float shimmer = sin(rotation * 12.0 + time * 3.0) * 0.5 + 0.5;
                finalColor.rgb += vec3(0.1, 0.15, 0.2) * shimmer * rimGlow;
            }
            
            return finalColor * color;
        }
    ]]

    local ok, result = pcall(lg.newShader, shaderSource)
    if ok then
        temporalShader = result
        shaderLoaded = true
    else
        print("[temporal_field_renderer] Failed to load shader:", result)
        shaderLoaded = false
    end
end

local function draw_temporal_field(entity, camera)
    if not entity._temporalField or not entity._temporalField.active then
        return
    end

    if not temporalShader then
        init_shader()
        if not temporalShader then
            return
        end
    end

    local field = entity._temporalField
    local body = entity.body
    if not (body and not body:isDestroyed()) then
        return
    end

    local x, y = body:getPosition()
    local radius = field.radius or 250

    -- Get ability for color parameters
    local bubbleColor = { 0.4, 0.7, 1.0, 0.25 }
    local rimColor = { 0.5, 0.85, 1.0, 0.6 }
    
    if entity.abilityModules then
        for i = 1, #entity.abilityModules do
            local module = entity.abilityModules[i]
            if module.ability and module.ability.type == "temporal_field" then
                bubbleColor = module.ability.bubbleColor or bubbleColor
                rimColor = module.ability.bubbleRimColor or rimColor
                break
            end
        end
    end

    lg.push("all")
    lg.setBlendMode("add")

    -- Set shader uniforms
    if temporalShader then
        local timeNow = love.timer.getTime()
        local screenX, screenY = lg.transformPoint(x, y)
        local edgeX, edgeY = lg.transformPoint(x + radius, y)
        local dx = edgeX - screenX
        local dy = edgeY - screenY
        local radiusScreen = math.max(1, math.sqrt(dx * dx + dy * dy))

        temporalShader:send("time", timeNow)
        temporalShader:send("center", { screenX, screenY })
        temporalShader:send("radius", radiusScreen)
        temporalShader:send("bubbleColor", bubbleColor)
        temporalShader:send("rimColor", rimColor)
        
        lg.setShader(temporalShader)
        lg.setColor(1, 1, 1, 1)

        local size = radiusScreen * 2.4
        lg.origin()
        lg.rectangle("fill", screenX - size * 0.5, screenY - size * 0.5, size, size)
        
        lg.setShader()
    end

    lg.pop()
end

return {
    draw_temporal_field = draw_temporal_field,
    init_shader = init_shader,
}
