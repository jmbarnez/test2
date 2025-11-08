---@diagnostic disable: undefined-global

local asteroid_renderer = {}

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

    -- Deep shadow layers for depth
    love.graphics.push()
    love.graphics.translate(4, 4)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(2, 2)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    -- Darkest base layer
    love.graphics.setColor(
        baseColor[1] * 0.5,
        baseColor[2] * 0.5,
        baseColor[3] * 0.5,
        baseColor[4] or 1
    )
    love.graphics.polygon("fill", vertices)

    -- Mid-tone layer with slight offset
    love.graphics.push()
    love.graphics.scale(0.85, 0.85)
    love.graphics.setColor(
        baseColor[1] * 0.8,
        baseColor[2] * 0.8,
        baseColor[3] * 0.8,
        baseColor[4] or 1
    )
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    -- Highlighted surface with texture variation
    love.graphics.push()
    love.graphics.scale(0.7, 0.7)
    love.graphics.setColor(
        baseColor[1] + 0.1,
        baseColor[2] + 0.1,
        baseColor[3] + 0.1,
        baseColor[4] or 1
    )
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    -- Bright highlight spots for mineral reflections
    love.graphics.push()
    love.graphics.scale(0.4, 0.4)
    love.graphics.translate(-radius * 0.3, -radius * 0.3)
    love.graphics.setColor(
        math.min(1, baseColor[1] + 0.3),
        math.min(1, baseColor[2] + 0.3),
        math.min(1, baseColor[3] + 0.25),
        (baseColor[4] or 1) * 0.6
    )
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    -- Dark cracks and crevices
    love.graphics.setColor(0.1, 0.08, 0.06, 0.8)
    love.graphics.setLineWidth(2.5)
    love.graphics.polygon("line", vertices)

    -- Rough outer edge
    love.graphics.setColor(0.2, 0.18, 0.15, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", vertices)

    -- Mineral highlights on edges
    love.graphics.setColor(0.7, 0.65, 0.55, 0.5)
    love.graphics.setLineWidth(0.5)
    love.graphics.polygon("line", vertices)

    -- Enhanced health bar
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

            -- Health bar background with glow
            love.graphics.setColor(0, 0, 0, 0.6 * alpha)
            love.graphics.rectangle("fill", -halfWidth - 1, -height * 0.5 - 1, width + 2, height + 2)

            love.graphics.setColor(0.1, 0.1, 0.1, 0.8 * alpha)
            love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width, height)

            if pct > 0 then
                -- Dynamic health bar color based on percentage
                local r, g, b
                if pct > 0.6 then
                    r, g, b = 0.2, 0.8, 0.3  -- Green
                elseif pct > 0.3 then
                    r, g, b = 0.9, 0.7, 0.2  -- Yellow
                else
                    r, g, b = 0.9, 0.3, 0.2  -- Red
                end
                
                love.graphics.setColor(r, g, b, alpha)
                love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width * pct, height)
                
                -- Health bar highlight
                love.graphics.setColor(r + 0.2, g + 0.2, b + 0.2, alpha * 0.7)
                love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width * pct, height * 0.4)
            end

            -- Health bar border
            love.graphics.setColor(0.2, 0.2, 0.2, 0.9 * alpha)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", -halfWidth, -height * 0.5, width, height)

            love.graphics.pop()
        end
    end

    love.graphics.pop()
end

return asteroid_renderer
