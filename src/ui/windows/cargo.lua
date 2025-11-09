---@diagnostic disable: undefined-global
local theme = require("src.ui.theme")
local window = require("src.ui.window")
---@diagnostic disable-next-line: undefined-global
local love = love

local cargo_window = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local window_metrics = theme.window

local function set_color(color)
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

local function draw_item_icon(icon, x, y, size)
    if type(icon) ~= "table" then
        return false
    end

    local layers = icon.layers
    if type(layers) ~= "table" or #layers == 0 then
        local baseColor = icon.color or icon.detail or icon.accent
        set_color(baseColor)
        local radius = size * 0.35
        love.graphics.circle("fill", x + size * 0.5, y + size * 0.5, radius)
        return true
    end

    love.graphics.push("all")
    love.graphics.translate(x + size * 0.5, y + size * 0.5)

    for i = 1, #layers do
        local layer = layers[i]
        if type(layer) == "table" then
            local color = layer.color or icon.detail or icon.color or icon.accent
            local halfSize = size * 0.5

            love.graphics.push()
            set_color(color)

            local offsetX = (layer.offsetX or 0) * size
            local offsetY = (layer.offsetY or 0) * size
            love.graphics.translate(offsetX, offsetY)

            if layer.rotation then
                love.graphics.rotate(layer.rotation)
            end

            local shape = layer.shape or "circle"

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
    end

    love.graphics.pop()
    return true
end

local function get_dimensions()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local margin = theme_spacing.window_margin

    local width = math.min(720, screenWidth - margin * 2)
    local height = math.min(580, screenHeight - margin * 2)
    local x = (screenWidth - width) * 0.5
    local y = (screenHeight - height) * 0.5

    return {
        x = math.max(margin, math.min(x, screenWidth - width - margin)),
        y = math.max(margin, math.min(y, screenHeight - height - margin)),
        width = width,
        height = height,
    }
end

function cargo_window.draw(context)
    local state = context.cargoUI
    if not state then
        state = {}
        context.cargoUI = state
    end

    if not state.visible then
        state.dragging = false
        return
    end

    local player = context.player
    local cargo = player and player.cargo
    if cargo and cargo.refresh then
        cargo:refresh()
    end

    local items = (cargo and cargo.items) or {}

    love.graphics.push("all")
    love.graphics.origin()

    local fonts = theme.get_fonts()

    local dims = get_dimensions()
    local padding = theme_spacing.window_padding
    local topBarHeight = window_metrics.top_bar_height
    local bottomBarHeight = window_metrics.bottom_bar_height
    local slotSize = theme_spacing.slot_size
    local slotPadding = theme_spacing.slot_padding

    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_mouse_down = love.mouse.isDown(1)
    local just_pressed = is_mouse_down and not state._was_mouse_down

    local frame = window.draw_frame {
        x = state.x or dims.x,
        y = state.y or dims.y,
        width = dims.width,
        height = dims.height,
        title = "CARGO",
        fonts = fonts,
        padding = padding,
        top_bar_height = topBarHeight,
        bottom_bar_height = bottomBarHeight,
        state = state,
        input = {
            x = mouse_x,
            y = mouse_y,
            is_down = is_mouse_down,
            just_pressed = just_pressed,
        },
    }

    local content = frame.content
    local contentX = content.x
    local contentY = content.y

    local slotsPerRow = math.max(1, math.floor((content.width + slotPadding) / (slotSize + slotPadding)))
    local gridHeight = content.height
    local slotsPerColumn = math.max(1, math.floor((gridHeight + slotPadding) / (slotSize + slotPadding)))
    local totalVisibleSlots = slotsPerRow * slotsPerColumn

    local gridStartY = contentY
    local gridStartX = contentX

    for i, item in ipairs(items) do
        if i > totalVisibleSlots then break end

        local slotIndex = i - 1
        local row = math.floor(slotIndex / slotsPerRow)
        local col = slotIndex % slotsPerRow
        local slotX = gridStartX + col * (slotSize + slotPadding)
        local slotY = gridStartY + row * (slotSize + slotPadding)

        local iconSize = slotSize - 10
        local iconX = slotX + 5
        local iconY = slotY + 5

        local iconDrawn = false
        if item.icon then
            iconDrawn = draw_item_icon(item.icon, iconX, iconY, iconSize)
        end

        if not iconDrawn then
            set_color(window_colors.accent)
            local placeholderRadius = iconSize * 0.25
            love.graphics.setLineWidth(1.25)
            love.graphics.circle("line", iconX + iconSize * 0.5, iconY + iconSize * 0.5, placeholderRadius)
        end
    end

    state._was_mouse_down = is_mouse_down

    if frame.close_clicked then
        state.visible = false
        state.dragging = false
    end

    love.graphics.pop()
end

return cargo_window
