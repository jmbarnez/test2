---@diagnostic disable: undefined-global
local theme = require("src.ui.theme")
local window = require("src.ui.window")
local tooltip = require("src.ui.tooltip")
local PlayerManager = require("src.player.manager")
local Items = require("src.items.registry")
local loader = require("src.blueprints.loader")
local utf8 = require("utf8")
---@diagnostic disable-next-line: undefined-global
local love = love

local cargo_window = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local window_metrics = theme.window
local set_color = theme.utils.set_color

local function format_currency(value)
    if type(value) ~= "number" then
        return tostring(value or "--")
    end

    local rounded = math.floor(value + 0.5)
    local absValue = math.abs(rounded)
    local chunks = {}

    repeat
        local remainder = absValue % 1000
        absValue = math.floor(absValue / 1000)
        if absValue > 0 then
            chunks[#chunks + 1] = string.format("%03d", remainder)
        else
            chunks[#chunks + 1] = tostring(remainder)
        end
    until absValue == 0

    local ordered = {}
    for index = #chunks, 1, -1 do
        ordered[#ordered + 1] = chunks[index]
    end

    local formatted = table.concat(ordered, ",")
    if rounded < 0 then
        formatted = "-" .. formatted
    end

    return formatted
end

local function draw_currency_icon(x, y, size)
    love.graphics.push("all")

    local radius = size * 0.5
    local centerX = x + radius
    local centerY = y + radius

    local baseColor = window_colors.currency_icon_base or { 0.35, 0.7, 1.0, 1 }
    local highlightColor = window_colors.currency_icon_highlight or { 0.75, 0.9, 1.0, 0.9 }
    local borderColor = window_colors.currency_icon_border or { 0.08, 0.25, 0.38, 1 }
    local symbolColor = window_colors.currency_icon_symbol or window_colors.title_text or { 1, 1, 1, 1 }

    set_color(baseColor)
    love.graphics.circle("fill", centerX, centerY, radius)

    set_color(highlightColor)
    love.graphics.circle("fill", centerX, centerY - radius * 0.25, radius * 0.6)

    set_color(borderColor)
    local borderWidth = math.max(1, size * 0.08)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.circle("line", centerX, centerY, radius - borderWidth * 0.5)

    set_color(symbolColor)
    local lineWidth = math.max(1.2, size * 0.14)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.line(centerX, centerY - radius * 0.4, centerX, centerY + radius * 0.4)

    love.graphics.setLineWidth(math.max(1, size * 0.1))
    love.graphics.line(centerX - radius * 0.45, centerY - radius * 0.15, centerX + radius * 0.45, centerY - radius * 0.15)
    love.graphics.line(centerX - radius * 0.45, centerY + radius * 0.2, centerX + radius * 0.45, centerY + radius * 0.2)

    love.graphics.pop()
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

    local width = math.min(640, screenWidth - margin * 2)
    local height = math.min(520, screenHeight - margin * 2)
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

    -- Draw quantity badge in bottom-right of slot
    if item.quantity ~= nil then
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

    local definition = item.id and Items.get(item.id) or nil

    local function format_number(value, decimals)
        if type(value) ~= "number" then
            return tostring(value or "--")
        end

        if not decimals then
            if math.abs(value - math.floor(value)) < 0.001 then
                return string.format("%d", value)
            end

            local magnitude = math.abs(value)
            if magnitude >= 100 then
                decimals = 0
            elseif magnitude >= 10 then
                decimals = 1
            else
                decimals = 2
            end
        end

        return string.format("%." .. tostring(decimals) .. "f", value)
    end

    local function capitalize(value)
        if type(value) ~= "string" or value == "" then
            return value
        end
        return value:sub(1, 1):upper() .. value:sub(2)
    end

    local function append_line(body, text)
        if type(text) == "string" and text ~= "" then
            body[#body + 1] = text
        end
    end

    local function is_weapon_item(target)
        if type(target) ~= "table" then
            return false
        end
        if target.type == "weapon" then
            return true
        end
        if target.blueprintCategory == "weapons" then
            return true
        end
        if type(target.id) == "string" and target.id:match("^weapon:") then
            return true
        end
        return false
    end

    local function extract_blueprint_id(target)
        if type(target) ~= "table" then
            return nil
        end
        if type(target.blueprintId) == "string" then
            return target.blueprintId
        end
        if type(target.id) == "string" then
            local blueprintId = target.id:match("^weapon:(.+)")
            if blueprintId then
                return blueprintId
            end
        end
        return nil
    end

    local tooltip_body = {}

    local item_type = (definition and definition.type) or item.type
    if item_type then
        append_line(tooltip_body, string.format("Type: %s", capitalize(tostring(item_type))))
    end

    if item.stackable ~= nil then
        append_line(tooltip_body, string.format("Stackable: %s", item.stackable and "Yes" or "No"))
    end

    if item.installed ~= nil then
        append_line(tooltip_body, string.format("Installed: %s", item.installed and "Yes" or "No"))
    end

    local slot = item.slot or (definition and definition.assign)
    if slot then
        append_line(tooltip_body, string.format("Slot: %s", tostring(slot)))
    end

    local quantity = item.quantity or (definition and definition.defaultQuantity)
    if quantity then
        append_line(tooltip_body, string.format("Quantity: %s", format_number(quantity, 0)))
    end

    local per_unit_volume = item.volume or item.unitVolume or (definition and (definition.volume or definition.unitVolume))
    if per_unit_volume then
        append_line(tooltip_body, string.format("Volume (per): %s", format_number(per_unit_volume)))
        if quantity and quantity > 1 then
            append_line(tooltip_body, string.format("Volume (total): %s", format_number(per_unit_volume * quantity)))
        end
    end

    local description = item.description or (definition and definition.description)

    if is_weapon_item(item) then
        local weapon_stats = {}
        local function append_weapon_stat(label, value, suffix, decimals)
            if value == nil then
                return
            end
            local text
            if type(value) == "number" then
                text = format_number(value, decimals)
            else
                text = tostring(value)
            end
            if suffix then
                text = text .. suffix
            end
            weapon_stats[#weapon_stats + 1] = string.format("%s: %s", label, text)
        end

        local blueprint_id = extract_blueprint_id(item)
        local blueprint_weapon

        if blueprint_id then
            local ok, blueprint = pcall(loader.load, "weapons", blueprint_id)
            if ok and type(blueprint) == "table" then
                local components = blueprint.components
                if type(components) == "table" then
                    blueprint_weapon = components.weapon
                end
                if not description then
                    description = blueprint.description or blueprint.summary
                end
            end
        end

        local weapon_data = blueprint_weapon or (item.metadata and item.metadata.weapon)

        if type(weapon_data) == "table" then
            append_weapon_stat("Mode", weapon_data.fireMode and capitalize(weapon_data.fireMode))

            if weapon_data.damage then
                append_weapon_stat("Damage", weapon_data.damage)
            end

            if weapon_data.damagePerSecond then
                append_weapon_stat("Damage/sec", weapon_data.damagePerSecond)
            end

            if weapon_data.fireRate and weapon_data.fireRate > 0 then
                local rate_text = format_number(weapon_data.fireRate, 2)
                local per_second = 1 / weapon_data.fireRate
                weapon_stats[#weapon_stats + 1] = string.format(
                    "Rate: %s s between shots (%s/s)",
                    rate_text,
                    format_number(per_second, 1)
                )
            end

            if weapon_data.beamDuration then
                append_weapon_stat("Beam Duration", weapon_data.beamDuration, " s", 2)
            end

            if weapon_data.projectileSpeed then
                append_weapon_stat("Projectile Speed", weapon_data.projectileSpeed)
            end

            if weapon_data.projectileLifetime then
                append_weapon_stat("Projectile Lifetime", weapon_data.projectileLifetime, " s", 2)
            end

            if weapon_data.maxRange then
                append_weapon_stat("Range", weapon_data.maxRange)
            elseif weapon_data.projectileSpeed and weapon_data.projectileLifetime then
                append_weapon_stat("Range", weapon_data.projectileSpeed * weapon_data.projectileLifetime)
            end

            if weapon_data.projectileSize then
                append_weapon_stat("Projectile Size", weapon_data.projectileSize)
            end

            if weapon_data.width then
                append_weapon_stat("Beam Width", weapon_data.width)
            end

            if weapon_data.damageType then
                append_weapon_stat("Damage Type", capitalize(weapon_data.damageType))
            end
        end

        if #weapon_stats > 0 then
            append_line(tooltip_body, "Weapon Stats:")
            for i = 1, #weapon_stats do
                append_line(tooltip_body, "  " .. weapon_stats[i])
            end
        end
    end

    tooltip.request({
        heading = item.name or (definition and definition.name) or "Unknown Item",
        body = tooltip_body,
        description = description,
    })
end

local function clear_search_focus(context, state)
    if context and context.uiInput then
        context.uiInput.keyboardCaptured = false
    end
    state.isSearchActive = false
end

function cargo_window.draw(context)
    local state = context.cargoUI
    if not state then
        state = {}
        context.cargoUI = state
    end

    state.searchQuery = state.searchQuery or ""
    state.isSearchActive = state.isSearchActive or false

    local uiInput = context.uiInput

    local isVisible = state.visible == true
    local previousVisible = state._previous_visible

    if previousVisible == nil then
        if not isVisible then
            clear_search_focus(context, state)
        end
    elseif previousVisible ~= isVisible then
        if not isVisible then
            clear_search_focus(context, state)
        elseif uiInput then
            uiInput.keyboardCaptured = false
        end
    end

    if not state.visible then
        state.dragging = false
        clear_search_focus(context, state)
        state._was_mouse_down = love.mouse.isDown(1)
        state._previous_visible = isVisible
        return
    end

    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_mouse_down = love.mouse.isDown(1)
    local just_pressed = is_mouse_down and not state._was_mouse_down

    if state.isSearchActive and uiInput then
        uiInput.keyboardCaptured = true
    end

    local player = PlayerManager.resolveLocalPlayer(context)
    local cargo = player and player.cargo
    if cargo and cargo.refresh then
        cargo:refresh()
    end

    local items = (cargo and cargo.items) or {}
    local usedVolume = cargo and cargo.used or 0
    local capacityVolume = cargo and cargo.capacity or 0
    local availableVolume = cargo and cargo.available
    if availableVolume == nil and capacityVolume > 0 then
        availableVolume = math.max(0, capacityVolume - usedVolume)
    end
    local percentFull = 0
    if capacityVolume and capacityVolume > 0 then
        percentFull = usedVolume / capacityVolume
    end
    percentFull = math.max(0, math.min(percentFull, 1))

    local currencyValue
    if context then
        currencyValue = PlayerManager.getCurrency(context)
    end

    if currencyValue == nil and player then
        if player.currency ~= nil then
            currencyValue = player.currency
        elseif player.credits ~= nil then
            currencyValue = player.credits
        elseif player.wallet then
            currencyValue = player.wallet.balance or player.wallet.credits
        end
    end

    local currencyAmountText
    if currencyValue ~= nil then
        if type(currencyValue) == "number" then
            currencyAmountText = format_currency(currencyValue)
        else
            currencyAmountText = tostring(currencyValue)
        end
    else
        currencyAmountText = "--"
    end

    love.graphics.push("all")
    love.graphics.origin()

    local fonts = theme.get_fonts()
    local dims = get_dimensions()
    local padding = theme_spacing.window_padding
    local topBarHeight = window_metrics.top_bar_height
    local bottomBarHeight = window_metrics.bottom_bar_height

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
    local searchHeight = fonts.body:getHeight() + 12
    local searchSpacing = 6
    local gridY = content.y + searchHeight + searchSpacing
    local gridHeight = content.height - searchHeight - searchSpacing
    if gridHeight < 0 then
        gridHeight = 0
    end

    local slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight = 
        calculate_grid_layout(content.width, gridHeight)

    local slotPadding = theme_spacing.slot_padding
    local gridStartY = gridY
    local gridStartX = content.x

    local searchRect = {
        x = content.x,
        y = content.y,
        width = content.width,
        height = searchHeight,
    }

    local searchHovered = mouse_x >= searchRect.x and mouse_x <= searchRect.x + searchRect.width and
        mouse_y >= searchRect.y and mouse_y <= searchRect.y + searchRect.height

    if searchHovered and just_pressed then
        state.isSearchActive = true
        if uiInput then
            uiInput.keyboardCaptured = true
        end
    elseif just_pressed and not searchHovered then
        if state.isSearchActive and uiInput then
            uiInput.keyboardCaptured = false
        end
        state.isSearchActive = false
    end

    love.graphics.setFont(fonts.body)
    set_color(window_colors.input_background or { 0.06, 0.07, 0.1, 1 })
    love.graphics.rectangle("fill", searchRect.x, searchRect.y, searchRect.width, searchRect.height, 4, 4)
    set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", searchRect.x + 0.5, searchRect.y + 0.5, searchRect.width - 1, searchRect.height - 1, 4, 4)

    local queryText = state.searchQuery or ""
    local placeholder = "Search cargo"
    if queryText == "" and not state.isSearchActive then
        set_color(window_colors.muted or { 0.5, 0.5, 0.55, 1 })
        love.graphics.print(placeholder, searchRect.x + 8, searchRect.y + (searchRect.height - fonts.body:getHeight()) * 0.5)
    else
        set_color(window_colors.text or { 0.85, 0.85, 0.9, 1 })
        love.graphics.print(queryText, searchRect.x + 8, searchRect.y + (searchRect.height - fonts.body:getHeight()) * 0.5)

        if state.isSearchActive then
            local textWidth = fonts.body:getWidth(queryText)
            local caretX = searchRect.x + 8 + textWidth + 2
            local caretY = searchRect.y + 6
            local caretHeight = searchRect.height - 12
            set_color(window_colors.caret or window_colors.text or { 0.85, 0.85, 0.9, 1 })
            love.graphics.rectangle("fill", caretX, caretY, 2, caretHeight)
        end
    end

    if searchHovered then
        love.graphics.setLineWidth(2)
        set_color(window_colors.accent or { 0.2, 0.5, 0.9, 1 })
        love.graphics.rectangle("line", searchRect.x + 0.5, searchRect.y + 0.5, searchRect.width - 1, searchRect.height - 1, 4, 4)
    end

    local filteredItems = items
    if queryText ~= "" then
        local lowerQuery = queryText:lower()
        filteredItems = {}
        for _, item in ipairs(items) do
            local name = item and item.name
            if type(name) == "string" and name:lower():find(lowerQuery, 1, true) then
                filteredItems[#filteredItems + 1] = item
            end
        end
    end

    local hoveredItem
    local hoveredSlotIndex

    for slotNumber = 1, totalVisibleSlots do
        local slotIndex = slotNumber - 1
        local row = math.floor(slotIndex / slotsPerRow)
        local col = slotIndex % slotsPerRow
        local slotX = gridStartX + col * (slotSize + slotPadding)
        local slotY = gridStartY + row * (slotWithLabelHeight + slotPadding)

        local item = filteredItems[slotNumber]
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

    -- Bottom bar / capacity display
    local bottomY = window_y + window_height - bottomBarHeight
    set_color(window_colors.bottom_bar or window_colors.background)
    love.graphics.rectangle("fill", window_x + 1, bottomY, window_width - 2, bottomBarHeight - 1)

    set_color(window_colors.accent or { 0.2, 0.55, 0.95, 1 })
    love.graphics.setLineWidth(2)
    love.graphics.line(window_x + 1, bottomY, window_x + window_width - 1, bottomY)

    local progressMarginX = padding
    local barHeight = math.max(6, math.floor(bottomBarHeight * 0.35))
    local barWidth = math.max(80, math.floor((window_width - progressMarginX * 2) * 0.42))
    local barX = window_x + progressMarginX
    local barY = bottomY + (bottomBarHeight - barHeight) * 0.5

    if barHeight > 0 and barWidth > 0 then
        set_color(window_colors.progress_background or { 0.03, 0.03, 0.05, 1 })
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 3, 3)

        local fillWidth = math.floor(barWidth * percentFull + 0.5)
        if fillWidth > 0 then
            local fillColor = window_colors.progress_fill or { 0.2, 0.55, 0.95, 1 }
            set_color(fillColor)
            love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight, 3, 3)
        end

        set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", barX + 0.5, barY + 0.5, barWidth - 1, barHeight - 1, 3, 3)

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
    end

    local currencyFont = fonts.small or fonts.body
    love.graphics.setFont(currencyFont)
    set_color(window_colors.text)
    local currencyAreaX = barX + barWidth + 16
    local currencyAreaWidth = math.max(60, window_x + window_width - currencyAreaX - progressMarginX)
    local iconSize = math.max(14, math.min(bottomBarHeight - 10, currencyFont:getHeight() + 6))
    local iconX = currencyAreaX
    local iconY = bottomY + (bottomBarHeight - iconSize) * 0.5

    draw_currency_icon(iconX, iconY, iconSize)

    local amountX = iconX + iconSize + 8
    local amountY = bottomY + (bottomBarHeight - currencyFont:getHeight()) * 0.5
    local amountWidth = math.max(20, currencyAreaWidth - (amountX - currencyAreaX))
    love.graphics.printf(currencyAmountText, amountX, amountY, amountWidth, "left")

    if frame.close_clicked then
        state.visible = false
        state.dragging = false
        clear_search_focus(context, state)
    end

    state._previous_visible = state.visible == true

    love.graphics.pop()
end

function cargo_window.textinput(context, text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    local state = context and context.cargoUI
    if not (state and state.visible and state.isSearchActive) then
        return false
    end

    state.searchQuery = (state.searchQuery or "") .. text
    return true
end

function cargo_window.keypressed(context, key, scancode, isrepeat)
    local state = context and context.cargoUI
    if not (state and state.visible) then
        return false
    end

    if state.isSearchActive then
        if key == "backspace" then
            local current = state.searchQuery or ""
            local byteoffset = utf8.offset(current, -1)
            if byteoffset then
                state.searchQuery = string.sub(current, 1, byteoffset - 1)
            end
            return true
        elseif key == "escape" then
            clear_search_focus(context, state)
            return true
        elseif key == "return" or key == "kpenter" then
            clear_search_focus(context, state)
            return true
        end
    end

    return false
end

function cargo_window.wheelmoved(context, x, y)
    return false
end

return cargo_window
