local core = require("src.ui.state.core")

local resolve_state_pair = core.resolve_state_pair

local Events = {}

local _cargo_window
local _options_window
local _map_window
local _debug_window
local _station_window

local function resolve_cargo_window()
    if not _cargo_window then
        _cargo_window = require("src.ui.windows.cargo")
    end
    return _cargo_window
end

local function resolve_options_window()
    if not _options_window then
        _options_window = require("src.ui.windows.options")
    end
    return _options_window
end

local function resolve_map_window()
    if not _map_window then
        _map_window = require("src.ui.windows.map")
    end
    return _map_window
end

local function resolve_debug_window()
    if not _debug_window then
        _debug_window = require("src.ui.windows.debug")
    end
    return _debug_window
end

local function resolve_station_window()
    if not _station_window then
        _station_window = require("src.ui.windows.station")
    end
    return _station_window
end

local function with_resolved_state(state, callback)
    local resolved = resolve_state_pair(state)
    if not resolved then
        return false
    end

    return callback(resolved)
end

function Events.handleWheelMoved(UIStateManager, state, x, y)
    return with_resolved_state(state, function(resolved)
        local window

        if UIStateManager.isOptionsUIVisible and UIStateManager.isOptionsUIVisible(resolved) then
            window = resolve_options_window()
            if window and window.wheelmoved and window.wheelmoved(resolved, x, y) then
                return true
            end
        end

        if UIStateManager.isMapUIVisible and UIStateManager.isMapUIVisible(resolved) then
            window = resolve_map_window()
            if window and window.wheelmoved and window.wheelmoved(resolved, x, y) then
                return true
            end
        end

        if UIStateManager.isDebugUIVisible and UIStateManager.isDebugUIVisible(resolved) then
            window = resolve_debug_window()
            if window and window.wheelmoved and window.wheelmoved(resolved, x, y) then
                return true
            end
        end

        if UIStateManager.isStationUIVisible and UIStateManager.isStationUIVisible(resolved) then
            window = resolve_station_window()
            if window and window.wheelmoved and window.wheelmoved(resolved, x, y) then
                return true
            end
        end

        window = resolve_cargo_window()
        if window and window.wheelmoved then
            window.wheelmoved(resolved, x, y)
        end

        return false
    end)
end

function Events.handleKeyPressed(UIStateManager, state, key, scancode, isrepeat)
    return with_resolved_state(state, function(resolved)
        -- Note: cargo_window uses all parameters, others only use context and key
        local window = resolve_cargo_window()
        if window and window.keypressed and window.keypressed(resolved, key, scancode, isrepeat) then
            return true
        end

        window = resolve_station_window()
        if window and window.keypressed and window.keypressed(resolved, key) then
            return true
        end

        if UIStateManager.isMapUIVisible and UIStateManager.isMapUIVisible(resolved) then
            window = resolve_map_window()
            if window and window.keypressed and window.keypressed(resolved, key) then
                return true
            end
        end

        if UIStateManager.isOptionsUIVisible and UIStateManager.isOptionsUIVisible(resolved) then
            window = resolve_options_window()
            if window and window.keypressed and window.keypressed(resolved, key) then
                return true
            end
        end

        return false
    end)
end

function Events.handleTextInput(UIStateManager, state, text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    return with_resolved_state(state, function(resolved)
        local window = resolve_cargo_window()
        if window and window.textinput and window.textinput(resolved, text) then
            return true
        end

        if UIStateManager.isMapUIVisible and UIStateManager.isMapUIVisible(resolved) then
            window = resolve_map_window()
            if window and window.textinput and window.textinput(resolved, text) then
                return true
            end
        end

        return false
    end)
end

function Events.handleMousePressed(UIStateManager, state, x, y, button, istouch, presses)
    return with_resolved_state(state, function(resolved)
        local handled = false

        local function try_window(window)
            if not window or type(window.mousepressed) ~= "function" then
                return false
            end

            if window.mousepressed(resolved, x, y, button, istouch, presses) then
                handled = true
                return true
            end

            return false
        end

        if UIStateManager.isOptionsUIVisible and UIStateManager.isOptionsUIVisible(resolved)
            and try_window(resolve_options_window()) then
            return true
        end

        if UIStateManager.isMapUIVisible and UIStateManager.isMapUIVisible(resolved)
            and try_window(resolve_map_window()) then
            return true
        end

        if UIStateManager.isDebugUIVisible and UIStateManager.isDebugUIVisible(resolved)
            and try_window(resolve_debug_window()) then
            return true
        end

        if UIStateManager.isStationUIVisible and UIStateManager.isStationUIVisible(resolved)
            and try_window(resolve_station_window()) then
            return true
        end

        try_window(resolve_cargo_window())

        return handled
    end)
end

function Events.handleMouseReleased(UIStateManager, state, x, y, button, istouch, presses)
    return with_resolved_state(state, function(resolved)
        local handled = false

        local function try_window(window)
            if not window or type(window.mousereleased) ~= "function" then
                return false
            end

            if window.mousereleased(resolved, x, y, button, istouch, presses) then
                handled = true
                return true
            end

            return false
        end

        if UIStateManager.isOptionsUIVisible and UIStateManager.isOptionsUIVisible(resolved)
            and try_window(resolve_options_window()) then
            return true
        end

        if UIStateManager.isMapUIVisible and UIStateManager.isMapUIVisible(resolved)
            and try_window(resolve_map_window()) then
            return true
        end

        if UIStateManager.isDebugUIVisible and UIStateManager.isDebugUIVisible(resolved)
            and try_window(resolve_debug_window()) then
            return true
        end

        if UIStateManager.isStationUIVisible and UIStateManager.isStationUIVisible(resolved)
            and try_window(resolve_station_window()) then
            return true
        end

        try_window(resolve_cargo_window())

        return handled
    end)
end

function Events.toggleFullscreen(state)
    return with_resolved_state(state, function(resolved)
        local window = resolve_options_window()
        if window and window.toggle_fullscreen then
            return window.toggle_fullscreen(resolved)
        end
        return false
    end)
end

return Events
