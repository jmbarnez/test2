local theme = require("src.ui.theme")
local geometry = require("src.util.geometry")
local Items = require("src.items.registry")
local ShipCargo = require("src.ships.cargo")
local PlayerManager = require("src.player.manager")
local CargoRendering = require("src.ui.windows.cargo.rendering")
local CargoData = require("src.ui.windows.cargo.data")
local loader = require("src.blueprints.loader")
local utf8 = require("utf8")
local CargoTooltip = require("src.ui.windows.cargo.tooltip")

---@diagnostic disable-next-line: undefined-global
local love = love

local station_shop = {}

local SCROLLBAR_WIDTH = 10

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color
local point_in_rect = geometry.point_in_rect

local SORT_MODES = {
    name = {
        id = "name",
        label = "Name A-Z",
        next = "price_asc",
    },
    price_asc = {
        id = "price_asc",
        label = "Price ↑",
        next = "price_desc",
    },
    price_desc = {
        id = "price_desc",
        label = "Price ↓",
        next = "name",
    },
}

local function normalize_category_id(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value:lower()
end

local function format_category_label(id)
    if not id or id == "" then
        return "Other"
    end
    local label = tostring(id)
    label = label:gsub("[:_]+", " ")
    label = label:gsub("%s+", " ")
    label = label:gsub("(%a)(%w*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return label
end

local function resolve_item_definition(item)
    if not item then
        return nil
    end
    return Items.get(item.id)
end

local function resolve_item_value(item, definition)
    if item and item.value ~= nil then
        return item.value
    end
    if definition and definition.value ~= nil then
        return definition.value
    end
    return 0
end

local function resolve_item_category(item, definition)
    if not item then
        return "other"
    end
    local category = item.blueprintCategory
        or (definition and definition.blueprintCategory)
        or item.type
        or (definition and definition.type)
        or "other"
    return normalize_category_id(category) or "other"
end

local function ensure_category_options(state, shopItems)
    local seen = {}
    local options = {
        { id = "all", label = "All Items" },
    }

    for i = 1, #shopItems do
        local item = shopItems[i]
        local definition = resolve_item_definition(item)
        local categoryId = resolve_item_category(item, definition)
        if categoryId ~= "all" and not seen[categoryId] then
            seen[categoryId] = true
            options[#options + 1] = {
                id = categoryId,
                label = format_category_label(categoryId),
            }
        end
    end

    table.sort(options, function(a, b)
        if a.id == "all" then
            return true
        end
        if b.id == "all" then
            return false
        end
        return a.label < b.label
    end)

    state.shopCategory = state.shopCategory or "all"
    local validSelected = state.shopCategory == "all"
    if not validSelected then
        for i = 1, #options do
            if options[i].id == state.shopCategory then
                validSelected = true
                break
            end
        end
    end
    if not validSelected then
        state.shopCategory = "all"
    end

    return options
end

local function matches_search(item, definition, lowerQuery)
    if not lowerQuery or lowerQuery == "" then
        return true
    end

    local name = (item and item.name) or (definition and definition.name) or ""
    if name:lower():find(lowerQuery, 1, true) then
        return true
    end

    local description = definition and definition.description
    if type(description) == "string" and description:lower():find(lowerQuery, 1, true) then
        return true
    end

    local id = item and item.id
    if type(id) == "string" and id:lower():find(lowerQuery, 1, true) then
        return true
    end

    return false
end

local function matches_category(item, definition, selectedCategory)
    if not selectedCategory or selectedCategory == "all" then
        return true
    end
    local categoryId = resolve_item_category(item, definition)
    return categoryId == selectedCategory
end

local function filter_shop_items(shopItems, state)
    local filtered = {}
    local lowerQuery = state.shopSearchQuery and state.shopSearchQuery:lower()
    local selectedCategory = state.shopCategory or "all"

    for i = 1, #shopItems do
        local item = shopItems[i]
        local definition = resolve_item_definition(item)
        if matches_category(item, definition, selectedCategory) and matches_search(item, definition, lowerQuery) then
            filtered[#filtered + 1] = item
        end
    end

    return filtered
end

local function sort_shop_items(items, sortMode)
    local info = SORT_MODES[sortMode] or SORT_MODES.name
    if info.id == "name" then
        table.sort(items, function(a, b)
            local nameA = tostring((a and a.name) or ""):lower()
            local nameB = tostring((b and b.name) or ""):lower()
            if nameA == nameB then
                return tostring(a and a.id or "") < tostring(b and b.id or "")
            end
            return nameA < nameB
        end)
    elseif info.id == "price_asc" then
        table.sort(items, function(a, b)
            local defA = resolve_item_definition(a)
            local defB = resolve_item_definition(b)
            local valueA = resolve_item_value(a, defA)
            local valueB = resolve_item_value(b, defB)
            if valueA == valueB then
                local nameA = tostring((a and a.name) or "")
                local nameB = tostring((b and b.name) or "")
                return nameA < nameB
            end
            return valueA < valueB
        end)
    elseif info.id == "price_desc" then
        table.sort(items, function(a, b)
            local defA = resolve_item_definition(a)
            local defB = resolve_item_definition(b)
            local valueA = resolve_item_value(a, defA)
            local valueB = resolve_item_value(b, defB)
            if valueA == valueB then
                local nameA = tostring((a and a.name) or "")
                local nameB = tostring((b and b.name) or "")
                return nameA < nameB
            end
            return valueA > valueB
        end)
    end
end

local function ensure_shop_items(state)
    if state._shopItems then
        return state._shopItems
    end

    -- Pre-register module blueprints for the shop
    local modules_to_stock = {
        "ability_dash",
        "ability_afterburner",
        "shield_t1",
    }
    for _, moduleId in ipairs(modules_to_stock) do
        local ok, blueprint = pcall(loader.load, "modules", moduleId)
        if ok and blueprint then
            Items.registerModuleBlueprint(blueprint)
        end
    end

    local items = {}
    for id, definition in Items.iterateDefinitions() do
        if type(definition) == "table" and definition.id and definition.value ~= nil then
            local instance = Items.instantiate(definition.id)
            if instance then
                items[#items + 1] = instance
            end
        end
    end

    state._shopItems = items
    return items
end

local function clear_search_focus(context, state)
    if not state.shopSearchActive then
        return
    end
    state.shopSearchActive = false
    local uiInput = context and context.uiInput
    if uiInput then
        uiInput.keyboardCaptured = false
    end
end

local function draw_controls(context, state, fonts, inner_x, cursor_y, inner_width, mouse_x, mouse_y, just_pressed)
    local uiInput = context and context.uiInput
    state.shopSearchQuery = state.shopSearchQuery or ""
    state.shopSortMode = state.shopSortMode or "name"
    state.shopCategory = state.shopCategory or "all"

    local searchHeight = (fonts.body and fonts.body:getHeight() or 16) + 12
    local spacingX = theme_spacing.small or 8
    local sortInfo = SORT_MODES[state.shopSortMode] or SORT_MODES.name
    local sortLabel = "Sort: " .. sortInfo.label

    local fontForWidth = fonts.body or love.graphics.getFont()
    local sortTextWidth = fontForWidth:getWidth(sortLabel) + 24
    local minSortWidth = 110
    local buttonWidth = math.max(minSortWidth, math.min(sortTextWidth, inner_width))
    local searchWidth = inner_width - buttonWidth - spacingX

    if searchWidth < 120 then
        buttonWidth = math.min(buttonWidth, inner_width)
        searchWidth = math.max(0, inner_width - buttonWidth - spacingX)
        if searchWidth == 0 then
            spacingX = 0
        end
    end

    local searchRect = {
        x = inner_x,
        y = cursor_y,
        width = searchWidth,
        height = searchHeight,
    }

    local sortRect = {
        x = searchRect.x + searchRect.width + spacingX,
        y = cursor_y,
        width = buttonWidth,
        height = searchHeight,
    }

    love.graphics.setFont(fonts.body or love.graphics.getFont())

    local searchHovered = searchRect.width > 0 and searchRect.height > 0 and point_in_rect(mouse_x, mouse_y, searchRect)
    local sortHovered = point_in_rect(mouse_x, mouse_y, sortRect)
    local categoryClicked = false

    if just_pressed then
        if searchHovered and searchRect.width > 0 then
            state.shopSearchActive = true
            if uiInput then
                uiInput.keyboardCaptured = true
            end
        elseif sortHovered then
            local nextMode = sortInfo.next or "name"
            if nextMode ~= state.shopSortMode then
                state.shopSortMode = nextMode
                state.scroll = 0
            end
            state.shopSearchActive = false
            if uiInput then
                uiInput.keyboardCaptured = false
            end
        end
    end

    if searchRect.width > 0 then
        set_color(window_colors.input_background or { 0.06, 0.07, 0.1, 1 })
        love.graphics.rectangle("fill", searchRect.x, searchRect.y, searchRect.width, searchRect.height, 4, 4)

        set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", searchRect.x + 0.5, searchRect.y + 0.5, searchRect.width - 1, searchRect.height - 1, 4, 4)

        local queryText = state.shopSearchQuery or ""
        local placeholder = "Search shop"

        if queryText == "" and not state.shopSearchActive then
            set_color(window_colors.muted or { 0.5, 0.5, 0.55, 1 })
            love.graphics.print(placeholder, searchRect.x + 8, searchRect.y + (searchRect.height - (fonts.body and fonts.body:getHeight() or 16)) * 0.5)
        else
            set_color(window_colors.text or { 0.85, 0.85, 0.9, 1 })
            love.graphics.print(queryText, searchRect.x + 8, searchRect.y + (searchRect.height - (fonts.body and fonts.body:getHeight() or 16)) * 0.5)

            if state.shopSearchActive then
                local textWidth = (fonts.body or love.graphics.getFont()):getWidth(queryText)
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
    end

    set_color(sortHovered and (window_colors.button_hover or window_colors.row_hover or { 0.12, 0.16, 0.22, 1 })
        or window_colors.button or { 0.12, 0.16, 0.22, 1 })
    love.graphics.rectangle("fill", sortRect.x, sortRect.y, sortRect.width, sortRect.height, 4, 4)

    set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sortRect.x + 0.5, sortRect.y + 0.5, sortRect.width - 1, sortRect.height - 1, 4, 4)

    set_color(window_colors.text or { 0.85, 0.85, 0.9, 1 })
    love.graphics.printf(sortLabel, sortRect.x, sortRect.y + (sortRect.height - (fonts.body and fonts.body:getHeight() or 16)) * 0.5, sortRect.width, "center")

    if sortHovered then
        love.graphics.setLineWidth(2)
        set_color(window_colors.accent or { 0.2, 0.5, 0.9, 1 })
        love.graphics.rectangle("line", sortRect.x + 0.5, sortRect.y + 0.5, sortRect.width - 1, sortRect.height - 1, 4, 4)
    end

    local categories = ensure_category_options(state, ensure_shop_items(state))
    local catFont = fonts.small or fonts.body or love.graphics.getFont()
    love.graphics.setFont(catFont)

    local catSpacingX = theme_spacing.small or 8
    local catSpacingY = theme_spacing.small or 8
    local catHeight = catFont:getHeight() + 12
    local rowStartX = inner_x
    local rowY = cursor_y + searchHeight + catSpacingY
    local maxX = inner_x + inner_width
    local maxBottom = rowY

    for i = 1, #categories do
        local category = categories[i]
        local textWidth = catFont:getWidth(category.label)
        local catWidth = math.min(textWidth + 20, inner_width)
        if rowStartX + catWidth > maxX then
            rowStartX = inner_x
            rowY = maxBottom + catSpacingY
        end

        local rect = {
            x = rowStartX,
            y = rowY,
            width = catWidth,
            height = catHeight,
        }

        local isActive = state.shopCategory == category.id
        local isHovered = point_in_rect(mouse_x, mouse_y, rect)

        local fill
        if isActive then
            fill = window_colors.accent_secondary or window_colors.accent or { 0.26, 0.42, 0.78, 1 }
        elseif isHovered then
            fill = window_colors.row_hover or { 0.18, 0.22, 0.3, 1 }
        else
            fill = window_colors.button or window_colors.background or { 0.08, 0.1, 0.14, 1 }
        end

        set_color(fill)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 4, 4)

        set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1, 4, 4)

        set_color(window_colors.title_text or window_colors.text or { 0.85, 0.9, 1.0, 1 })
        love.graphics.print(category.label, rect.x + (rect.width - textWidth) * 0.5, rect.y + (rect.height - catFont:getHeight()) * 0.5)

        if just_pressed and isHovered then
            categoryClicked = true
            if state.shopCategory ~= category.id then
                state.shopCategory = category.id
                state.scroll = 0
            end
            state.shopSearchActive = false
            if uiInput then
                uiInput.keyboardCaptured = false
            end
        end

        rowStartX = rect.x + rect.width + catSpacingX
        maxBottom = math.max(maxBottom, rect.y + rect.height)
    end

    if just_pressed and not searchHovered and not sortHovered and not categoryClicked then
        clear_search_focus(context, state)
    end

    local totalHeight = searchHeight
    if #categories > 0 then
        totalHeight = math.max(totalHeight, maxBottom - cursor_y)
    end

    return totalHeight
end

local function draw_button(rect, label, fonts, hovered, disabled, kind)
    if not rect then
        return
    end

    local fill = window_colors.button or { 0.12, 0.16, 0.22, 1 }
    local border = window_colors.border or { 0.08, 0.08, 0.12, 0.9 }
    local text_color = window_colors.text or { 0.85, 0.9, 1.0, 1 }

    if kind == "buy" then
        fill = window_colors.success or { 0.18, 0.5, 0.24, 1 }
        border = window_colors.success_border or border
    elseif kind == "sell" then
        fill = window_colors.danger or { 0.62, 0.22, 0.22, 1 }
        border = window_colors.danger_border or border
    end

    if disabled then
        fill = window_colors.muted or { 0.35, 0.4, 0.48, 0.7 }
        text_color = window_colors.muted or text_color
    elseif hovered then
        fill = window_colors.button_hover or window_colors.row_hover or fill
    end

    set_color(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 4, 4)

    set_color(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1, 4, 4)

    local font = fonts.small or fonts.body
    love.graphics.setFont(font)
    set_color(text_color)
    love.graphics.printf(label, rect.x, rect.y + (rect.height - font:getHeight()) * 0.5, rect.width, "center")
end

local function draw_quantity_field(rect, quantity, fonts, hovered)
    local fill = window_colors.input_background or { 0.06, 0.07, 0.1, 1 }
    local border = window_colors.border or { 0.08, 0.08, 0.12, 0.9 }
    if hovered then
        border = window_colors.accent or border
    end

    set_color(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 3, 3)

    set_color(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1, 3, 3)

    local font = fonts.small or fonts.body
    love.graphics.setFont(font)
    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
    local text = tostring(quantity or 1)
    love.graphics.printf(text, rect.x, rect.y + (rect.height - font:getHeight()) * 0.5, rect.width, "center")
end

local function clamp_quantity(value)
    value = tonumber(value) or 1
    if value < 1 then
        value = 1
    end
    return math.floor(value + 0.5)
end

local function get_player_and_cargo(context)
    local player = PlayerManager.resolveLocalPlayer(context)
    if not player then
        return nil, nil
    end
    return player, player.cargo
end

local function get_player_item_quantity(cargoComponent, itemId)
    if not (cargoComponent and itemId) then
        return 0
    end

    local items = cargoComponent.items or {}
    for i = 1, #items do
        local item = items[i]
        if item and item.id == itemId then
            return tonumber(item.quantity) or 0
        end
    end
    return 0
end

---@param context table
---@param params table
function station_shop.draw(context, params)
    local fonts = params.fonts
    local default_font = params.default_font or love.graphics.getFont()
    local content = params.content
    local state = params.state or (context and context.stationUI) or {}
    local mouse_x = params.mouse_x or 0
    local mouse_y = params.mouse_y or 0
    local mouse_down = params.mouse_down == true
    local just_pressed = params.just_pressed == true

    state.shopQuantities = state.shopQuantities or {}

    local padding = theme_spacing.medium or 16
    local scrollbarX = content.x + content.width - SCROLLBAR_WIDTH
    local inner_x = content.x + padding
    local inner_y = content.y + padding
    local inner_width = math.max(0, scrollbarX - inner_x - padding)
    local inner_height = math.max(0, content.height - padding * 2)
    local inner_bottom = inner_y + inner_height

    local cursor_y = inner_y + (theme_spacing.xsmall or math.max(4, math.floor((theme_spacing.small or 8) * 0.35)))

    local player, cargoComponent = get_player_and_cargo(context)
    if not player or not cargoComponent then
        love.graphics.setFont(fonts.body or default_font)
        set_color(window_colors.muted or { 0.7, 0.75, 0.8, 1 })
        love.graphics.printf("No player ship or cargo available.", inner_x, cursor_y, inner_width, "left")
        return
    end

    local shopItems = ensure_shop_items(state)
    local displayItems = filter_shop_items(shopItems, state)
    sort_shop_items(displayItems, state.shopSortMode)

    local controlsHeight = draw_controls(context, state, fonts, inner_x, cursor_y, inner_width, mouse_x, mouse_y, just_pressed)
    cursor_y = cursor_y + controlsHeight + (theme_spacing.small or 8)

    local grid_top = cursor_y
    local grid_height = math.max(0, inner_bottom - grid_top)
    if grid_height <= 0 then
        return
    end

    local slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight, labelHeight =
        CargoRendering.calculateGridLayout(inner_width, grid_height, fonts)

    local slotPadding = theme_spacing.slot_padding
    local gridStartX = inner_x
    local gridStartY = grid_top
    
    -- Extra vertical spacing to account for controls (quantity + buttons = ~52px total)
    local rowSpacing = 60

    if #displayItems == 0 then
        love.graphics.setFont(fonts.body or default_font)
        set_color(window_colors.muted or { 0.6, 0.65, 0.7, 1 })
        love.graphics.printf("No items match your filters.", inner_x, cursor_y + (grid_height * 0.5) - (fonts.body and fonts.body:getHeight() or default_font:getHeight()), inner_width, "center")

        love.graphics.setScissor()

        local bottomBar = params.bottom_bar
        if bottomBar then
            local currencyValue = PlayerManager.getCurrency(context)
            if currencyValue ~= nil then
                local currencyText = CargoData.formatCurrency(currencyValue)
                CargoRendering.drawCurrency(bottomBar, 0, currencyText, fonts)
            end
        end
        return
    end

    -- Calculate total content height
    local totalRows = math.ceil(#displayItems / slotsPerRow)
    local contentHeight = totalRows * (slotWithLabelHeight + slotPadding + rowSpacing)
    
    -- Initialize scroll state
    state.scroll = tonumber(state.scroll) or 0
    local maxScroll = math.max(0, contentHeight - grid_height)
    state.scroll = math.max(0, math.min(maxScroll, state.scroll))
    
    -- Scissor clip for scrollable area
    local viewportRect = {
        x = inner_x,
        y = grid_top,
        w = inner_width,
        h = grid_height,
    }
    love.graphics.setScissor(viewportRect.x, viewportRect.y, viewportRect.w, viewportRect.h)

    for index = 1, #displayItems do
        local item = displayItems[index]
        local slotIndex = index - 1
        local row = math.floor(slotIndex / slotsPerRow)
        local col = slotIndex % slotsPerRow
        local slotX = gridStartX + col * (slotSize + slotPadding)
        local slotY = gridStartY + row * (slotWithLabelHeight + slotPadding + rowSpacing) - state.scroll

        -- Skip items outside viewport
        if slotY + slotWithLabelHeight + rowSpacing < grid_top then
            goto continue
        end
        if slotY > grid_top + grid_height then
            break
        end

        local slotRect = {
            x = slotX,
            y = slotY,
            width = slotSize,
            height = slotSize,
        }

        local isHovered = point_in_rect(mouse_x, mouse_y, slotRect)
        CargoRendering.drawSlotBackground(slotX, slotY, slotSize, isHovered, false)
        CargoRendering.drawItemInSlot(item, slotX, slotY, slotSize, labelHeight, fonts)

        if isHovered and item then
            CargoTooltip.create(item)
        end

        local controlsY = slotY + slotSize + 4 + labelHeight
        local controlsHeight = 20
        local controlsSpacing = 4
        
        -- Quantity field on its own line, centered
        local quantityWidth = math.min(slotSize - 8, 60)
        local qtyRect = {
            x = slotX + (slotSize - quantityWidth) * 0.5,
            y = controlsY,
            width = quantityWidth,
            height = controlsHeight,
        }

        -- Buy and Sell buttons side by side below quantity
        local buttonsY = controlsY + controlsHeight + controlsSpacing
        local buttonGap = 6
        local buttonWidth = math.floor((slotSize - buttonGap) * 0.5)
        
        local buyRect = {
            x = slotX,
            y = buttonsY,
            width = buttonWidth,
            height = controlsHeight,
        }

        local sellRect = {
            x = slotX + buttonWidth + buttonGap,
            y = buttonsY,
            width = buttonWidth,
            height = controlsHeight,
        }

        local itemId = item.id
        local currentQty = clamp_quantity(state.shopQuantities[itemId] or 1)
        state.shopQuantities[itemId] = currentQty

        local qtyHovered = point_in_rect(mouse_x, mouse_y, qtyRect)
        draw_quantity_field(qtyRect, currentQty, fonts, qtyHovered)

        local definition = Items.get(itemId)
        local unitValue = (definition and definition.value) or 0
        local currencyValue = PlayerManager.getCurrency(context) or 0
        local totalCost = unitValue * currentQty

        local buyDisabled = unitValue <= 0 or currencyValue < totalCost
        local buyHovered = (not buyDisabled) and point_in_rect(mouse_x, mouse_y, buyRect)
        local ownedQuantity = get_player_item_quantity(cargoComponent, itemId)
        local sellDisabled = unitValue <= 0 or ownedQuantity <= 0
        local sellHovered = not sellDisabled and point_in_rect(mouse_x, mouse_y, sellRect)

        draw_button(buyRect, "Buy", fonts, buyHovered, buyDisabled, "buy")
        draw_button(sellRect, "Sell", fonts, sellHovered, sellDisabled, "sell")

        if just_pressed then
            if buyHovered and not buyDisabled then
                local instance = Items.instantiate(itemId)
                local added = instance and ShipCargo.add_item_instance(cargoComponent, instance, currentQty)
                if added then
                    PlayerManager.adjustCurrency(context, -totalCost)
                end
            elseif sellHovered and not sellDisabled then
                local sellQty = math.min(ownedQuantity, currentQty)
                if sellQty > 0 then
                    local removed = ShipCargo.try_remove_item(cargoComponent, itemId, sellQty)
                    if removed then
                        local gain = unitValue * sellQty
                        if gain ~= 0 then
                            PlayerManager.adjustCurrency(context, gain)
                        end
                    end
                end
            elseif qtyHovered then
                if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                    state.shopQuantities[itemId] = clamp_quantity(currentQty + 5)
                elseif love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                    state.shopQuantities[itemId] = clamp_quantity(currentQty + 10)
                else
                    state.shopQuantities[itemId] = clamp_quantity(currentQty + 1)
                end
            end
        end
        
        ::continue::
    end
    
    love.graphics.setScissor()
    
    -- Draw scrollbar if needed
    if maxScroll > 0 then
        local scrollAreaY = grid_top
        local scrollAreaHeight = grid_height
        local thumbHeight = math.max(18, scrollAreaHeight * (grid_height / contentHeight))
        local thumbTravel = scrollAreaHeight - thumbHeight
        local thumbY = scrollAreaY + (thumbTravel > 0 and (state.scroll / maxScroll) * thumbTravel or 0)
        
        -- Scrollbar track
        set_color(window_colors.background or { 0.08, 0.1, 0.14, 0.8 })
        love.graphics.rectangle("fill", scrollbarX, scrollAreaY, SCROLLBAR_WIDTH, scrollAreaHeight)
        
        -- Scrollbar thumb
        local thumbHovered = point_in_rect(mouse_x, mouse_y, {
            x = scrollbarX,
            y = thumbY,
            width = SCROLLBAR_WIDTH,
            height = thumbHeight,
        })
        
        local thumbColor = thumbHovered 
            and (window_colors.accent or { 0.3, 0.5, 0.8, 0.9 })
            or (window_colors.border or { 0.2, 0.25, 0.3, 0.8 })
        set_color(thumbColor)
        love.graphics.rectangle("fill", scrollbarX, thumbY, SCROLLBAR_WIDTH, thumbHeight, 2, 2)
    end

    local bottomBar = params.bottom_bar
    if bottomBar then
        local currencyValue = PlayerManager.getCurrency(context)
        if currencyValue ~= nil then
            local currencyText = CargoData.formatCurrency(currencyValue)
            CargoRendering.drawCurrency(bottomBar, 0, currencyText, fonts)
        end
    end
end

function station_shop.textinput(context, text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    local state = context and context.stationUI
    if not (state and state.visible and state.shopSearchActive) then
        return false
    end

    state.shopSearchQuery = (state.shopSearchQuery or "") .. text
    state.scroll = 0
    return true
end

function station_shop.keypressed(context, key)
    local state = context and context.stationUI
    if not state or not state.visible then
        return false
    end

    if key == "escape" then
        local wasActive = state.shopSearchActive
        clear_search_focus(context, state)
        return wasActive
    end

    if not state.shopSearchActive then
        return false
    end

    if key == "backspace" then
        local query = state.shopSearchQuery or ""
        local byteoffset = utf8.offset(query, -1)
        if byteoffset then
            state.shopSearchQuery = string.sub(query, 1, byteoffset - 1)
        end
        return true
    end

    return false
end

--- Handles mouse wheel scrolling
---@param context table The game context
---@param x number X scroll amount
---@param y number Y scroll amount
---@return boolean Whether the scroll was handled
function station_shop.wheelmoved(context, x, y)
    local state = context and context.stationUI
    if not (state and state.visible) then
        return false
    end
    
    -- Check if we have scrollable content
    local scroll = tonumber(state.scroll) or 0
    local maxScroll = 0
    
    -- Simple scroll step calculation
    local step = 60
    local nextScroll = math.max(0, scroll - y * step)
    
    -- If scroll changed, update it
    if math.abs(nextScroll - scroll) > 0.1 then
        state.scroll = nextScroll
        return true
    end
    
    return false
end

return station_shop
