---@diagnostic disable: undefined-global

local constants = require("src.constants.game")

local FilmGrain = {}

local love = love

local shaderSource = [[
extern float time;
extern float intensity;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 base = Texel(tex, texture_coords) * color;
    if (base.a <= 0.0) {
        return base;
    }

    vec2 grainCoord = screen_coords * 0.5 + vec2(time * 0.1);
    float grain = (rand(grainCoord) - 0.5) * intensity * 0.05;

    vec3 result = base.rgb + vec3(grain);
    return vec4(clamp(result, 0.0, 1.0), base.a);
}
]]

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

    return shader
end

local function read_config()
    local renderConfig = constants.render or {}
    local grainConfig = renderConfig.film_grain or {}

    return {
        enabled = grainConfig.enabled ~= false,
        intensity = grainConfig.intensity or 0.01,
    }
end

local function ensure_canvas(effect, width, height)
    width = math.max(1, math.floor(width + 0.5))
    height = math.max(1, math.floor(height + 0.5))

    if effect.canvas and effect.canvas:getWidth() == width and effect.canvas:getHeight() == height then
        return
    end

    if effect.canvas then
        effect.canvas:release()
    end

    effect.canvas = love.graphics.newCanvas(width, height)
    effect.canvas:setFilter("linear", "linear")
end

function FilmGrain.initialize(state)
    local cfg = read_config()
    local shader = build_shader()

    state.filmGrain = {
        shader = shader,
        enabled = cfg.enabled and shader ~= nil,
        intensity = cfg.intensity,
        canvas = nil,
        time = 0,
    }

    if shader then
        shader:send("intensity", cfg.intensity)
    end

    local viewport = state.viewport
    if viewport then
        FilmGrain.resize(state, viewport.width, viewport.height)
    end
end

function FilmGrain.teardown(state)
    local effect = state.filmGrain
    if not effect then
        return
    end

    if effect.canvas then
        effect.canvas:release()
        effect.canvas = nil
    end

    state.filmGrain = nil
end

function FilmGrain.resize(state, width, height)
    local effect = state.filmGrain
    if not effect or not effect.enabled or not effect.shader then
        return
    end

    ensure_canvas(effect, width, height)
end

function FilmGrain.update(state, dt)
    local effect = state.filmGrain
    if not effect or not effect.enabled then
        return
    end

    effect.time = effect.time + (dt or 0)
end

local function get_clear_components(clear_color)
    if type(clear_color) == "table" then
        return clear_color[1] or 0, clear_color[2] or 0, clear_color[3] or 0, clear_color[4] or 1
    end
    return 0, 0, 0, 1
end

function FilmGrain.draw(state, drawScene, clear_color)
    local effect = state.filmGrain
    if not effect or not effect.enabled or not effect.shader then
        local r, g, b, a = get_clear_components(clear_color)
        love.graphics.clear(r, g, b, a)
        drawScene()
        return
    end

    local viewport = state.viewport
    local width = viewport and viewport.width or love.graphics.getWidth()
    local height = viewport and viewport.height or love.graphics.getHeight()

    ensure_canvas(effect, width, height)

    local r, g, b, a = get_clear_components(clear_color)

    love.graphics.push("all")
    love.graphics.setCanvas(effect.canvas)
    love.graphics.clear(r, g, b, 1)
    drawScene()
    love.graphics.setCanvas()
    love.graphics.pop()

    love.graphics.clear(r, g, b, a)

    love.graphics.push("all")
    effect.shader:send("time", effect.time)
    love.graphics.setShader(effect.shader)
    love.graphics.draw(effect.canvas, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
end

function FilmGrain.isActive(state)
    local effect = state.filmGrain
    return effect and effect.enabled and effect.shader ~= nil
end

return FilmGrain
