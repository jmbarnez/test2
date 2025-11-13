local love = love

local explosion_renderer = {}

function explosion_renderer.draw(explosions)
    if not (explosions and #explosions > 0) then
        return
    end

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    for i = 1, #explosions do
        local e = explosions[i]
        local radius = e.radius or 0
        if radius > 0 then
            if e.color then
                love.graphics.setColor(e.color[1] or 1, e.color[2] or 1, e.color[3] or 1, e.color[4] or 1)
            else
                love.graphics.setColor(1, 1, 1, 0.8)
            end
            love.graphics.circle("fill", e.x or 0, e.y or 0, radius)

            if e.ringColor then
                love.graphics.setColor(e.ringColor[1] or 1, e.ringColor[2] or 1, e.ringColor[3] or 1, e.ringColor[4] or 1)
                local ringRadius = e.ringRadius or radius * 0.85
                local lineWidth = e.ringWidth or math.max(2, radius * 0.1)
                love.graphics.setLineWidth(lineWidth)
                love.graphics.circle("line", e.x or 0, e.y or 0, ringRadius)
            end
        end
    end

    love.graphics.pop()
end

return explosion_renderer
