---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
local vector = require("src.util.vector")

local Lighting = {}

local love = love

local shaderSource = [[
extern vec3 lightDirection;
extern vec3 ambientColor;
extern vec3 diffuseColor;
extern vec3 specularColor;
extern float ambientStrength;
extern float diffuseStrength;
extern float specularStrength;
extern float specularPower;
extern float rimStrength;
extern float rimExponent;
extern vec2 entityCenter;
extern float entityRadius;
extern float entityNormalScale;
extern float entityDiffuseScale;
extern float entitySpecularScale;
extern float entityAmbientScale;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 base = Texel(tex, texture_coords) * color;
    if (base.a <= 0.0) {
        return base;
    }

    float radius = max(entityRadius, 1.0);
    vec2 offset = (screen_coords - entityCenter) / radius;
    float dist = length(offset);
    float clamped = clamp(dist, 0.0, 1.5);
    float height = sqrt(max(1.0 - clamped * clamped, 0.0));

    vec3 normal = normalize(vec3(offset.x, offset.y, height * entityNormalScale));
    vec3 L = normalize(lightDirection);
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 H = normalize(L + V);

    float diff = max(dot(normal, L), 0.0);
    float spec = pow(max(dot(normal, H), 0.0), specularPower);
    float rim = pow(1.0 - max(dot(normal, V), 0.0), rimExponent);

    vec3 ambientTerm = ambientColor * ambientStrength * entityAmbientScale;
    vec3 diffuseTerm = diffuseColor * (diff * diffuseStrength * entityDiffuseScale);

    float specFactor = spec * specularStrength * entitySpecularScale * base.a;
    float rimFactor = rim * rimStrength * entitySpecularScale * base.a;

    vec3 highlightBase = mix(base.rgb, specularColor, 0.35);
    vec3 specularTerm = highlightBase * specFactor;
    vec3 rimTerm = highlightBase * rimFactor;

    vec3 lit = base.rgb * (ambientTerm + diffuseTerm) + specularTerm + rimTerm;
    return vec4(clamp(lit, 0.0, 1.0), base.a);
}
]]

local function normalize_vec3(vec)
    local x = vec and vec[1] or 0
    local y = vec and vec[2] or 0
    local z = vec and vec[3] or 1
    local length = vector.length(x, y, z)
    if length <= vector.EPSILON then
        return { 0, 0, 1 }
    end
    return { x / length, y / length, z / length }
end

local function clamp01(value)
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function build_shader()
    local graphics = love and love.graphics
    if type(graphics) ~= "table" then
        return nil
    end

    if type(graphics.isSupported) == "function" then
        local ok, supported = pcall(graphics.isSupported, "shader")
        if ok and not supported then
            return nil
        end
    elseif type(graphics.getSupported) == "function" then
        local ok, supported = pcall(graphics.getSupported)
        if ok and type(supported) == "table" and supported.shader == false then
            return nil
        end
    end

    if type(graphics.newShader) ~= "function" then
        return nil
    end

    local ok, shader = pcall(graphics.newShader, shaderSource)
    if not ok then
        return nil
    end

    shader:send("entityNormalScale", 1.0)
    shader:send("entityDiffuseScale", 1.0)
    shader:send("entitySpecularScale", 1.0)
    shader:send("entityAmbientScale", 1.0)

    return shader
end

Lighting.shader = build_shader()
Lighting.isBound = false

local function resolve_config()
    local renderConfig = constants.render or {}
    local lightingConfig = renderConfig.lighting or {}

    return {
        direction = normalize_vec3(lightingConfig.direction or { -0.25, -0.45, 0.85 }),
        ambient = lightingConfig.ambient or { 0.3, 0.3, 0.35 },
        diffuse = lightingConfig.diffuse or { 0.85, 0.88, 0.95 },
        specular = lightingConfig.specular or { 0.9, 0.9, 0.95 },
        ambientStrength = lightingConfig.ambient_strength or 1.0,
        diffuseStrength = lightingConfig.diffuse_strength or 1.0,
        specularStrength = lightingConfig.specular_strength or 0.65,
        specularPower = lightingConfig.specular_power or 16,
        rimStrength = lightingConfig.rim_strength or 0.35,
        rimExponent = lightingConfig.rim_exponent or 2.0,
    }
