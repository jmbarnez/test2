-- Station Window: Interface for interacting with space stations
-- Provides access to station services like trading, repairs, and missions

local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local PlayerManager = require("src.player.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local station_window = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local window_metrics = theme.window
local set_color = theme.utils.set_color

--- Gets the station name from the station entity
---@param station table The station entity
---@return string The station name
local function get_station_name(station)
    if not station then
        return "Unknown Station"
    end
    
    if station.name then
        return station.name
    end
    
    if station.stationName then
        return station.stationName
    end
    
    return "Space Station"
end

--- Draws the station window
---@param context table The game context
function station_window.draw(context)
    if not (context and context.stationUI and context.stationUI.visible) then
        return
    end
    
    local state = context.stationUI
    local fonts = theme.fonts
    
    -- Get viewport dimensions
    local vw = love.graphics.getWidth()
    local vh = love.graphics.getHeight()
    
    -- Calculate window dimensions
    local windowWidth = math.min(600, vw * 0.8)
    local windowHeight = math.min(500, vh * 0.8)
    
    -- Initialize window position if not set
    if not state.x then
        state.x = (vw - windowWidth) / 2
        state.y = (vh - windowHeight) / 2
        state.width = windowWidth
        state.height = windowHeight
    end
    
    -- Get mouse position
    local mouse_x, mouse_y = love.mouse.getPosition()
    
    -- Draw window frame
    local frame = window.draw_frame(
        state.x,
        state.y,
        state.width,
        state.height,
        get_station_name(context.stationInfluenceSource),
        fonts,
        state.dragging
    )
    
    if not frame then
        return
    end
    
    -- Handle window dragging
    local is_mouse_down = love.mouse.isDown(1)
    local was_mouse_down = state._was_mouse_down or false
    state._was_mouse_down = is_mouse_down
    
    if frame.titlebar then
        local tb = frame.titlebar
        local inTitlebar = mouse_x >= tb.x and mouse_x <= tb.x + tb.width
            and mouse_y >= tb.y and mouse_y <= tb.y + tb.height
        
        if inTitlebar and is_mouse_down and not was_mouse_down then
            state.dragging = true
            state.dragOffsetX = mouse_x - state.x
            state.dragOffsetY = mouse_y - state.y
        end
    end
    
    if state.dragging then
        if is_mouse_down then
            state.x = mouse_x - (state.dragOffsetX or 0)
            state.y = mouse_y - (state.dragOffsetY or 0)
        else
            state.dragging = false
        end
    end
    
    -- Handle close button
    if frame.closeButton then
        local cb = frame.closeButton
        local inClose = mouse_x >= cb.x and mouse_x <= cb.x + cb.width
            and mouse_y >= cb.y and mouse_y <= cb.y + cb.height
        
        if inClose and is_mouse_down and not was_mouse_down then
            station_window.close(context)
            return
        end
    end
    
    -- Draw content area
    local content = frame.content
    if not content then
        return
    end
    
    love.graphics.setFont(fonts.body or fonts.small)
    
    -- Draw station services
    local padding = theme_spacing.medium or 16
    local contentY = content.y + padding
    local contentX = content.x + padding
    local availableWidth = content.width - padding * 2
    
    -- Welcome message
    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
    love.graphics.setFont(fonts.body_bold or fonts.body)
    love.graphics.printf(
        "Welcome to " .. get_station_name(context.stationInfluenceSource),
        contentX,
        contentY,
        availableWidth,
        "center"
    )
    
    contentY = contentY + (fonts.body_bold or fonts.body):getHeight() + padding * 2
    
    -- Station services section
    love.graphics.setFont(fonts.small or fonts.body)
    set_color(window_colors.muted or { 0.65, 0.7, 0.8, 1 })
    
    local services = {
        "• Trading & Market Access",
        "• Ship Repairs & Maintenance",
        "• Module Installation & Upgrades",
        "• Mission Board",
        "• Refuel & Resupply",
    }
    
    for i, service in ipairs(services) do
        love.graphics.print(service, contentX + padding, contentY)
        contentY = contentY + (fonts.small or fonts.body):getHeight() + theme_spacing.small
    end
    
    contentY = contentY + padding
    
    -- Status message
    set_color(window_colors.muted or { 0.65, 0.7, 0.8, 1 })
    love.graphics.setFont(fonts.small_italic or fonts.small or fonts.body)
    love.graphics.printf(
        "Station services are currently under development.\nCheck back soon for full functionality.",
        contentX,
        contentY,
        availableWidth,
        "center"
    )
    
    -- Close button hint
    contentY = content.y + content.height - padding - (fonts.small or fonts.body):getHeight()
    set_color(window_colors.muted or { 0.55, 0.6, 0.7, 1 })
    love.graphics.setFont(fonts.small or fonts.body)
    love.graphics.printf(
        "Press ESC or click X to close",
        contentX,
        contentY,
        availableWidth,
        "center"
    )
end

--- Opens the station window
---@param context table The game context
function station_window.open(context)
    if not context then
        return
    end
    
    if not context.stationUI then
        context.stationUI = {
            visible = false,
            dragging = false,
            x = nil,
            y = nil,
            width = nil,
            height = nil,
            _was_mouse_down = false,
        }
    end
    
    context.stationUI.visible = true
    context.stationUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    
    -- Capture input
    if context.uiInput then
        context.uiInput.mouseCaptured = true
        context.uiInput.keyboardCaptured = true
    end
end

--- Closes the station window
---@param context table The game context
function station_window.close(context)
    if not (context and context.stationUI) then
        return
    end
    
    context.stationUI.visible = false
    context.stationUI.dragging = false
    
    -- Release input if no other modals are visible
    if context.uiInput then
        local UIStateManager = require("src.ui.state_manager")
        if not UIStateManager.isAnyUIVisible(context) then
            context.uiInput.mouseCaptured = false
            context.uiInput.keyboardCaptured = false
        end
    end
end

--- Toggles the station window visibility
---@param context table The game context
function station_window.toggle(context)
    if not context then
        return
    end
    
    if context.stationUI and context.stationUI.visible then
        station_window.close(context)
    else
        station_window.open(context)
    end
end

--- Checks if the station window is visible
---@param context table The game context
---@return boolean True if visible
function station_window.is_visible(context)
    return context and context.stationUI and context.stationUI.visible
end

--- Handles keypressed events
---@param context table The game context
---@param key string The key that was pressed
---@return boolean True if the event was handled
function station_window.keypressed(context, key)
    if not station_window.is_visible(context) then
        return false
    end
    
    if key == "escape" then
        station_window.close(context)
        return true
    end
    
    return false
end

--- Handles wheel scrolling
---@param context table The game context
---@param x number Horizontal scroll amount
---@param y number Vertical scroll amount
---@return boolean True if the event was handled
function station_window.wheelmoved(context, x, y)
    if not station_window.is_visible(context) then
        return false
    end
    
    -- Could implement scrolling here if needed
    return true
end

return station_window
