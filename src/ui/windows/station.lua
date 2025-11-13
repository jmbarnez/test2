-- Station Window: Interface for interacting with space stations

local theme = require("src.ui.theme")
local window = require("src.ui.components.window")

---@diagnostic disable-next-line: undefined-global
local love = love

local station_window = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color

local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 320

local function resolve_fonts()
    local fonts = theme.get_fonts and theme.get_fonts() or theme.fonts or {}
    if not fonts.body then
        fonts.body = love.graphics.getFont()
    end
    return fonts
end

local function resolve_station_name(context)
    local station = context and context.stationDockTarget
    if station then
        if station.name then
            return station.name
        end
        if station.stationName then
            return station.stationName
        end
    end
    return "Space Station"
end

--- Draws the station window
---@param context table The game context
function station_window.draw(context)
    print("[STATION WINDOW] draw called - context:", context ~= nil, "stationUI:", context and context.stationUI ~= nil, "visible:", context and context.stationUI and context.stationUI.visible)
    
    if not (context and context.stationUI and context.stationUI.visible) then
        return
    end

    local state = context.stationUI
    print("[STATION WINDOW] draw - state visible:", state.visible, "x:", state.x, "y:", state.y, "w:", state.width, "h:", state.height)
    local fonts = resolve_fonts()
    local default_font = fonts.body or love.graphics.getFont()

    local vw, vh = love.graphics.getWidth(), love.graphics.getHeight()

    state.width = state.width or math.min(DEFAULT_WIDTH, vw * 0.9)
    state.height = state.height or math.min(DEFAULT_HEIGHT, vh * 0.9)
    state.x = state.x or (vw - state.width) * 0.5
    state.y = state.y or (vh - state.height) * 0.5

    local mouse_x, mouse_y = love.mouse.getPosition()
    local mouse_down = love.mouse.isDown(1)
    local previous_down = state._mouse_down_prev or false

    -- DEBUG: Draw a bright rectangle to make sure we can see SOMETHING
    love.graphics.setColor(1, 0, 0, 0.8)  -- Bright red
    love.graphics.rectangle("fill", state.x, state.y, state.width, state.height)
    love.graphics.setColor(1, 1, 1, 1)    -- Reset color

    local frame = window.draw_frame {
        x = state.x,
        y = state.y,
        width = state.width,
        height = state.height,
        title = resolve_station_name(context),
        state = state,
        fonts = fonts,
        input = {
            x = mouse_x,
            y = mouse_y,
            just_pressed = mouse_down and not previous_down,
            is_down = mouse_down,
        },
    }

    state._mouse_down_prev = mouse_down

    if not frame then
        return
    end

    if frame.close_clicked then
        station_window.close(context)
        return
    end

    local content = frame.content
    if not content then
        return
    end

    local padding = theme_spacing.medium or 16
    local inner_x = content.x + padding
    local inner_width = math.max(0, content.width - padding * 2)
    local cursor_y = content.y + padding

    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
    love.graphics.setFont((fonts.body_bold or fonts.title or default_font))
    love.graphics.printf("Station Services", inner_x, cursor_y, inner_width, "center")

    cursor_y = cursor_y + ((fonts.body_bold or fonts.title or default_font):getHeight()) + padding

    set_color(window_colors.muted or { 0.65, 0.7, 0.8, 1 })
    love.graphics.setFont(default_font)
    love.graphics.printf(
        "Docking functionality coming soon.\nPress Esc or click X to undock.",
        inner_x,
        cursor_y,
        inner_width,
        "center"
    )
end

--- Opens the station window via UI state manager
---@param context table The game context
function station_window.open(context)
    if not context then
        return
    end
    local UIStateManager = require("src.ui.state_manager")
    UIStateManager.showStationUI(context)
end

--- Closes the station window via UI state manager
---@param context table The game context
function station_window.close(context)
    if not context then
        return
    end
    local UIStateManager = require("src.ui.state_manager")
    UIStateManager.hideStationUI(context)
end

--- Toggles the station window visibility
---@param context table The game context
function station_window.toggle(context)
    if not context then
        return
    end
    local UIStateManager = require("src.ui.state_manager")
    if UIStateManager.isStationUIVisible(context) then
        UIStateManager.hideStationUI(context)
    else
        UIStateManager.showStationUI(context)
    end
end

--- Checks if the station window is visible
---@param context table The game context
---@return boolean
function station_window.is_visible(context)
    local UIStateManager = require("src.ui.state_manager")
    return UIStateManager.isStationUIVisible(context)
end

--- Handles key input
---@param context table The game context
---@param key string
---@return boolean
function station_window.keypressed(context, key)
    if key == "escape" and station_window.is_visible(context) then
        station_window.close(context)
        return true
    end
    return false
end

--- Handles wheel scrolling
---@param context table
---@param x number
---@param y number
---@return boolean
function station_window.wheelmoved(context, x, y)
    if station_window.is_visible(context) then
        return true
    end
    return false
end

return station_window
