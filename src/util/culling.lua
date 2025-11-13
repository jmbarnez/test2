local constants = require("src.constants.game")
local vector = require("src.util.vector")

local Culling = {}

local render_constants = constants.render or {}

local function compute_polygon_radius(points)
    if type(points) ~= "table" then
        return 0
    end

    local max_radius = 0
    for i = 1, #points, 2 do
        local x = points[i] or 0
        local y = points[i + 1] or 0
        local radius = vector.length(x, y)
        if radius > max_radius then
            max_radius = radius
        end
    end

    return max_radius
end

local function compute_drawable_radius(drawable)
    if type(drawable) ~= "table" then
        return 0
    end

    if type(drawable.cullRadius) == "number" and drawable.cullRadius >= 0 then
        return drawable.cullRadius
    end

    if type(drawable.radius) == "number" and drawable.radius > 0 then
        return drawable.radius
    end

    if type(drawable.size) == "number" and drawable.size > 0 then
        return drawable.size * 0.5
    end

    if type(drawable.width) == "number" and drawable.width > 0 then
        return drawable.width * 0.5
    end

    if type(drawable.height) == "number" and drawable.height > 0 then
        return drawable.height * 0.5
    end

    if type(drawable.polygon) == "table" and #drawable.polygon >= 6 then
        return compute_polygon_radius(drawable.polygon)
    end

    if type(drawable.shape) == "table" and #drawable.shape >= 6 then
        return compute_polygon_radius(drawable.shape)
    end

    return 0
end

local function resolve_camera(source)
    if not source then
        return nil
    end

    if source.camera and source.camera.x then
        return source.camera
    end

    if source.x and source.y and source.width and source.height then
        return source
    end

    local state = source.state
    if state and state.camera then
        return state.camera
    end

    local resolver = source.resolveState
    if type(resolver) == "function" then
        local ok, resolved = pcall(resolver, source)
        if ok and resolved and resolved.camera then
            return resolved.camera
        end
    end

    return nil
end

function Culling.computeCullRadius(entity, fallback)
    if not entity then
        return 0
    end

    local radius = entity.cullRadius
    if type(radius) == "number" and radius >= 0 then
        return radius
    end

    local drawable = entity.drawable
    radius = compute_drawable_radius(drawable)
    if radius > 0 then
        return radius
    end

    if fallback then
        local ok, value = pcall(fallback, entity)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
    end

    if entity.radius and entity.radius > 0 then
        return entity.radius
    end

    if entity.hullSize then
        local hx = entity.hullSize.x or 0
        local hy = entity.hullSize.y or 0
        local diag = vector.length(hx, hy)
        if diag > 0 then
            return diag * 0.5
        end
    end

    return 0
end

function Culling.isEntityVisible(entity, context, options)
    if not entity then
        return true
    end

    local optionsType = type(options)
    local margin
    local fallback

    if optionsType == "table" then
        margin = options.margin
        fallback = options.fallback
    end

    local camera = resolve_camera(context)
    if not camera and type(context) == "table" and context.x and context.width then
        camera = context
    end

    if not camera then
        return true
    end

    local position = entity.position
    if not (position and position.x and position.y) then
        return true
    end

    local cull_margin = margin
    if type(cull_margin) ~= "number" then
        cull_margin = render_constants.entity_cull_margin or 0
    end

    local radius = Culling.computeCullRadius(entity, fallback)
    if radius <= 0 then
        radius = 0
    end

    local cam_x = camera.x or 0
    local cam_y = camera.y or 0
    local cam_width = camera.width or 0
    local cam_height = camera.height or 0

    local left = cam_x - cull_margin - radius
    local right = cam_x + cam_width + cull_margin + radius
    local top = cam_y - cull_margin - radius
    local bottom = cam_y + cam_height + cull_margin + radius

    local x = position.x
    local y = position.y

    return x >= left and x <= right and y >= top and y <= bottom
end

function Culling.shouldCull(entity, context, options)
    if not entity then
        return false
    end

    if entity.disableRenderCulling or entity.alwaysVisible then
        return false
    end

    local drawable = entity.drawable
    if drawable and (drawable.disableRenderCulling or drawable.alwaysVisible) then
        return false
    end

    local opts = options or {}
    return not Culling.isEntityVisible(entity, context, {
        margin = opts.margin,
        fallback = opts.fallback,
    })
end

function Culling.resolveCamera(source)
    return resolve_camera(source)
end

return Culling
