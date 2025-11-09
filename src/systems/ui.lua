local tiny = require("libs.tiny")
local theme = require("src.ui.theme")
local tooltip = require("src.ui.tooltip")
local cargo_window = require("src.ui.windows.cargo")
local death_window = require("src.ui.windows.death")
local multiplayer_window = require("src.ui.windows.multiplayer")
---@diagnostic disable-next-line: undefined-global
local love = love

local function set_color(color, alphaOverride)
    local r, g, b, a = 1, 1, 1, 1
    if type(color) == "table" then
        r = color[1] ~= nil and color[1] or r
        g = color[2] ~= nil and color[2] or g
        b = color[3] ~= nil and color[3] or b
        if color[4] ~= nil then
            a = color[4]
        end
    end
    if alphaOverride ~= nil then
        a = alphaOverride
    end
    love.graphics.setColor(r, g, b, a)
end

local function draw_icon_layer(icon, layer, size)
    love.graphics.push()

    local baseColor = layer.color or icon.detail or icon.color or icon.accent
    local alpha = layer.alpha
    set_color(baseColor, alpha)

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

local function draw_item_icon(icon, x, y, size)
    if type(icon) ~= "table" then
        return false
    end

    local layers = icon.layers
    if type(layers) ~= "table" or #layers == 0 then
        local baseColor = icon.color or icon.detail or icon.accent
        set_color(baseColor, 1)
        local radius = size * 0.35
        love.graphics.circle("fill", x + size * 0.5, y + size * 0.5, radius)
        return true
    end

    love.graphics.push("all")
    love.graphics.translate(x + size * 0.5, y + size * 0.5)

    for i = 1, #layers do
        local layer = layers[i]
        if type(layer) == "table" then
            draw_icon_layer(icon, layer, size)
        end
    end

    love.graphics.pop()
    return true
end

return function(context)
    return tiny.system {
        draw = function()
            local uiInput = context and context.uiInput
            if uiInput then
                uiInput.mouseCaptured = false
                uiInput.keyboardCaptured = false
            end

            tooltip.begin_frame()
            cargo_window.draw(context)
            death_window.draw(context)
            multiplayer_window.draw(context)
            local mouse_x, mouse_y = love.mouse.getPosition()
            tooltip.draw(mouse_x, mouse_y, theme.get_fonts())
        end,
    }
end
