local ItemIconRenderer = {}

---@diagnostic disable-next-line: undefined-global
local love = love

local function default_set_color(color)
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

local function resolve_set_color(options)
    if options and type(options.set_color) == "function" then
        return options.set_color
    end
    return default_set_color
end

local function build_polygon_vertices(points, halfSize)
    local vertices = {}
    for i = 1, #points, 2 do
        local px = points[i]
        local py = points[i + 1]
        if type(px) == "number" and type(py) == "number" then
            vertices[#vertices + 1] = px * halfSize
            vertices[#vertices + 1] = py * halfSize
        end
    end
    return vertices
end

---@param icon table
---@param layer table
---@param size number
---@param options table|nil
function ItemIconRenderer.drawLayer(icon, layer, size, options)
    if type(layer) ~= "table" then
        return
    end

    local set_color = resolve_set_color(options)

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
    elseif shape == "polygon" then
        local points = layer.points
        if type(points) == "table" and #points >= 6 then
            local vertices = build_polygon_vertices(points, halfSize)
            if #vertices >= 6 then
                local drawMode = (layer.mode == "line" or layer.draw == "line") and "line" or "fill"
                if drawMode == "line" then
                    local thickness = (layer.lineWidth or layer.thickness or 0.08) * halfSize
                    love.graphics.setLineWidth(thickness)
                end
                love.graphics.polygon(drawMode, vertices)
            end
        end
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

---@param icon table
---@param size number
---@param options table|nil
---@return boolean
function ItemIconRenderer.draw(icon, size, options)
    if type(icon) ~= "table" then
        return false
    end

    local set_color = resolve_set_color(options)
    local layers = icon.layers

    if type(layers) ~= "table" or #layers == 0 then
        set_color(icon.color or icon.detail or icon.accent)
        local fallbackRadius = ((options and options.fallbackRadius) or 0.35) * size
        love.graphics.circle("fill", 0, 0, fallbackRadius)
        return true
    end

    for i = 1, #layers do
        ItemIconRenderer.drawLayer(icon, layers[i], size, options)
    end

    return true
end

---@param icon table
---@param x number
---@param y number
---@param size number
---@param options table|nil
---@return boolean
function ItemIconRenderer.drawAt(icon, x, y, size, options)
    if type(icon) ~= "table" then
        return false
    end

    love.graphics.push("all")

    local anchorX = 0.5
    local anchorY = 0.5
    if options then
        if options.anchorX ~= nil then
            anchorX = options.anchorX
        end
        if options.anchorY ~= nil then
            anchorY = options.anchorY
        end
    end

    love.graphics.translate(x + size * anchorX, y + size * anchorY)
    local result = ItemIconRenderer.draw(icon, size, options)

    love.graphics.pop()

    return result
end

return ItemIconRenderer
