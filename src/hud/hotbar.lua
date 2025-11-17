local constants = require("src.constants.game")
local theme = require("src.ui.theme")
local HotbarManager = require("src.player.hotbar")
local ItemIconRenderer = require("src.util.item_icon_renderer")

---@diagnostic disable-next-line: undefined-global
local love = love

local Hotbar = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local hotbar_constants = (constants.ui and constants.ui.hotbar) or {}
local set_color = theme.utils.set_color
local HOTBAR_SLOTS = hotbar_constants.slot_count or 10
local SELECTED_OUTLINE_COLOR = { 0.2, 0.85, 0.95, 1 }

local function draw_item_icon(icon, x, y, size)
    return ItemIconRenderer.drawAt(icon, x, y, size, {
        set_color = set_color,
        fallbackRadius = 0.35,
    })
end

--- Get hotbar slot rectangles for external drag-drop support
---@param context table
---@param player table
---@return table|nil Array of slot rectangles with x, y, width, height, slotIndex
function Hotbar.getSlotRects(context, player)
    if not player then return nil end
    
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return nil end

    -- Mirror layout math from Hotbar.draw to keep hit-testing aligned
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local baseSlotSize = (theme_spacing and theme_spacing.slot_size) or 48
    local slotSize = math.max(36, math.floor(baseSlotSize * 0.9))
    local padding = 6
    local gap = 5

    local selectedIndex = hotbar.selectedIndex or 1
    if selectedIndex < 1 or selectedIndex > HOTBAR_SLOTS then
        selectedIndex = 1
    end

    local selectedItem = hotbar.slots[selectedIndex]
    local name = nil
    if selectedItem then
        name = selectedItem.name or (selectedItem.id and selectedItem.id:gsub("_", " ")) or "Item"
    end

    local fonts = theme.get_fonts()
    local barWidth = HOTBAR_SLOTS * slotSize + (HOTBAR_SLOTS - 1) * gap + padding * 2
    local titleHeight = 0
    if fonts.body and name then
        titleHeight = fonts.body:getHeight() + padding
        local nameWidth = fonts.body:getWidth(name)
        if barWidth < nameWidth + padding * 2 then
            barWidth = nameWidth + padding * 2
        end
    end

    local barHeight = slotSize + padding * 2 + titleHeight
    local x = (screenWidth - barWidth) * 0.5
    local y = screenHeight - barHeight - 16

    local contentY = y + padding
    if fonts.body and name then
        contentY = contentY + fonts.body:getHeight() + padding * 0.5
    end

    local slotStartX = x + padding
    local slotY = contentY

    local rects = {}
    for i = 1, HOTBAR_SLOTS do
        local slotX = slotStartX + (i - 1) * (slotSize + gap)
        rects[i] = {
            x = slotX,
            y = slotY,
            width = slotSize,
            height = slotSize,
            slotIndex = i,
        }
    end

    return rects
end

--- Check if mouse position is over a hotbar slot
---@param mouseX number
---@param mouseY number
---@param context table
---@param player table
---@return number|nil slotIndex The slot index if hovering, nil otherwise
function Hotbar.getSlotAtPosition(mouseX, mouseY, context, player)
    if not (mouseX and mouseY) then return nil end
    
    local rects = Hotbar.getSlotRects(context, player)
    if not rects then return nil end
    
    for i = 1, #rects do
        local rect = rects[i]
        if mouseX >= rect.x and mouseX <= rect.x + rect.width and
           mouseY >= rect.y and mouseY <= rect.y + rect.height then
            return rect.slotIndex
        end
    end
    
    return nil
end

