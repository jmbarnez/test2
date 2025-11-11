---@diagnostic disable: undefined-global

local wreckage_renderer = {}

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

    love.graphics.pop()
end

return wreckage_renderer
