---@diagnostic disable: undefined-global

local drawable_helpers = {}

local function clone_table(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function drawable_helpers.normalise_color(color, fallback)
    fallback = fallback or { 1, 1, 1, 1 }
    if type(color) ~= "table" then
        return { fallback[1], fallback[2], fallback[3], fallback[4] }
    end

    return {
        color[1] ~= nil and color[1] or fallback[1],
        color[2] ~= nil and color[2] or fallback[2],
        color[3] ~= nil and color[3] or fallback[3],
        color[4] ~= nil and color[4] or fallback[4],
    }
end

do
    local normalise_color = drawable_helpers.normalise_color

    function drawable_helpers.resolve_color(palette, spec, fallback)
        local fallback_color = normalise_color(fallback)
        if type(spec) == "table" and #spec >= 3 then
            return normalise_color(spec, fallback_color)
        elseif type(spec) == "string" and palette and palette[spec] then
            local color = palette[spec]
            if type(color) == "table" and #color >= 3 then
                return normalise_color(color, fallback_color)
            end
        end

        return fallback_color
    end
end

function drawable_helpers.apply_transform(part)
    local has_transform = false
    if part.offset then
        love.graphics.translate(part.offset.x or 0, part.offset.y or 0)
        has_transform = true
    end
    if part.rotation then
        love.graphics.rotate(part.rotation)
        has_transform = true
    end
    if part.scale then
        if type(part.scale) == "table" then
            love.graphics.scale(part.scale.x or 1, part.scale.y or 1)
        else
            love.graphics.scale(part.scale, part.scale)
        end
        has_transform = true
    end

    return has_transform
end

function drawable_helpers.mirror_points(points)
    if type(points) ~= "table" then
        return {}
    end

    local mirrored = {}
    for i = 1, #points, 2 do
        mirrored[#mirrored + 1] = -(points[i] or 0)
        mirrored[#mirrored + 1] = points[i + 1] or 0
    end
    return mirrored
end

function drawable_helpers.draw_polygon_part(part, palette, defaults)
    local points = part.points
    if type(points) ~= "table" or #points < 6 then
        return
    end

    love.graphics.push()
    drawable_helpers.apply_transform(part)

    local base_color = drawable_helpers.resolve_color(palette, part.fill or part.tag or "default", defaults.fill)
    local fill_alpha = part.alpha or base_color[4] or defaults.alpha or 1
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], fill_alpha)
    local mode = part.mode or "fill"
    love.graphics.polygon(mode, points)

    if part.stroke ~= false and mode ~= "line" then
        local stroke_color = drawable_helpers.resolve_color(palette, part.stroke or "outline", defaults.stroke)
        local stroke_alpha = part.strokeAlpha or stroke_color[4] or fill_alpha
        love.graphics.setColor(stroke_color[1], stroke_color[2], stroke_color[3], stroke_alpha)
        love.graphics.setLineWidth(part.strokeWidth or defaults.strokeWidth or 2)
        love.graphics.polygon("line", points)
    end

    love.graphics.pop()
end

function drawable_helpers.draw_ellipse_part(part, palette, defaults)
    local radius_x = part.radiusX or (part.width and part.width * 0.5) or part.radius or defaults.ellipseRadius or 5
    local radius_y = part.radiusY or (part.height and part.height * 0.5) or part.length or radius_x

    love.graphics.push()
    drawable_helpers.apply_transform(part)

    local blend = part.blend
    if blend then
        love.graphics.setBlendMode(blend)
    end

    local base_color = drawable_helpers.resolve_color(palette, part.fill or part.tag or "default", defaults.fill)
    local fill_alpha = part.alpha or base_color[4] or defaults.alpha or 1
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], fill_alpha)
    love.graphics.ellipse(part.mode or "fill", part.centerX or 0, part.centerY or 0, radius_x, radius_y)

    if part.stroke and part.stroke ~= false then
        local stroke_color = drawable_helpers.resolve_color(palette, part.stroke, defaults.stroke)
        local stroke_alpha = part.strokeAlpha or stroke_color[4] or fill_alpha
        love.graphics.setColor(stroke_color[1], stroke_color[2], stroke_color[3], stroke_alpha)
        love.graphics.setLineWidth(part.strokeWidth or defaults.strokeWidth or 1)
        love.graphics.ellipse("line", part.centerX or 0, part.centerY or 0, radius_x, radius_y)
    end

    if blend then
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

function drawable_helpers.draw_parts(parts, palette, defaults)
    if type(parts) ~= "table" then
        return
    end

    for i = 1, #parts do
        local part = parts[i]
        if part then
            local part_type = part.type or "polygon"
            if part_type == "polygon" then
                drawable_helpers.draw_polygon_part(part, palette, defaults)

                local mirror = part.mirror or part.mirrorX or part.mirrorHorizontal
                if mirror then
                    local mirrored = clone_table(part)
                    mirrored.points = drawable_helpers.mirror_points(part.points)
                    mirrored.mirror = nil
                    mirrored.mirrorX = nil
                    mirrored.mirrorHorizontal = nil
                    drawable_helpers.draw_polygon_part(mirrored, palette, defaults)
                end
            elseif part_type == "ellipse" then
                drawable_helpers.draw_ellipse_part(part, palette, defaults)
            end
        end
    end
end

return drawable_helpers
