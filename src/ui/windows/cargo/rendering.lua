-- Cargo Rendering: Visual rendering for cargo items and icons
-- Handles icon layers, slot backgrounds, currency icons, and item display

local theme = require("src.ui.theme")
local CargoData = require("src.ui.windows.cargo.data")

---@diagnostic disable-next-line: undefined-global
local love = love

local CargoRendering = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color

--- Draws a currency icon
---@param x number X position
---@param y number Y position
---@param size number Icon size
function CargoRendering.drawCurrencyIcon(x, y, size)
    love.graphics.push("all")

    local radius = size * 0.5
    local centerX = x + radius
    local centerY = y + radius

    local baseColor = window_colors.currency_icon_base or { 0.35, 0.7, 1.0, 1 }
    local highlightColor = window_colors.currency_icon_highlight or { 0.75, 0.9, 1.0, 0.9 }
    local borderColor = window_colors.currency_icon_border or { 0.08, 0.25, 0.38, 1 }
    local symbolColor = window_colors.currency_icon_symbol or window_colors.title_text or { 1, 1, 1, 1 }

    -- Base circle
    set_color(baseColor)
    love.graphics.circle("fill", centerX, centerY, radius)

    -- Highlight
    set_color(highlightColor)
    love.graphics.circle("fill", centerX, centerY - radius * 0.25, radius * 0.6)

    -- Border
    set_color(borderColor)
    local borderWidth = math.max(1, size * 0.08)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.circle("line", centerX, centerY, radius - borderWidth * 0.5)

    -- Currency symbol
    set_color(symbolColor)
    local lineWidth = math.max(1.2, size * 0.14)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.line(centerX, centerY - radius * 0.4, centerX, centerY + radius * 0.4)

    love.graphics.setLineWidth(math.max(1, size * 0.1))
    love.graphics.line(centerX - radius * 0.45, centerY - radius * 0.15, centerX + radius * 0.45, centerY - radius * 0.15)
    love.graphics.line(centerX - radius * 0.45, centerY + radius * 0.2, centerX + radius * 0.45, centerY + radius * 0.2)

    love.graphics.pop()
end

--- Draws a single icon layer
---@param icon table The icon definition
---@param layer table The layer to draw
---@param size number The icon size
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
        -- Default to circle
        local radius = (layer.radius or 0.4) * halfSize
        love.graphics.circle("fill", 0, 0, radius)
    end

    love.graphics.pop()
end

--- Draws an item icon
---@param icon table The icon definition
---@param x number X position
---@param y number Y position
---@param size number Icon size
---@return boolean True if icon was drawn
function CargoRendering.drawItemIcon(icon, x, y, size)
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

--- Draws a slot background
---@param slotX number Slot X position
---@param slotY number Slot Y position
---@param slotSize number Slot size
---@param isHovered boolean Whether the slot is hovered
---@param isSelected boolean Whether the slot is selected
function CargoRendering.drawSlotBackground(slotX, slotY, slotSize, isHovered, isSelected)
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

