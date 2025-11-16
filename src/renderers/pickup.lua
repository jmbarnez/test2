---@diagnostic disable: undefined-global
-- Pickup renderer
-- Draws pickup items in the world, with optional bobbing and custom
-- icon layers. Icons are made from simple shapes (circle, ring, triangle, etc.)
local love = love
local math = math

local pickup_renderer = {}

--- Set love.graphics color using an RGBA table or use white as fallback.
local function set_color(color)
    if type(color) == "table" then
        love.graphics.setColor(
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            color[4] or 1
        )
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
end

--- Draw a single icon layer for item icons. Supports multiple shapes.
-- @param icon table parent icon definition (may contain color defaults)
-- @param layer table layer definition (shape, offsets, color)
-- @param size number scale of base icon
local function draw_icon_layer(icon, layer, size)
    love.graphics.push()

    local color = layer.color or icon.detail or icon.color or icon.accent
    set_color(color)

    local offsetX = (layer.offsetX or 0) * size
    local offsetY = (layer.offsetY or 0) * size
    love.graphics.translate(offsetX, offsetY)

    if layer.rotation then
        love.graphics.rotate(layer.rotation)
    end

    local shape = layer.shape or "circle"
    local halfSize = size * 0.5

    if shape == "circle" then
        local radius = (layer.radius or 0.5) * halfSize
        love.graphics.circle("fill", 0, 0, radius)
    elseif shape == "ring" then
        local radius = (layer.radius or 0.5) * halfSize
        local thickness = (layer.thickness or 0.1) * halfSize
        love.graphics.setLineWidth(thickness)
        love.graphics.circle("line", 0, 0, radius)
    elseif shape == "rectangle" then
        local width = (layer.width or 0.6) * size
        local height = (layer.height or 0.2) * size
        love.graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height)
    elseif shape == "rounded_rect" then
        local width = (layer.width or 0.6) * size
        local height = (layer.height or 0.2) * size
        local radius = (layer.radius or 0.1) * size
        love.graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height, radius, radius)
    elseif shape == "triangle" then
        local width = (layer.width or 0.5) * size
        local height = (layer.height or 0.5) * size
        local direction = layer.direction or "up"
        local halfWidth = width * 0.5
        if direction == "up" then
            love.graphics.polygon("fill", 0, -height * 0.5, halfWidth, height * 0.5, -halfWidth, height * 0.5)
        else
            love.graphics.polygon("fill", 0, height * 0.5, halfWidth, -height * 0.5, -halfWidth, -height * 0.5)
        end
    elseif shape == "beam" then
        local width = (layer.width or 0.2) * size
        local length = (layer.length or 0.8) * size
        love.graphics.rectangle("fill", -length * 0.5, -width * 0.5, length, width)
    else
        local radius = (layer.radius or 0.4) * halfSize
        love.graphics.circle("fill", 0, 0, radius)
    end

    love.graphics.pop()
end

--- Draw a full item icon (stack of layers) at the origin.
-- Returns true when an icon was drawn.
local function draw_item_icon(icon, size)
    if type(icon) ~= "table" then
        return false
    end

    local layers = icon.layers
    if type(layers) ~= "table" or #layers == 0 then
        local baseColor = icon.color or icon.detail or icon.accent
        set_color(baseColor)
        love.graphics.circle("fill", 0, 0, size * 0.35)
        return true
    end

    for i = 1, #layers do
        local layer = layers[i]
        if type(layer) == "table" then
            draw_icon_layer(icon, layer, size)
        end
    end

    return true
end

--- Draw a pickup entity at its position with optional bob and rotation.
-- @param entity table collectible entity with drawable property.
function pickup_renderer.draw(entity)
    local pos = entity.position
    local drawable = entity.drawable
    if not (pos and drawable) then
        return
    end

    love.graphics.push("all")
    love.graphics.translate(pos.x, pos.y)

    local bob = 0
    if drawable.bobAmplitude and drawable.bobAmplitude ~= 0 then
        local speed = drawable.bobSpeed or 2
        local timer = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
        bob = math.sin(timer * speed) * drawable.bobAmplitude
        love.graphics.translate(0, bob)
    end

    if entity.rotation then
        love.graphics.rotate(entity.rotation)
    end

    local size = drawable.size or 28

    love.graphics.push()
    if drawable.icon then
        draw_item_icon(drawable.icon, size)
    else
        set_color(drawable.color or {0.8, 0.8, 0.8})
        love.graphics.circle("fill", 0, 0, size * 0.4)
        set_color({1, 1, 1, 0.25})
        love.graphics.circle("line", 0, 0, size * 0.4)
    end
    love.graphics.pop()

    love.graphics.pop()
end

return pickup_renderer
