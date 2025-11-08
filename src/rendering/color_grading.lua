---@diagnostic disable: undefined-global

local constants = require("src.constants.game")

local ColorGrading = {}

local love = love

local shaderSource = [[
extern Image source;
extern Image lutMap;
extern float intensity;
extern float lutSize;
extern vec2 lutTextureSize;

vec3 sampleLUT(vec3 color) {
    float size = max(lutSize, 2.0);
    float scale = size - 1.0;
    float blue = clamp(color.b * scale, 0.0, scale);
    float slice0 = floor(blue);
    float slice1 = min(slice0 + 1.0, scale);
    float interp = blue - slice0;

    float texelsPerSlice = lutTextureSize.x / size;
    float texelSizeX = 1.0 / lutTextureSize.x;
    float texelSizeY = 1.0 / lutTextureSize.y;

    float red = clamp(color.r * scale, 0.0, scale);
    float green = clamp(color.g * scale, 0.0, scale);

    float sliceOffset0 = slice0 * texelsPerSlice;
    float sliceOffset1 = slice1 * texelsPerSlice;

    float u0 = (sliceOffset0 + red + 0.5) * texelSizeX;
    float u1 = (sliceOffset1 + red + 0.5) * texelSizeX;
    float v = (green + 0.5) * texelSizeY;

    vec3 sample0 = Texel(lutMap, vec2(u0, v)).rgb;
    vec3 sample1 = Texel(lutMap, vec2(u1, v)).rgb;

    return mix(sample0, sample1, interp);
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 base = Texel(source, texture_coords) * color;
    if (intensity <= 0.0) {
        return base;
    }

    vec3 graded = sampleLUT(base.rgb);
    base.rgb = mix(base.rgb, graded, clamp(intensity, 0.0, 1.0));
    return base;
}
]]

local function isSupported()
    local graphics = love and love.graphics
    if type(graphics) ~= "table" then
        return false
    end

    if type(graphics.newCanvas) ~= "function" or type(graphics.newShader) ~= "function" then
        return false
    end

    if type(graphics.isSupported) == "function" then
        local ok, shaders = pcall(graphics.isSupported, "shader")
        if ok and not shaders then
            return false
        end
    end

    return true
end

local function loadLUT(path)
    if not path or path == "" then
        return nil
    end

    local fs = love and love.filesystem
    if type(fs) ~= "table" or type(fs.getInfo) ~= "function" then
        return nil
    end

    if not fs.getInfo(path) then
        return nil
    end

    if type(love.graphics) ~= "table" or type(love.graphics.newImage) ~= "function" then
        return nil
    end

    local ok, image = pcall(love.graphics.newImage, path)
    if not ok or not image then
        return nil
    end

    image:setFilter("linear", "linear")
    return image
end

local function buildShader()
    local ok, shader = pcall(love.graphics.newShader, shaderSource)
    if not ok then
        return nil
    end
    return shader
end

local function resolveConfig()
    local renderConfig = constants.render or {}
    local cfg = renderConfig.color_grading or {}

    local intensity = cfg.intensity
    if type(intensity) ~= "number" then
        intensity = 1.0
    end
    intensity = math.max(0, math.min(1, intensity))

    local size = cfg.size
    if type(size) ~= "number" or size < 2 then
        size = 16
    end

    return {
        enabled = cfg.enabled ~= false,
        intensity = intensity,
        size = size,
        lut_path = cfg.lut_path,
    }
end

local function ensureCanvas(state, width, height)
    local cg = state._colorGrading
    local canvas = cg and cg.canvas
    if canvas and canvas:getWidth() == width and canvas:getHeight() == height then
        return canvas
    end

    if canvas then
        canvas:release()
    end

    local ok, newCanvas = pcall(love.graphics.newCanvas, width, height)
    if not ok then
        return nil
    end

    newCanvas:setFilter("linear", "linear")

    cg.canvas = newCanvas
    return newCanvas
end

local function activate(state)
    local cg = state._colorGrading
    if not cg then
        return
    end

    if not (cg.config and cg.config.enabled) then
        cg.active = false
        return
    end

    if not cg.shader or not cg.lut or cg.config.intensity <= 0 then
        cg.active = false
        return
    end

    cg.shader:send("lutMap", cg.lut)
    cg.shader:send("lutSize", cg.config.size)
    cg.shader:send("lutTextureSize", { cg.lut:getWidth(), cg.lut:getHeight() })
    cg.active = true
end

function ColorGrading.initialize(state)
    if not isSupported() then
        return
    end

    state._colorGrading = state._colorGrading or {}
    local cg = state._colorGrading

    cg.config = resolveConfig()
    cg.intensity = cg.config.intensity or 1.0
    cg.shader = buildShader()
    cg.lut = loadLUT(cg.config.lut_path)
    cg.canvas = nil
    cg.active = false

    if not cg.shader or not cg.lut then
        cg.active = false
        return
    end

    activate(state)

    local viewport = state.viewport
    if viewport and cg.active then
        ColorGrading.resize(state, viewport.width, viewport.height)
    end
end

function ColorGrading.resize(state, width, height)
    local cg = state._colorGrading
    if not (cg and cg.active) then
        return
    end
    ensureCanvas(state, math.max(1, math.floor(width + 0.5)), math.max(1, math.floor(height + 0.5)))
end

function ColorGrading.beginFrame(state, clearColor)
    local cg = state._colorGrading
    if not (cg and cg.active) then
        return false
    end

    local viewport = state.viewport
    if not viewport then
        return false
    end

    local canvas = ensureCanvas(state, viewport.width, viewport.height)
    if not canvas then
        return false
    end

    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(clearColor[1], clearColor[2], clearColor[3], 1)
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

function ColorGrading.finish(state, clearColor)
    local cg = state._colorGrading
    if not (cg and cg.active and cg.canvas and cg.shader) then
        return
    end

    love.graphics.pop()

    love.graphics.clear(clearColor[1], clearColor[2], clearColor[3], 1)
    love.graphics.push("all")
    love.graphics.setShader(cg.shader)
    cg.shader:send("intensity", cg.config.intensity or 1.0)
    cg.shader:send("source", cg.canvas)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cg.canvas, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
end

function ColorGrading.teardown(state)
    local cg = state._colorGrading
    if not cg then
        return
    end

    if cg.canvas then
        cg.canvas:release()
        cg.canvas = nil
    end

    if cg.shader then
        cg.shader:release()
        cg.shader = nil
    end

    if cg.lut and cg.lut.release then
        cg.lut:release()
    end
    cg.lut = nil
    cg.active = false
end

return ColorGrading