--- Draws an item in a slot
---@param item table|nil The item to draw
---@param slotX number Slot X position
---@param slotY number Slot Y position
---@param slotSize number Slot size
---@param labelHeight number Height reserved for label
---@param fonts table Font table from theme
function CargoRendering.drawItemInSlot(item, slotX, slotY, slotSize, labelHeight, fonts)
    local iconSize = slotSize - 10
    local iconX = slotX + 5
    local iconY = slotY + 5

    -- Draw icon
    local iconDrawn = false
    if item and item.icon then
        iconDrawn = CargoRendering.drawItemIcon(item.icon, iconX, iconY, iconSize)
    end

    if not iconDrawn then
        -- Placeholder icon
        set_color(window_colors.accent)
        local placeholderRadius = iconSize * 0.25
        love.graphics.setLineWidth(1.25)
        love.graphics.circle("line", iconX + iconSize * 0.5, iconY + iconSize * 0.5, placeholderRadius)
    end

    -- Draw quantity badge
    if item and item.quantity ~= nil then
        local quantityFont = fonts.small_bold or fonts.small or fonts.body
        love.graphics.setFont(quantityFont)
        local quantityText = tostring(item.quantity)
        local quantityWidth = quantityFont:getWidth(quantityText)
        local quantityHeight = quantityFont:getHeight()
        local badgePaddingX = 4
        local badgePaddingY = 2
        local badgeWidth = quantityWidth + badgePaddingX * 2
        local badgeHeight = quantityHeight + badgePaddingY * 2
        local badgeX = slotX + slotSize - badgeWidth - 4
        local badgeY = slotY + slotSize - badgeHeight - 4

        set_color(window_colors.slot_quantity_background or { 0, 0, 0, 0.65 })
        love.graphics.rectangle("fill", badgeX, badgeY, badgeWidth, badgeHeight, 3, 3)

        set_color(window_colors.slot_quantity_border or window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", badgeX + 0.5, badgeY + 0.5, badgeWidth - 1, badgeHeight - 1, 3, 3)

        set_color(window_colors.slot_quantity_text or window_colors.text or { 0.85, 0.85, 0.9, 1 })
        love.graphics.print(quantityText, badgeX + badgePaddingX, badgeY + badgePaddingY - 1)
    end

    if not item then
        return
    end

    -- Draw item name
    local itemName = item.name or "Unknown Item"
    local font = fonts.small or fonts.body
    love.graphics.setFont(font)
    set_color(window_colors.text)

    local textLines = CargoData.wrapText(itemName, font, slotSize - 4)
    local lineHeight = font:getHeight()
    local textAreaHeight = (labelHeight or ((theme_spacing.slot_text_height or 16) * 2 + 10)) - 4
    local maxLines = math.max(1, math.floor(textAreaHeight / lineHeight))
    local textStartY = slotY + slotSize + 4

    for j = 1, math.min(#textLines, maxLines) do
        local line = textLines[j]
        local textWidth = font:getWidth(line)
        local textX = slotX + (slotSize - textWidth) * 0.5
        local textY = textStartY + (j - 1) * lineHeight
        love.graphics.print(line, textX, textY)
    end
end

--- Calculates grid layout parameters
---@param contentWidth number Available content width
---@param contentHeight number Available content height
---@param fonts table Font table from theme
---@return number slotsPerRow
---@return number slotsPerColumn
---@return number totalVisibleSlots
---@return number slotSize
---@return number slotWithLabelHeight
---@return number labelHeight
function CargoRendering.calculateGridLayout(contentWidth, contentHeight, fonts)
    local baseSlotSize = theme_spacing.slot_size
    local slotSize = math.floor(baseSlotSize * 1.2 + 0.5)
    local slotPadding = theme_spacing.slot_padding

    local labelFont = fonts and (fonts.small or fonts.body) or nil
    local lineHeight = labelFont and labelFont:getHeight() or theme_spacing.slot_text_height or 16
    local maxLines = 2
    local textAreaHeight = maxLines * lineHeight
    local labelHeight = textAreaHeight + 10
    local slotWithLabelHeight = slotSize + labelHeight

    local slotsPerRow = math.max(1, math.floor((contentWidth + slotPadding) / (slotSize + slotPadding)))
    local slotsPerColumn = math.max(1, math.floor((contentHeight + slotPadding) / (slotWithLabelHeight + slotPadding)))
    local totalVisibleSlots = slotsPerRow * slotsPerColumn

    return slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight, labelHeight
end

--- Draws the cargo capacity bar
---@param bottomBar table The bottom bar frame data
---@param percentFull number The fill percentage (0-1)
---@param capacityVolume number The total capacity
---@param fonts table Font table from theme
function CargoRendering.drawCapacityBar(bottomBar, percentFull, capacityVolume, fonts)
    if not bottomBar then
        return
    end

    local inner = bottomBar.inner or bottomBar
    local innerHeight = math.max(0, inner.height)
    local innerWidth = math.max(0, inner.width)
    local barHeight = math.max(6, math.floor(innerHeight * 0.55))
    local barWidth = math.max(80, math.floor(innerWidth * 0.42))
    local barX = inner.x
    local barY = inner.y + (innerHeight - barHeight) * 0.5

    if barHeight <= 0 or barWidth <= 0 then
        return
    end

    -- Background
    set_color(window_colors.progress_background or { 0.03, 0.03, 0.05, 1 })
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 3, 3)

    -- Fill
    local fillWidth = math.floor(barWidth * percentFull + 0.5)
    if fillWidth > 0 then
        local fillColor = window_colors.progress_fill or { 0.2, 0.55, 0.95, 1 }
        set_color(fillColor)
        love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight, 3, 3)
    end

    -- Border
    set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX + 0.5, barY + 0.5, barWidth - 1, barHeight - 1, 3, 3)

    -- Percentage text
    local percentText
    if capacityVolume and capacityVolume > 0 then
        percentText = string.format("%d%%", math.floor(percentFull * 100 + 0.5))
    else
        percentText = "--"
    end

    if percentText ~= "--" then
        local labelFont = fonts.small or fonts.body
        love.graphics.setFont(labelFont)
        set_color(window_colors.title_text or window_colors.text or { 1, 1, 1, 1 })
        love.graphics.printf(percentText, barX, barY + (barHeight - labelFont:getHeight()) * 0.5, barWidth, "center")
    end

    return barWidth
end

--- Draws currency display in bottom bar
---@param bottomBar table The bottom bar frame data
---@param barWidth number Width of the capacity bar
---@param currencyText string The formatted currency text
---@param fonts table Font table from theme
function CargoRendering.drawCurrency(bottomBar, barWidth, currencyText, fonts)
    if not bottomBar then
        return
    end

    local inner = bottomBar.inner or bottomBar
    local innerHeight = math.max(0, inner.height)
    local innerWidth = math.max(0, inner.width)
    local barX = inner.x

    local currencyFont = fonts.small or fonts.body
    love.graphics.setFont(currencyFont)
    set_color(window_colors.text)
    
    local currencyAreaX = barX + barWidth + 16
    local currencyAreaWidth = math.max(60, inner.x + innerWidth - currencyAreaX)
    local iconSize = math.max(14, math.min(innerHeight - 10, currencyFont:getHeight() + 6))
    local iconX = currencyAreaX
    local iconY = inner.y + (innerHeight - iconSize) * 0.5

    CargoRendering.drawCurrencyIcon(iconX, iconY, iconSize)

    local amountX = iconX + iconSize + 8
    local amountY = inner.y + (innerHeight - currencyFont:getHeight()) * 0.5
    local amountWidth = math.max(20, currencyAreaWidth - (amountX - currencyAreaX))
    love.graphics.printf(currencyText, amountX, amountY, amountWidth, "left")
end

return CargoRendering
