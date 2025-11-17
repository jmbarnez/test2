-- Cargo Window: Coordinator for inventory management UI
-- Delegates to specialized modules for data, tooltips, and rendering
-- Handles window frame, search, sorting, and user interaction

local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local PlayerManager = require("src.player.manager")
local Modules = require("src.ships.modules")
local ShipCargo = require("src.ships.cargo")
local utf8 = require("utf8")

-- Specialized cargo modules
local CargoData = require("src.ui.windows.cargo.data")
local CargoTooltip = require("src.ui.windows.cargo.tooltip")
local CargoRendering = require("src.ui.windows.cargo.rendering")

---@diagnostic disable-next-line: undefined-global
local love = love

local cargo_window = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local window_metrics = theme.window
local set_color = theme.utils.set_color

local function is_module_item(item)
    if type(item) ~= "table" then
        return false
    end

    if item.type == "module" then
        return true
    end

    if type(item.id) == "string" and item.id:match("^module:") then
        return true
    end

    return false
end

local function can_drop_module_item(item, slot)
    if not (is_module_item(item) and type(slot) == "table") then
        return false
    end

    local slotType = slot.type
    local itemSlot = item.slot or slotType

    if slotType and itemSlot and slotType ~= itemSlot then
        return false
    end

    return true
end

--- Clears search input focus
---@param context table The game context
---@param state table The cargo UI state
local function clear_search_focus(context, state)
    if context and context.uiInput then
        context.uiInput.keyboardCaptured = false
    end
    state.isSearchActive = false
end

