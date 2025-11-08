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

    love.graphics.push()
    love.graphics.translate(2, 2)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.polygon("fill", vertices)
    love.graphics.pop()

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)
    love.graphics.polygon("fill", vertices)

    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", vertices)

    local health = entity.health
    local bar = entity.healthBar
    if health and bar and health.max and health.max > 0 and health.showTimer and health.showTimer > 0 then
        local showDuration = bar.showDuration or 0
        local alpha = showDuration > 0 and math.min(1, health.showTimer / showDuration) or 1
        if alpha > 0 then
            local pct = math.max(0, math.min(1, (health.current or 0) / health.max))
            local baseWidth = bar.width or 40
            local width = baseWidth * 0.5
            local height = bar.height or 4
            local offset = math.abs(bar.offset or 0)
            local halfWidth = width * 0.5
            local rotation = entity.rotation or 0

            love.graphics.push()
            love.graphics.rotate(-rotation)
            love.graphics.translate(0, -(offset))

            love.graphics.setColor(0, 0, 0, 0.5 * alpha)
            love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width, height)

            if pct > 0 then
                love.graphics.setColor(1, 1, 0, alpha)
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
