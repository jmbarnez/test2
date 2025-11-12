-- Cargo Window: Coordinator for inventory management UI
-- Delegates to specialized modules for data, tooltips, and rendering
-- Handles window frame, search, sorting, and user interaction

local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local PlayerManager = require("src.player.manager")
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

--- Clears search input focus
---@param context table The game context
---@param state table The cargo UI state
local function clear_search_focus(context, state)
    if context and context.uiInput then
        context.uiInput.keyboardCaptured = false
    end
    state.isSearchActive = false
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
        local set_color = theme.utils.set_color
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
    local set_color = theme.utils.set_color
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

    return searchRect, sortRect
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

    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_mouse_down = love.mouse.isDown(1)
    local just_pressed = is_mouse_down and not state._was_mouse_down

    if state.isSearchActive and uiInput then
        uiInput.keyboardCaptured = true
    end

    -- Get player and cargo data
    local player = PlayerManager.resolveLocalPlayer(context)
    if not player then
        love.graphics.pop()
        return
    end
    
    local cargoInfo = CargoData.getCargoInfo(player)
    local currencyValue = CargoData.getCurrency(context, player)
    local currencyText = currencyValue ~= nil and CargoData.formatCurrency(currencyValue) or "--"

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
        if mouseInsideWindow or state.dragging or frame.dragging then
            uiInput.mouseCaptured = true
        end
    end

    local content = frame.content
    
    -- Draw search and sort controls
    local searchRect, sortRect = draw_search_and_sort(content, state, fonts, mouse_x, mouse_y, just_pressed, uiInput)
    
    local searchHeight = fonts.body:getHeight() + 12
    local searchSpacing = 6
    local gridY = content.y + searchHeight + searchSpacing
    local gridHeight = content.height - searchHeight - searchSpacing
    if gridHeight < 0 then
        gridHeight = 0
    end

    -- Calculate grid layout
    local slotsPerRow, slotsPerColumn, totalVisibleSlots, slotSize, slotWithLabelHeight, labelHeight =
        CargoRendering.calculateGridLayout(content.width, gridHeight, fonts)

    local slotPadding = theme_spacing.slot_padding
    local gridStartY = gridY
    local gridStartX = content.x

    -- Filter and sort items
    local filteredItems = CargoData.filterItems(cargoInfo.items, state.searchQuery)
    CargoData.sortItems(filteredItems, state.sortMode)

    -- Draw item slots
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
            CargoTooltip.create(item)
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

    -- Draw bottom bar (capacity and currency)
    local bottomBar = frame.bottom_bar
    if bottomBar then
        local barWidth = CargoRendering.drawCapacityBar(bottomBar, cargoInfo.percentFull, cargoInfo.capacity, fonts)
        if barWidth then
            CargoRendering.drawCurrency(bottomBar, barWidth, currencyText, fonts)
        end
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
