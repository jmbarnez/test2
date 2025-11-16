local theme = require("src.ui.theme")
local geometry = require("src.util.geometry")
local Items = require("src.items.registry")
local ShipCargo = require("src.ships.cargo")
local PlayerManager = require("src.player.manager")
local CargoRendering = require("src.ui.windows.cargo.rendering")
local CargoData = require("src.ui.windows.cargo.data")
local loader = require("src.blueprints.loader")

---@diagnostic disable-next-line: undefined-global
local love = love

local station_shop = {}

local SCROLLBAR_WIDTH = 10

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color
local point_in_rect = geometry.point_in_rect

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

    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
    love.graphics.setFont(fonts.body_bold or fonts.title or default_font)
    love.graphics.printf("Station Shop", inner_x, inner_y, inner_width, "left")

    local header_height = (fonts.body_bold or fonts.title or default_font):getHeight()
    local cursor_y = inner_y + header_height + (theme_spacing.small or math.floor(padding * 0.5))

    local player, cargoComponent = get_player_and_cargo(context)
    if not player or not cargoComponent then
        love.graphics.setFont(fonts.body or default_font)
        set_color(window_colors.muted or { 0.7, 0.75, 0.8, 1 })
        love.graphics.printf("No player ship or cargo available.", inner_x, cursor_y, inner_width, "left")
        return
    end

    local available_height = math.max(0, inner_height - (cursor_y - content.y))
    if available_height <= 0 then
        return
    end

    local grid_top = cursor_y
    local grid_height = available_height

    local slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight, labelHeight =
        CargoRendering.calculateGridLayout(inner_width, grid_height, fonts)

    local slotPadding = theme_spacing.slot_padding
    local gridStartX = inner_x
    local gridStartY = grid_top
    
    -- Extra vertical spacing to account for controls (quantity + buttons = ~52px total)
    local rowSpacing = 60

    local shopItems = ensure_shop_items(state)
    
    -- Calculate total content height
    local totalRows = math.ceil(#shopItems / slotsPerRow)
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

    for index = 1, #shopItems do
        local item = shopItems[index]
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
