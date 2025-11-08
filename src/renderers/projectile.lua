local love = love

local projectile_renderer = {}

function projectile_renderer.draw(entity)
    if not (entity and entity.position and entity.drawable) then
        return
    end

    local x = entity.position.x
    local y = entity.position.y
    local drawable = entity.drawable
    local size = drawable.size or 6
    local color = drawable.color or { 0.2, 0.8, 1.0 }
    local glowColor = drawable.glowColor or { 0.5, 0.9, 1.0 }

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    -- Outer glow
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.3)
    love.graphics.circle("fill", x, y, size * 1.5)

    -- Middle glow
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.6)
    love.graphics.circle("fill", x, y, size)

    -- Core
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.circle("fill", x, y, size * 0.6)

    -- Bright center
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", x, y, size * 0.3)

    love.graphics.pop()
end

return projectile_renderer