--- Draws the module side panel showing available slots
---@param moduleSlots table Module slot array
---@param panel table Panel rectangle {x, y, width, height}
---@param fonts table Font table from theme
---@param mouse_x number Mouse X position
---@param mouse_y number Mouse Y position
---@param dragItem table|nil Item currently being dragged
---@return table|nil result Table containing hover information and slot rects
local function draw_module_panel(moduleSlots, panel, fonts, mouse_x, mouse_y, dragItem)
    if not panel or panel.width <= 0 or panel.height <= 0 then
        return nil
    end

    set_color(window_colors.panel_background or { 0.05, 0.06, 0.09, 0.95 })
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height, 4, 4)

    set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panel.x + 0.5, panel.y + 0.5, panel.width - 1, panel.height - 1, 4, 4)

    local headerFont = fonts.small_caps or fonts.small_bold or fonts.small or fonts.body
    love.graphics.setFont(headerFont)
    set_color(window_colors.title_text or window_colors.text or { 0.85, 0.9, 1.0, 1 })
    local headerText = "MODULE SLOTS"
    local headerHeight = headerFont:getHeight()
    love.graphics.print(headerText, panel.x + 12, panel.y + 10)

    local dividerY = panel.y + 12 + headerHeight
    set_color(window_colors.border or { 0.1, 0.12, 0.16, 0.8 })
    love.graphics.rectangle("fill", panel.x + 10, dividerY, panel.width - 20, 1)

    local slotStartY = dividerY + 12
    local slotHeight = 78
    local slotSpacing = 10
    local iconSize = 44
    local iconX = panel.x + 18
    local textStartX = iconX + iconSize + 12
    local maxTextWidth = panel.x + panel.width - textStartX - 12

    local hoveredItem
    local hoveredSlot
    local hoveredSlotIndex
    local hoveredSlotNumber
    local slotRects = {}
    love.graphics.setFont(fonts.small or fonts.body)

    if #moduleSlots == 0 then
        set_color(window_colors.muted or { 0.55, 0.57, 0.62, 1 })
        love.graphics.printf("No module slots", panel.x, slotStartY, panel.width, "center")
        return {
            hoveredItem = nil,
            hoveredSlot = nil,
            hoveredSlotIndex = nil,
            slotRects = slotRects,
        }
    end

    for index = 1, #moduleSlots do
        local slot = moduleSlots[index]
        local slotY = slotStartY + (index - 1) * (slotHeight + slotSpacing)
        if slotY > panel.y + panel.height - slotHeight - 8 then
            break
        end

        local rectX = panel.x + 12
        local rectWidth = panel.width - 24
        local rectHeight = slotHeight
        slotRects[index] = {
            x = rectX,
            y = slotY,
            width = rectWidth,
            height = rectHeight,
        }

        local isHovered = mouse_x >= rectX and mouse_x <= rectX + rectWidth
            and mouse_y >= slotY and mouse_y <= slotY + slotHeight

        local slotBackground = window_colors.slot_background or { 0.07, 0.09, 0.13, 0.9 }
        local slotBorder = window_colors.slot_border or window_colors.border or { 0.1, 0.12, 0.16, 0.8 }

        local canDrop = dragItem and can_drop_module_item(dragItem, slot)
        if isHovered then
            hoveredSlot = slot
            hoveredSlotIndex = index
            if dragItem then
                if canDrop then
                    slotBackground = window_colors.slot_drop_valid or window_colors.row_hover or { 0.16, 0.32, 0.48, 1 }
                    slotBorder = window_colors.accent or { 0.2, 0.5, 0.9, 1 }
                else
                    slotBackground = window_colors.slot_drop_invalid or { 0.3, 0.12, 0.14, 1 }
                    slotBorder = window_colors.danger or { 0.85, 0.32, 0.32, 1 }
                end
            else
                slotBackground = window_colors.row_hover or { 0.12, 0.16, 0.22, 1 }
                slotBorder = window_colors.slot_border or window_colors.border or { 0.1, 0.12, 0.16, 0.8 }
            end
        elseif dragItem and canDrop then
            slotBorder = window_colors.accent or { 0.2, 0.5, 0.9, 1 }
        end

        set_color(slotBackground)
        love.graphics.rectangle("fill", rectX, slotY, rectWidth, rectHeight, 4, 4)

        set_color(slotBorder)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rectX + 0.5, slotY + 0.5, rectWidth - 1, rectHeight - 1, 4, 4)

        local item = slot and slot.item or nil
        if item and item.icon then
            CargoRendering.drawItemIcon(item.icon, iconX, slotY + 16, iconSize)
        else
            set_color(window_colors.muted or { 0.4, 0.45, 0.5, 1 })
            love.graphics.setLineWidth(1.25)
            love.graphics.circle("line", iconX + iconSize * 0.5, slotY + 16 + iconSize * 0.5, iconSize * 0.32)
        end

        local slotFont = fonts.small_bold or fonts.small or fonts.body
        love.graphics.setFont(slotFont)
        set_color(window_colors.text or { 0.85, 0.85, 0.9, 1 })
        local slotName = (slot and slot.name) or string.format("Slot %d", index)
        love.graphics.print(slotName, textStartX, slotY + 12)

        local typeFont = fonts.tiny or fonts.small or fonts.body
        love.graphics.setFont(typeFont)
        set_color(window_colors.muted or { 0.55, 0.57, 0.62, 1 })
        local slotType = slot and slot.type or "--"
        love.graphics.print(string.upper(slotType), textStartX, slotY + 12 + slotFont:getHeight() + 4)

        love.graphics.setFont(fonts.small or fonts.body)
        if item then
            set_color(window_colors.text or { 0.9, 0.92, 0.96, 1 })
            love.graphics.printf(item.name or "Installed Module", textStartX, slotY + 38, maxTextWidth, "left")
            if isHovered then
                hoveredItem = item
            end
        else
            set_color(window_colors.muted or { 0.55, 0.57, 0.62, 1 })
            love.graphics.printf("Empty", textStartX, slotY + 38, maxTextWidth, "left")
        end
    end

    return {
        hoveredItem = hoveredItem,
        hoveredSlot = hoveredSlot,
        hoveredSlotIndex = hoveredSlotIndex,
        slotRects = slotRects,
    }
end

--- Gets window dimensions
---@return table Window dimensions {x, y, width, height}
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