function Hotbar.draw(context, player)
    if not player then return end

    context = context or {}
    local state = context.state or context

    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return end

    local selectedIndex = hotbar.selectedIndex or 1
    if selectedIndex < 1 or selectedIndex > HOTBAR_SLOTS then
        selectedIndex = 1
    end

    local fonts = theme.get_fonts()
    local selectedItem = hotbar.slots[selectedIndex]

    local name = nil
    if selectedItem then
        name = selectedItem.name or (selectedItem.id and selectedItem.id:gsub("_", " ")) or "Item"
    end

    local slotsForLayout = HOTBAR_SLOTS
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local baseSlotSize = (theme_spacing and theme_spacing.slot_size) or 48
    local slotSize = math.max(36, math.floor(baseSlotSize * 0.9))
    local padding = 6
    local gap = 5

    local barWidth = slotsForLayout * slotSize + (slotsForLayout - 1) * gap + padding * 2
    local titleHeight = 0
    if fonts.body and name then
        titleHeight = fonts.body:getHeight() + padding
        local nameWidth = fonts.body:getWidth(name)
        if barWidth < nameWidth + padding * 2 then
            barWidth = nameWidth + padding * 2
        end
    end

    local barHeight = slotSize + padding * 2 + titleHeight
    local x = (screenWidth - barWidth) * 0.5
    local y = screenHeight - barHeight - 16

    -- Background
    set_color(window_colors.shadow or { 0, 0, 0, 0.4 })
    love.graphics.rectangle("fill", x, y + 2, barWidth, barHeight, 4, 4)
    set_color(window_colors.background or { 0.02, 0.02, 0.04, 0.9 })
    love.graphics.rectangle("fill", x, y, barWidth, barHeight, 4, 4)

    local contentY = y + padding

    -- Text
    if fonts.body and name then
        local textX = x + padding
        love.graphics.setFont(fonts.body)
        set_color(window_colors.text or { 0.8, 0.8, 0.85, 1 })
        love.graphics.print(name, textX, contentY)
        contentY = contentY + fonts.body:getHeight() + padding * 0.5
    end

    local slotStartX = x + padding
    local slotY = contentY

    local selectedDisplayIndex = math.min(selectedIndex, HOTBAR_SLOTS)

    local hotbarState
    if type(state) == "table" then
        state.hotbarUI = state.hotbarUI or {}
        hotbarState = state.hotbarUI
    else
        Hotbar._fallbackState = Hotbar._fallbackState or {}
        hotbarState = Hotbar._fallbackState
    end

    local ownsCapture = hotbarState and hotbarState.capturingMouse or false

    local uiInput = context.uiInput
    
    -- Always get mouse position and state to check for hotbar hovers
    local mouseX, mouseY
    if love.mouse and love.mouse.getPosition then
        mouseX, mouseY = love.mouse.getPosition()
    end

    local isMouseDown = false
    local isRightMouseDown = false
    if love.mouse and love.mouse.isDown then
        isMouseDown = love.mouse.isDown(1) or false
        isRightMouseDown = love.mouse.isDown(2) or false
    end

    local wasMouseDown = hotbarState and hotbarState.wasMouseDown or false
    local wasRightMouseDown = hotbarState and hotbarState.wasRightMouseDown or false
    
    -- Check if mouse is over any hotbar slot
    local mouseOverHotbar = false
    if mouseX and mouseY then
        local testSlotX = slotStartX
        for i = 1, HOTBAR_SLOTS do
            local slotX = slotStartX + (i - 1) * (slotSize + gap)
            if mouseX >= slotX and mouseX <= slotX + slotSize and 
               mouseY >= slotY and mouseY <= slotY + slotSize then
                mouseOverHotbar = true
                break
            end
        end
    end
    
    -- Allow interaction if we own the capture, OR if mouse is over hotbar (hotbar can steal focus)
    local allowInteraction = not (uiInput and uiInput.mouseCaptured and not ownsCapture) or mouseOverHotbar
    local interactionEnabled = allowInteraction or ownsCapture
    
    local justPressed = interactionEnabled and isMouseDown and not wasMouseDown
    local justReleased = interactionEnabled and not isMouseDown and wasMouseDown
    local justRightPressed = interactionEnabled and isRightMouseDown and not wasRightMouseDown

    local hoveredIndex = nil
    local draggedIndex = hotbarState and hotbarState.draggedIndex
    local pressIndex = hotbarState and hotbarState.pressIndex

    -- Icon
    for i = 1, HOTBAR_SLOTS do
        local item = hotbar.slots[i]
        local slotX = slotStartX + (i - 1) * (slotSize + gap)

        local isHovered = false
        if mouseX and mouseY then
            isHovered = mouseX >= slotX and mouseX <= slotX + slotSize and mouseY >= slotY and mouseY <= slotY + slotSize
            if isHovered then
                hoveredIndex = i
                if uiInput and interactionEnabled and (isMouseDown or justPressed) then
                    uiInput.mouseCaptured = true
                    if hotbarState then
                        hotbarState.capturingMouse = true
                    end
                end
            end
        end

        -- Handle drag start (only if not already dragging from external UI)
        if interactionEnabled and justPressed and isHovered and item and not hotbarState.draggedIndex then
            hotbarState.draggedIndex = i
            hotbarState.dragStartX = mouseX
            hotbarState.dragStartY = mouseY
        end

        -- Handle drag end / drop (only if cargo window doesn't have capture)
        -- When cargo is open, it handles all hotbar drops
        local cargoHasCapture = uiInput and uiInput.mouseCaptured and not ownsCapture
        if interactionEnabled and justReleased and hotbarState.draggedIndex and not cargoHasCapture then
            -- Check which slot the mouse is over when released
            local mouseX, mouseY = love.mouse.getPosition()
            local dropSlot = Hotbar.getSlotAtPosition(mouseX, mouseY, context, player)
            
            if dropSlot and dropSlot ~= hotbarState.draggedIndex then
                -- Drop on a different slot -> swap
                HotbarManager.swapSlots(player, hotbarState.draggedIndex, dropSlot)
                hotbarState.draggedIndex = nil
                hotbarState.capturingMouse = false
                if uiInput and uiInput.mouseCaptured then
                    uiInput.mouseCaptured = false
                end
            elseif dropSlot == hotbarState.draggedIndex then
                -- Just a click, select this slot
                HotbarManager.setSelected(player, dropSlot)
                selectedIndex = dropSlot
                selectedItem = hotbar.slots[dropSlot]
                hotbarState.draggedIndex = nil
                hotbarState.capturingMouse = false
                if uiInput and uiInput.mouseCaptured then
                    uiInput.mouseCaptured = false
                end
            else
                -- Dropped outside hotbar, let other UI elements handle it (e.g., cargo window)
                -- Don't clear drag state here - it will be cleared by whoever handles it
            end
            break  -- Exit loop after handling drop
        end

        -- Handle right-click to remove item from hotbar
        if interactionEnabled and justRightPressed and isHovered and item then
            HotbarManager.moveToCargo(player, i)
        end

        local isSelected = (i == selectedIndex)
        local isDragging = (draggedIndex == i)
        if isDragging then
            set_color(window_colors.surface_subtle or { 0.03, 0.04, 0.07, 0.5 })
        elseif isSelected then
            set_color(window_colors.surface or window_colors.background or { 0.05, 0.07, 0.10, 0.95 })
        else
            set_color(window_colors.surface_subtle or { 0.03, 0.04, 0.07, 0.9 })
        end
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 3, 3)

        if isSelected then
            love.graphics.push("all")
            set_color(SELECTED_OUTLINE_COLOR)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slotX + 1, slotY + 1, slotSize - 2, slotSize - 2, 3, 3)
            love.graphics.pop()
        end

        if item and not isDragging then
            local iconDrawn = draw_item_icon(item.icon, slotX + 4, slotY + 4, slotSize - 8)

            if not iconDrawn then
                set_color(window_colors.muted or { 0.5, 0.5, 0.55, 0.7 })
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", slotX + slotSize * 0.5, slotY + slotSize * 0.5, slotSize * 0.3)
            end

            -- Show quantity if > 1
            if item.quantity and item.quantity > 1 and fonts.small then
                love.graphics.setFont(fonts.small)
                set_color({ 1, 1, 1, 1 })
                local qtyText = tostring(item.quantity)
                local qtyWidth = fonts.small:getWidth(qtyText)
                love.graphics.print(qtyText, slotX + slotSize - qtyWidth - 4, slotY + 4)
            end
        end

        if fonts.small then
            love.graphics.setFont(fonts.small)
            if item then
                if isSelected then
                    set_color(window_colors.accent or { 0.3, 0.6, 0.8, 1 })
                else
                    set_color(window_colors.muted or { 0.6, 0.6, 0.65, 1 })
                end
            else
                set_color(window_colors.surface_subtle or { 0.25, 0.25, 0.3, 0.8 })
            end

            local label
            if i == 10 then
                label = "0"
            else
                label = tostring(i)
            end
            love.graphics.print(label, slotX + 4, slotY + slotSize - fonts.small:getHeight() - 2)
        end
    end

    -- Draw dragged item following cursor
    if draggedIndex and mouseX and mouseY and hotbar.slots[draggedIndex] then
        local draggedItem = hotbar.slots[draggedIndex]
        local dragSize = slotSize * 0.8
        local dragX = mouseX - dragSize / 2
        local dragY = mouseY - dragSize / 2
        
        set_color({ 0.1, 0.1, 0.15, 0.9 })
        love.graphics.rectangle("fill", dragX, dragY, dragSize, dragSize, 3, 3)
        draw_item_icon(draggedItem.icon, dragX + 4, dragY + 4, dragSize - 8)
    end

    if hotbarState then
        hotbarState.wasMouseDown = interactionEnabled and isMouseDown or false
        hotbarState.wasRightMouseDown = interactionEnabled and isRightMouseDown or false
        -- Don't auto-clear drag state - let drop handlers (hotbar or cargo) clear it explicitly
        -- Only release mouse capture if drag was already cleared by a handler
        if not isMouseDown and not isRightMouseDown then
            if hotbarState.capturingMouse and not hotbarState.draggedIndex then
                hotbarState.capturingMouse = false
                if uiInput and uiInput.mouseCaptured then
                    uiInput.mouseCaptured = false
                end
            end
            -- Safety: if drag persists after mouse release for too long, clear it
            if hotbarState.draggedIndex and justReleased then
                hotbarState.dragReleaseFrame = (hotbarState.dragReleaseFrame or 0) + 1
                if hotbarState.dragReleaseFrame > 2 then
                    hotbarState.draggedIndex = nil
                    hotbarState.capturingMouse = false
                    hotbarState.dragReleaseFrame = nil
                    if uiInput and uiInput.mouseCaptured then
                        uiInput.mouseCaptured = false
                    end
                end
            else
                hotbarState.dragReleaseFrame = nil
            end
        end
    end

    if hoveredIndex and hoveredIndex >= 1 and hoveredIndex <= HOTBAR_SLOTS and state and not state.hudTooltipRequest and not draggedIndex then
        local item = hotbar.slots[hoveredIndex]
        if item then
            local heading = item.name or (item.id and item.id:gsub("_", " ")) or "Item"
            local body = {}

            local item_type = item.type or "item"
            body[#body + 1] = string.format("Type: %s", tostring(item_type))

            if item.quantity and item.quantity > 1 then
                body[#body + 1] = string.format("Quantity: %d", item.quantity)
            end

            if item.volume then
                body[#body + 1] = string.format("Volume: %.1f", item.volume)
            end

            state.hudTooltipRequest = {
                heading = heading,
                body = body,
                description = item.description,
            }
        end
    end
end

--- Get current hotbar drag state
---@param context table
---@param player table
---@return table|nil dragInfo {item: table, slotIndex: number} or nil if not dragging
function Hotbar.getDragState(context, player)
    if not player then return nil end
    
    local state = context.state or context
    local hotbarState
    if type(state) == "table" then
        hotbarState = state.hotbarUI
    else
        hotbarState = Hotbar._fallbackState
    end
    
    if not hotbarState or not hotbarState.draggedIndex then
        return nil
    end
    
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return nil end
    
    local draggedItem = hotbar.slots[hotbarState.draggedIndex]
    if not draggedItem then return nil end
    
    return {
        item = draggedItem,
        slotIndex = hotbarState.draggedIndex,
    }
end

--- Clear hotbar drag state (called externally when drag is handled)
---@param context table
function Hotbar.clearDragState(context)
    local state = context.state or context
    local hotbarState
    if type(state) == "table" then
        hotbarState = state.hotbarUI
    else
        hotbarState = Hotbar._fallbackState
    end
    
    if hotbarState then
        -- Only release global capture if we owned it
        local ownedCapture = hotbarState.capturingMouse
        hotbarState.draggedIndex = nil
        hotbarState.capturingMouse = false

        -- Release UI input capture if we owned it
        if ownedCapture then
            local uiInput = context.uiInput or (state and state.uiInput)
            if uiInput and uiInput.mouseCaptured then
                uiInput.mouseCaptured = false
            end
        end
    end
end

--- Expose HotbarManager functions for external use
Hotbar.moveFromCargo = HotbarManager.moveFromCargo
Hotbar.moveToCargo = HotbarManager.moveToCargo
Hotbar.swapSlots = HotbarManager.swapSlots
Hotbar.setSlot = HotbarManager.setSlot
Hotbar.getSlot = HotbarManager.getSlot

--- Begin a hotbar drag on a specific slot (used by external UIs)
---@param context table
---@param player table
---@param slotIndex number
---@param mouseX number|nil
---@param mouseY number|nil
---@return boolean started True if drag was started
function Hotbar.beginDragAtSlot(context, player, slotIndex, mouseX, mouseY)
    local hotbar = HotbarManager.getHotbar(player)
    if not (hotbar and slotIndex and slotIndex >= 1 and slotIndex <= HOTBAR_SLOTS) then
        return false
    end
    local item = hotbar.slots[slotIndex]
    if not item then
        return false
    end

    local state = context.state or context
    local hotbarState
    if type(state) == "table" then
        state.hotbarUI = state.hotbarUI or {}
        hotbarState = state.hotbarUI
    else
        Hotbar._fallbackState = Hotbar._fallbackState or {}
        hotbarState = Hotbar._fallbackState
    end

    hotbarState.draggedIndex = slotIndex
    hotbarState.dragStartX = mouseX
    hotbarState.dragStartY = mouseY
    hotbarState.capturingMouse = true

    local uiInput = context.uiInput or (state and state.uiInput)
    if uiInput then
        uiInput.mouseCaptured = true
    end

    return true
end

return Hotbar
