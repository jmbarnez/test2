---@diagnostic disable: undefined-global
-- Wreckage renderer
-- Draws destroyed ship fragments and optional health/repair overlays.
local wreckage_renderer = {}

--- Draw a wreckage entity at its position. Draws a polygon fill/outline
-- and a small health bar if the entity has a health component.
function wreckage_renderer.draw(entity)
    if not (entity and entity.position and entity.drawable) then
        return
    end

    local drawable = entity.drawable
    local polygon = drawable.polygon
    if type(polygon) ~= "table" or #polygon < 6 then
        return
    end

    love.graphics.push("all")
    love.graphics.translate(entity.position.x or 0, entity.position.y or 0)
    love.graphics.rotate(entity.rotation or 0)

    local fill_color = drawable.color or { 0.4, 0.45, 0.5, 1 }
    local outline_color = drawable.outline or { 0.2, 0.25, 0.3, 1 }
    local line_width = drawable.lineWidth or 1.5

    local wreckage = entity.wreckage
    local alpha = drawable.alpha or 1
    if wreckage and wreckage.alpha then
        alpha = alpha * wreckage.alpha
    end

    love.graphics.setColor(
        fill_color[1] or 1,
        fill_color[2] or 1,
        fill_color[3] or 1,
        (fill_color[4] or 1) * alpha
    )
    love.graphics.polygon("fill", polygon)

    love.graphics.setLineWidth(line_width)
    love.graphics.setColor(
        outline_color[1] or fill_color[1] or 1,
        outline_color[2] or fill_color[2] or 1,
        outline_color[3] or fill_color[3] or 1,
        (outline_color[4] or fill_color[4] or 1) * alpha
    )
    love.graphics.polygon("line", polygon)

    local health = entity.health
    local bar = entity.healthBar
    if health and bar and health.max and health.max > 0 then
        local showTimer = health.showTimer or 0
        local showDuration = bar.showDuration or 0
        if showDuration <= 0 or showTimer > 0 then
            local alpha_bar = showDuration > 0 and math.min(1, showTimer / showDuration) or 1
            if alpha_bar > 0 then
                local pct = math.max(0, math.min(1, (health.current or 0) / health.max))
                local wreckage = entity.wreckage
                local reference_radius = wreckage and wreckage.pieceRadius or 18
                local baseWidth = bar.width or (reference_radius * 1.8)
                local width = baseWidth * 0.7
                local height = bar.height or 5
                local offset = math.abs(bar.offset or (reference_radius + 8))
                local halfWidth = width * 0.5

                love.graphics.push()
                love.graphics.rotate(-(entity.rotation or 0))
                love.graphics.translate(0, -offset)

                love.graphics.setColor(0, 0, 0, 0.65 * alpha_bar)
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

                    love.graphics.setColor(r, g, b, alpha_bar)
                    love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width * pct, height)
                end

                love.graphics.setColor(0, 0, 0, 0.9 * alpha_bar)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", -halfWidth, -height * 0.5, width, height)

                love.graphics.pop()
            end
        end
    end

    love.graphics.pop()
end

return wreckage_renderer
