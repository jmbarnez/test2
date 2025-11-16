---@diagnostic disable: undefined-global
-- Pickup renderer
-- Draws pickup items in the world, with optional bobbing and custom
-- icon layers. Icons are made from simple shapes (circle, ring, triangle, etc.)
local love = love
local math = math
local ItemIconRenderer = require("src.util.item_icon_renderer")

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

--- Draw a full item icon (stack of layers) at the origin.
-- Returns true when an icon was drawn.
local function draw_item_icon(icon, size)
    return ItemIconRenderer.draw(icon, size, {
        set_color = set_color,
        fallbackRadius = 0.35,
    })
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