--- Draws the search input and sort button
---@param content table The content area frame
---@param state table The cargo UI state
---@param fonts table Font table from theme
---@param mouse_x number Mouse X position
---@param mouse_y number Mouse Y position
---@param just_pressed boolean Whether mouse was just pressed
---@param uiInput table|nil UI input state
---@return table searchRect
---@return table sortRect
---@return boolean searchHovered
---@return boolean sortHovered
local function draw_search_and_sort(content, state, fonts, mouse_x, mouse_y, just_pressed, uiInput)
    local searchHeight = fonts.body:getHeight() + 12
    local searchSpacing = 6
    local sortMode = state.sortMode
    local sortInfo = CargoData.SORT_MODES[sortMode] or CargoData.SORT_MODES.name
    local sortLabel = "Sort: " .. sortInfo.label
    local buttonWidth = math.max(80, math.min(fonts.body:getWidth(sortLabel) + 24, content.width))
    local searchWidth = content.width - buttonWidth - searchSpacing
    
    if searchWidth < 0 then
        buttonWidth = content.width
        searchWidth = 0
        searchSpacing = 0
    elseif searchWidth < 80 then
        searchWidth = math.max(0, content.width - searchSpacing - 80)
        buttonWidth = content.width - searchWidth - searchSpacing
    end

    local searchRect = {
        x = content.x,
        y = content.y,
        width = searchWidth,
        height = searchHeight,
    }

    local sortRect = {
        x = searchRect.x + searchRect.width + searchSpacing,
        y = content.y,
        width = buttonWidth,
        height = searchHeight,
    }

    local searchHovered = searchRect.width > 0 and mouse_x >= searchRect.x and mouse_x <= searchRect.x + searchRect.width and
        mouse_y >= searchRect.y and mouse_y <= searchRect.y + searchRect.height

    local sortHovered = mouse_x >= sortRect.x and mouse_x <= sortRect.x + sortRect.width and
        mouse_y >= sortRect.y and mouse_y <= sortRect.y + sortRect.height

    -- Handle interaction
    if searchHovered and just_pressed then
        state.isSearchActive = true
        if uiInput then
            uiInput.keyboardCaptured = true
        end
    elseif just_pressed and not searchHovered then
        if state.isSearchActive and not sortHovered and uiInput then
            uiInput.keyboardCaptured = false
        end
        if not sortHovered then
            state.isSearchActive = false
        end
    end

    love.graphics.setFont(fonts.body)
    
    -- Draw search box
    if searchRect.width > 0 then
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
    end

    -- Draw sort button
    set_color(sortHovered and (window_colors.button_hover or window_colors.row_hover or { 0.12, 0.16, 0.22, 1 })
        or window_colors.button_background or window_colors.input_background or { 0.06, 0.07, 0.1, 1 })
    love.graphics.rectangle("fill", sortRect.x, sortRect.y, sortRect.width, sortRect.height, 4, 4)

    set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.8 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sortRect.x + 0.5, sortRect.y + 0.5, sortRect.width - 1, sortRect.height - 1, 4, 4)

    set_color(window_colors.text or { 0.85, 0.85, 0.9, 1 })
    love.graphics.printf(sortLabel, sortRect.x, sortRect.y + (sortRect.height - fonts.body:getHeight()) * 0.5, sortRect.width, "center")

    if sortHovered then
        love.graphics.setLineWidth(2)
        set_color(window_colors.accent or { 0.2, 0.5, 0.9, 1 })
        love.graphics.rectangle("line", sortRect.x + 0.5, sortRect.y + 0.5, sortRect.width - 1, sortRect.height - 1, 4, 4)
    end

    if sortHovered and just_pressed then
        state.sortMode = sortInfo.next or "name"
    end

    return searchRect, sortRect, searchHovered, sortHovered
end

