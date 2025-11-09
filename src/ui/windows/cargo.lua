---@diagnostic disable: undefined-global
local theme = require("src.ui.theme")
local window = require("src.ui.window")
local tooltip = require("src.ui.tooltip")
local PlayerManager = require("src.player.manager")
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

local function draw_icon_layer(icon, layer, size)
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
            draw_icon_layer(icon, layer, size)
        end
    end

    love.graphics.pop()
    return true
end

local function wrap_text(text, font, maxWidth)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local lines = {}
    local currentLine = ""
    
    for i, word in ipairs(words) do
        local testLine = currentLine == "" and word or currentLine .. " " .. word
        if font:getWidth(testLine) <= maxWidth then
            currentLine = testLine
        else
            if currentLine ~= "" then
                table.insert(lines, currentLine)
                currentLine = word
            else
                table.insert(lines, word)
            end
        end
    end
    
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    
    return lines
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

local function calculate_grid_layout(contentWidth, contentHeight)
    local slotSize = theme_spacing.slot_size
    local slotPadding = theme_spacing.slot_padding
    local labelHeight = 32
    local slotWithLabelHeight = slotSize + labelHeight + 4
    
    local slotsPerRow = math.max(1, math.floor((contentWidth + slotPadding) / (slotSize + slotPadding)))
    local slotsPerColumn = math.max(1, math.floor((contentHeight + slotPadding) / (slotWithLabelHeight + slotPadding)))
    local totalVisibleSlots = slotsPerRow * slotsPerColumn
    
    return slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight
end

local function draw_slot_background(slotX, slotY, slotSize, isHovered, isSelected)
    if isHovered then
        set_color(window_colors.row_hover or { 1, 1, 1, 0.1 })
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 3, 3)
    end
    
    if isHovered or isSelected then
        set_color(window_colors.slot_border or { 0.08, 0.08, 0.12, 0.5 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", slotX + 0.5, slotY + 0.5, slotSize - 1, slotSize - 1, 3, 3)
    end
end

local function draw_item_in_slot(item, slotX, slotY, slotSize, fonts)
    local iconSize = slotSize - 10
    local iconX = slotX + 5
    local iconY = slotY + 5

    -- Draw icon
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

    -- Draw item name with text wrapping
    local itemName = item.name or "Unknown Item"
    local font = fonts.small or fonts.body
    love.graphics.setFont(font)
    set_color(window_colors.text)
    
    local textLines = wrap_text(itemName, font, slotSize - 4)
    local lineHeight = font:getHeight()
    local textStartY = slotY + slotSize + 2
    
    for j, line in ipairs(textLines) do
        local textWidth = font:getWidth(line)
        local textX = slotX + (slotSize - textWidth) * 0.5
        local textY = textStartY + (j - 1) * lineHeight
        love.graphics.print(line, textX, textY)
    end
end

local function create_item_tooltip(item)
    if not item then return end
    
    local tooltip_body = {}
    if item.quantity then
        tooltip_body[#tooltip_body + 1] = string.format("Quantity: %s", item.quantity)
    end
    if item.volume then
        tooltip_body[#tooltip_body + 1] = string.format("Volume: %s", item.volume)
    end

    tooltip.request({
        heading = item.name or "Unknown Item",
        body = tooltip_body,
        description = item.description,
    })
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

    local player = PlayerManager.resolveLocalPlayer(context)
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

    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_mouse_down = love.mouse.isDown(1)
    local just_pressed = is_mouse_down and not state._was_mouse_down
    local uiInput = context.uiInput

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

    local window_x = state.x or dims.x
    local window_y = state.y or dims.y
    local window_width = state.width or dims.width
    local window_height = state.height or dims.height
    local mouseInsideWindow = mouse_x and mouse_y and 
        mouse_x >= window_x and mouse_x <= window_x + window_width and 
        mouse_y >= window_y and mouse_y <= window_y + window_height

    if uiInput and state.visible then
        if mouseInsideWindow or state.dragging or frame.dragging then
            uiInput.mouseCaptured = true
        end
    end

    local content = frame.content
    local slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight = 
        calculate_grid_layout(content.width, content.height)

    local slotPadding = theme_spacing.slot_padding
    local gridStartY = content.y
    local gridStartX = content.x

    local hoveredItem
    local hoveredSlotIndex

    for slotNumber = 1, totalVisibleSlots do
        local slotIndex = slotNumber - 1
        local row = math.floor(slotIndex / slotsPerRow)
        local col = slotIndex % slotsPerRow
        local slotX = gridStartX + col * (slotSize + slotPadding)
        local slotY = gridStartY + row * (slotWithLabelHeight + slotPadding)

        local item = items[slotNumber]
        local isMouseOver = mouse_x >= slotX and mouse_x <= slotX + slotSize and 
                           mouse_y >= slotY and mouse_y <= slotY + slotSize

        if isMouseOver then
            hoveredItem = item
            hoveredSlotIndex = slotIndex
            create_item_tooltip(item)
        end

        local isSelected = state._hovered_slot == slotIndex
        draw_slot_background(slotX, slotY, slotSize, isMouseOver, isSelected)

        if item then
            draw_item_in_slot(item, slotX, slotY, slotSize, fonts)
        end
    end

    state._hovered_slot = hoveredSlotIndex
    state._hovered_item = hoveredItem
    state._was_mouse_down = is_mouse_down

    if frame.close_clicked then
        state.visible = false
        state.dragging = false
    end

    love.graphics.pop()
end

return cargo_window
