---@diagnostic disable: undefined-global

--- Asteroid renderer
-- Responsible for drawing asteroid entities, applying multiple layered
-- fill and stroke operations to provide a textured rock-like appearance.
local asteroid_renderer = {}

--- Draws an asteroid entity on screen.
-- @param entity table An entity with the drawable shape and position/rotation
function asteroid_renderer.draw(entity)
    local drawable = entity.drawable
    local vertices = drawable and drawable.shape
    if type(vertices) ~= "table" or #vertices < 6 then
        return
    end

    love.graphics.push("all")
    love.graphics.translate(entity.position.x, entity.position.y)
    love.graphics.rotate(entity.rotation or 0)

    local baseColor = drawable.color
    if type(baseColor) ~= "table" then
        baseColor = { 0.4, 0.35, 0.3 }
    end

    local radius = drawable.radius or 20

    -- Outer glow
    love.graphics.setColor(baseColor[1] * 0.3, baseColor[2] * 0.3, baseColor[3] * 0.3, 0.2)
    love.graphics.setLineWidth(6)
    love.graphics.polygon("line", vertices)

    -- Base fill with darker tone
    love.graphics.setColor(baseColor[1] * 0.5, baseColor[2] * 0.5, baseColor[3] * 0.5, baseColor[4] or 1)
    love.graphics.polygon("fill", vertices)

    -- Texture layer 1: Mid-tone patches
    love.graphics.push()
    love.graphics.scale(0.85, 0.85)
    love.graphics.rotate(0.3)
    love.graphics.setColor(
        baseColor[1] * 0.7,
        baseColor[2] * 0.7,
        baseColor[3] * 0.7,
        (baseColor[4] or 1) * 0.6
    )
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    -- Texture layer 2: Lighter inner region
    love.graphics.push()
    love.graphics.scale(0.65, 0.65)
    love.graphics.rotate(-0.2)
    love.graphics.setColor(
        math.min(1, baseColor[1] * 1.1),
        math.min(1, baseColor[2] * 1.1),
        math.min(1, baseColor[3] * 1.1),
        (baseColor[4] or 1) * 0.5
    )
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    -- Texture layer 3: Bright highlights
    love.graphics.push()
    love.graphics.scale(0.4, 0.4)
    love.graphics.rotate(0.5)
    love.graphics.setColor(
        math.min(1, baseColor[1] * 1.4),
        math.min(1, baseColor[2] * 1.4),
        math.min(1, baseColor[3] * 1.4),
        (baseColor[4] or 1) * 0.4
    )
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    -- Shadow crevices
    love.graphics.push()
    love.graphics.scale(0.75, 0.75)
    love.graphics.rotate(-0.4)
    love.graphics.setColor(baseColor[1] * 0.2, baseColor[2] * 0.2, baseColor[3] * 0.2, 0.4)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", vertices)
    love.graphics.pop()

    -- Main outline
    love.graphics.setColor(baseColor[1] * 0.3, baseColor[2] * 0.3, baseColor[3] * 0.3, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", vertices)

    -- Bright edge highlight
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", vertices)

    -- Health bar
    local health = entity.health
    local bar = entity.healthBar
    if health and bar and health.max and health.max > 0 and health.showTimer and health.showTimer > 0 then
        local showDuration = bar.showDuration or 0
        local alpha = showDuration > 0 and math.min(1, health.showTimer / showDuration) or 1
        if alpha > 0 then
            local pct = math.max(0, math.min(1, (health.current or 0) / health.max))
            local baseWidth = bar.width or radius * 1.2
            local width = baseWidth * 0.6
            local height = bar.height or 5
            local offset = math.abs(bar.offset or radius + 8)
            local halfWidth = width * 0.5
            local rotation = entity.rotation or 0

            love.graphics.push()
            love.graphics.rotate(-rotation)
            love.graphics.translate(0, -(offset))

            love.graphics.setColor(0, 0, 0, 0.7 * alpha)
            love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width, height)

            if pct > 0 then
                local r, g, b
                if pct > 0.6 then
                    r, g, b = 0.3, 0.9, 0.5
                elseif pct > 0.3 then
                    r, g, b = 0.95, 0.8, 0.3
                else
                    r, g, b = 0.95, 0.4, 0.3
                end
                
                love.graphics.setColor(r, g, b, alpha)
                love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width * pct, height)
            end

            love.graphics.setColor(0, 0, 0, 0.9 * alpha)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", -halfWidth, -height * 0.5, width, height)

            love.graphics.pop()
        end
    end

    love.graphics.pop()
end

return asteroid_renderer