--- Draws the cargo window
---@param context table The game context
function cargo_window.draw(context)
    local state = context.cargoUI
    if not state then
        state = {}
        context.cargoUI = state
    end

    state.searchQuery = state.searchQuery or ""
    state.isSearchActive = state.isSearchActive or false
    state.sortMode = state.sortMode or "name"

    local uiInput = context.uiInput

    local isVisible = state.visible == true
    local previousVisible = state._previous_visible

    -- Handle visibility changes
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

    if uiInput then
        uiInput.mouseCaptured = true
        uiInput.keyboardCaptured = true
    end

    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_mouse_down = love.mouse.isDown(1)
    local just_pressed = is_mouse_down and not state._was_mouse_down
    local just_released = (not is_mouse_down) and state._was_mouse_down

    if state.isSearchActive and uiInput then
        uiInput.keyboardCaptured = true
    end

    -- Get player and cargo data
    local player = PlayerManager.resolveLocalPlayer(context)
    if not player then
        return
    end
    
    local cargoInfo = CargoData.getCargoInfo(player)
    local moduleSlots = Modules.get_slots(player)
    local moduleSlotCount = moduleSlots and #moduleSlots or 0
    local currencyValue = CargoData.getCurrency(context, player)
    local currencyText = currencyValue ~= nil and CargoData.formatCurrency(currencyValue) or "--"
    local dragItem = state.draggedItem

    love.graphics.push("all")
    love.graphics.origin()

    local fonts = theme.get_fonts()
    local dims = get_dimensions()
    local padding = theme_spacing.window_padding
    local topBarHeight = window_metrics.top_bar_height
    local bottomBarHeight = window_metrics.bottom_bar_height

    -- Draw window frame
    local frame = window.draw_frame({
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
    })

    local window_x = state.x or dims.x
    local window_y = state.y or dims.y
    local window_width = state.width or dims.width
    local window_height = state.height or dims.height
    local mouseInsideWindow = mouse_x and mouse_y and
        mouse_x >= window_x and mouse_x <= window_x + window_width and
        mouse_y >= window_y and mouse_y <= window_y + window_height

    if uiInput and state.visible then
        if state.dragging or frame.dragging then
            uiInput.mouseCaptured = true
        elseif is_mouse_down and mouseInsideWindow then
            uiInput.mouseCaptured = true
        end
    end

    local content = frame.content

    local panelSpacing = 14
    local modulePanelWidth = 0
    local showModulePanel = moduleSlotCount > 0
    if showModulePanel then
        modulePanelWidth = math.min(240, math.max(160, content.width * 0.35))
    end
    local itemAreaWidth = content.width - modulePanelWidth - (showModulePanel and panelSpacing or 0)
    if itemAreaWidth < 160 then
        itemAreaWidth = math.max(120, itemAreaWidth)
        modulePanelWidth = showModulePanel and math.max(140, content.width - itemAreaWidth - panelSpacing) or 0
    end

    if itemAreaWidth < 0 then
        itemAreaWidth = 0
    end

    local itemArea = {
        x = content.x,
        y = content.y,
        width = itemAreaWidth,
        height = content.height,
    }

    local modulePanel
    if showModulePanel then
        modulePanel = {
            x = itemArea.x + itemArea.width + panelSpacing,
            y = content.y,
            width = modulePanelWidth,
            height = content.height,
        }
    end
    
    -- Draw search and sort controls
    local searchRect, sortRect, searchHovered, sortHovered = draw_search_and_sort(itemArea, state, fonts, mouse_x, mouse_y, just_pressed, uiInput)
    
    local searchHeight = fonts.body:getHeight() + 12
    local searchSpacing = 6
    local gridY = itemArea.y + searchHeight + searchSpacing
    local gridHeight = itemArea.height - searchHeight - searchSpacing
    if gridHeight < 0 then
        gridHeight = 0
    end

    -- Calculate grid layout
    local slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight, labelHeight =
        CargoRendering.calculateGridLayout(itemArea.width, gridHeight, fonts)

    local slotPadding = theme_spacing.slot_padding
    local gridStartY = gridY
    local gridStartX = itemArea.x

    -- Filter and sort items
    local filteredItems = CargoData.filterItems(cargoInfo.items, state.searchQuery)
    CargoData.sortItems(filteredItems, state.sortMode)

    -- Draw item slots
    local hoveredItem
    local hoveredSlotIndex
    local hoveredSlotRect
    local hoveredSlotNumber
    local cargoSlotRects = {}

    for slotNumber = 1, totalVisibleSlots do
        local slotIndex = slotNumber - 1
        local row = math.floor(slotIndex / slotsPerRow)
        local col = slotIndex % slotsPerRow
        local slotX = gridStartX + col * (slotSize + slotPadding)
        local slotY = gridStartY + row * (slotWithLabelHeight + slotPadding)

        local item = filteredItems[slotNumber]
        cargoSlotRects[slotNumber] = {
            x = slotX,
            y = slotY,
            width = slotSize,
            height = slotSize,
            item = item,
            index = slotNumber,
        }

        local isMouseOver = mouse_x >= slotX and mouse_x <= slotX + slotSize and
            mouse_y >= slotY and mouse_y <= slotY + slotSize

        if isMouseOver then
            hoveredItem = item
            hoveredSlotIndex = slotIndex
            hoveredSlotNumber = slotNumber
            hoveredSlotRect = cargoSlotRects[slotNumber]
            if not dragItem then
                CargoTooltip.create(item)
            end
        end

        local isSelected = state._hovered_slot == slotIndex
        CargoRendering.drawSlotBackground(slotX, slotY, slotSize, isMouseOver, isSelected)

        if item then
            CargoRendering.drawItemInSlot(item, slotX, slotY, slotSize, labelHeight, fonts)
        end
    end

    state._hovered_slot = hoveredSlotIndex
    state._hovered_item = hoveredItem
    state._was_mouse_down = is_mouse_down

    -- Draw module panel if available
    local modulePanelResult
    if showModulePanel and modulePanel then
        modulePanelResult = draw_module_panel(moduleSlots, modulePanel, fonts, mouse_x, mouse_y, dragItem)
        if modulePanelResult and modulePanelResult.hoveredItem and not dragItem
            and not searchHovered and not sortHovered then
            CargoTooltip.create(modulePanelResult.hoveredItem)
        end
    end

    -- Initiate dragging when clicking on a module-capable item
    local clickOverSearchOrSort = (searchHovered or sortHovered)
    if not dragItem and just_pressed and not clickOverSearchOrSort then
        if hoveredItem then
            state.draggedItem = hoveredItem
            state.dragSource = "cargo"
            state.dragIndex = hoveredSlotNumber
        elseif modulePanelResult and modulePanelResult.hoveredSlot and modulePanelResult.hoveredItem
            and is_module_item(modulePanelResult.hoveredItem) then
            state.draggedItem = modulePanelResult.hoveredItem
            state.dragSource = "module"
            state.dragIndex = modulePanelResult.hoveredSlotIndex
        end
        dragItem = state.draggedItem
    end

    -- Handle drop logic when releasing mouse button
    if dragItem and just_released then
        local handled = false

        -- Check if dropping onto hotbar
        local Hotbar = require("src.hud.hotbar")
        local hotbarSlotIndex = Hotbar.getSlotAtPosition(mouse_x, mouse_y, context, player)
        if hotbarSlotIndex and state.dragSource == "cargo" then
            handled = Hotbar.moveFromCargo(player, dragItem, hotbarSlotIndex)
        end

        if not handled and modulePanelResult and modulePanelResult.hoveredSlot and can_drop_module_item(dragItem, modulePanelResult.hoveredSlot) then
            Modules.equip(player, dragItem, modulePanelResult.hoveredSlotIndex)
            handled = true
        elseif state.dragSource == "module" then
            local insideCargoArea = mouse_x >= itemArea.x and mouse_x <= itemArea.x + itemArea.width and
                mouse_y >= itemArea.y and mouse_y <= itemArea.y + itemArea.height
            if insideCargoArea then
                Modules.unequip(player, state.dragIndex)
                handled = true
            end
        end

        if not handled and state.dragSource == "cargo" then
            local insideWindow = mouseInsideWindow
            if not insideWindow then
                local uiContext = context
                local gameState = uiContext and uiContext.state or context
                local camera = uiContext and uiContext.camera or (gameState and gameState.camera)
                local worldX, worldY = mouse_x, mouse_y
                if camera then
                    local zoom = camera.zoom or 1
                    if zoom ~= 0 then
                        worldX = mouse_x / zoom + (camera.x or 0)
                        worldY = mouse_y / zoom + (camera.y or 0)
                    else
                        worldX = camera.x or mouse_x
                        worldY = camera.y or mouse_y
                    end
                end

                local quantity = dragItem.quantity or 1
                local removed = false
                if player.cargo and player.cargo.tryRemoveItem then
                    removed = player.cargo:tryRemoveItem(dragItem.id or dragItem.name, quantity)
                elseif ShipCargo.try_remove_item then
                    removed = ShipCargo.try_remove_item(player.cargo, dragItem.id or dragItem.name, quantity)
                end

                if removed and gameState and gameState.world then
                    require("src.states.gameplay.entities").spawnLootPickup(gameState, {
                        item = dragItem,
                        quantity = quantity,
                        position = { x = worldX, y = worldY },
                    })
                    handled = true
                end
            end
        end

        if handled then
            Modules.sync_from_cargo(player)
            if player.cargo then
                player.cargo.dirty = true
            end
        end

        state.draggedItem = nil
        state.dragSource = nil
        state.dragIndex = nil
        dragItem = nil
    end

    -- Draw bottom bar (capacity and currency)
    local bottomBar = frame.bottom_bar
    if bottomBar then
        local barWidth = CargoRendering.drawCapacityBar(bottomBar, cargoInfo.percentFull, cargoInfo.capacity, fonts)
        if barWidth then
            CargoRendering.drawCurrency(bottomBar, barWidth, currencyText, fonts)
        end
    end

    -- Draw dragged item overlay
    if dragItem then
        local iconSize = 44
        local overlayX = mouse_x + 18
        local overlayY = mouse_y + 22

        love.graphics.push("all")
        set_color(window_colors.drag_shadow or { 0, 0, 0, 0.35 })
        love.graphics.rectangle("fill", overlayX - 6, overlayY - 6, iconSize + 12, iconSize + 12, 4, 4)

        set_color(window_colors.drag_background or { 0.12, 0.16, 0.22, 0.9 })
        love.graphics.rectangle("fill", overlayX - 4, overlayY - 4, iconSize + 8, iconSize + 8, 4, 4)

        set_color(window_colors.drag_border or window_colors.accent or { 0.2, 0.5, 0.9, 1 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", overlayX - 4 + 0.5, overlayY - 4 + 0.5, iconSize + 8 - 1, iconSize + 8 - 1, 4, 4)

        if dragItem.icon then
            CargoRendering.drawItemIcon(dragItem.icon, overlayX, overlayY, iconSize)
        else
            set_color(window_colors.muted or { 0.5, 0.55, 0.6, 1 })
            love.graphics.setLineWidth(1.25)
            love.graphics.circle("line", overlayX + iconSize * 0.5, overlayY + iconSize * 0.5, iconSize * 0.35)
        end
        love.graphics.pop()
    end

    if frame.close_clicked then
        state.visible = false
        state.dragging = false
        clear_search_focus(context, state)
    end

    state._previous_visible = state.visible == true

    love.graphics.pop()
end

--- Handles text input for search
---@param context table The game context
---@param text string The text input
---@return boolean Whether the input was handled
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

--- Handles key presses
---@param context table The game context
---@param key string The key pressed
---@param scancode string The scancode
---@param isrepeat boolean Whether this is a repeat
---@return boolean Whether the key was handled
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

--- Handles mouse wheel scrolling
---@param context table The game context
---@param x number X scroll amount
---@param y number Y scroll amount
---@return boolean Whether the scroll was handled
function cargo_window.wheelmoved(context, x, y)
    return false
end

return cargo_window