end

Lighting.config = resolve_config()

local function apply_config(shader, config)
    if not shader then
        return
    end

    shader:send("lightDirection", config.direction)
    shader:send("ambientColor", config.ambient)
    shader:send("diffuseColor", config.diffuse)
    shader:send("specularColor", config.specular)
    shader:send("ambientStrength", config.ambientStrength)
    shader:send("diffuseStrength", config.diffuseStrength)
    shader:send("specularStrength", config.specularStrength)
    shader:send("specularPower", config.specularPower)
    shader:send("rimStrength", config.rimStrength)
    shader:send("rimExponent", config.rimExponent)
end

apply_config(Lighting.shader, Lighting.config)

function Lighting.isAvailable()
    return Lighting.shader ~= nil
end

function Lighting.setConfig(newConfig)
    if not Lighting.shader then
        return
    end

    if type(newConfig) == "table" then
        if newConfig.direction then
            Lighting.config.direction = normalize_vec3(newConfig.direction)
        end
        if newConfig.ambient then
            Lighting.config.ambient = newConfig.ambient
        end
        if newConfig.diffuse then
            Lighting.config.diffuse = newConfig.diffuse
        end
        if newConfig.specular then
            Lighting.config.specular = newConfig.specular
        end
        if newConfig.ambient_strength then
            Lighting.config.ambientStrength = newConfig.ambient_strength
        end
        if newConfig.diffuse_strength then
            Lighting.config.diffuseStrength = newConfig.diffuse_strength
        end
        if newConfig.specular_strength then
            Lighting.config.specularStrength = newConfig.specular_strength
        end
        if newConfig.specular_power then
            Lighting.config.specularPower = newConfig.specular_power
        end
        if newConfig.rim_strength then
            Lighting.config.rimStrength = newConfig.rim_strength
        end
        if newConfig.rim_exponent then
            Lighting.config.rimExponent = newConfig.rim_exponent
        end
    end

    apply_config(Lighting.shader, Lighting.config)
end

local function resolve_overrides(entity, fallback)
    local overrides = {}

    if type(fallback) == "table" then
        for key, value in pairs(fallback) do
            overrides[key] = value
        end
    end

    local entityOverrides = entity and entity.lighting
    if type(entityOverrides) == "table" then
        for key, value in pairs(entityOverrides) do
            overrides[key] = value
        end
    end

    if next(overrides) == nil then
        return nil
    end

    return overrides
end

local function extract_scale(overrides, key, default)
    if type(overrides) ~= "table" then
        return default
    end

    local value = overrides[key]
    if type(value) == "number" then
        return value
    end

    return default
end

function Lighting.bindEntity(entity, context, radius, drawableOverrides)
    if not Lighting.shader or not entity or not entity.position then
        return false
    end

    local overrides = resolve_overrides(entity, drawableOverrides)

    local actualRadius = radius
    if overrides and type(overrides.radius) == "number" then
        actualRadius = overrides.radius
    end

    actualRadius = math.max(actualRadius or 48, 1)

    local camera = context and context.camera
    local centerX = entity.position.x
    local centerY = entity.position.y

    if camera then
        centerX = centerX - (camera.x or 0)
        centerY = centerY - (camera.y or 0)
    end

    Lighting.shader:send("entityCenter", { centerX, centerY })
    Lighting.shader:send("entityRadius", actualRadius)

    local normalScale = extract_scale(overrides, "normal_scale", 1.0)
    Lighting.shader:send("entityNormalScale", normalScale)

    Lighting.shader:send("entityDiffuseScale", extract_scale(overrides, "diffuse", 1.0))
    Lighting.shader:send("entitySpecularScale", extract_scale(overrides, "specular", 1.0))
    Lighting.shader:send("entityAmbientScale", clamp01(extract_scale(overrides, "ambient", 1.0)))

    love.graphics.setShader(Lighting.shader)
    Lighting.isBound = true
    return true
end

function Lighting.unbind()
    if Lighting.isBound then
        love.graphics.setShader()
        Lighting.isBound = false
    end
end

return Lighting
