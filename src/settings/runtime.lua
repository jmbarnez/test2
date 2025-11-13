local constants = require("src.constants.game")

local runtime_settings = {
    max_fps = math.max(0, (constants.window and constants.window.max_fps) or 0),
    vsync_enabled = (constants.window and ((constants.window.vsync or 0) ~= 0)) or false,
    _frame_limit_dirty = true,
    _on_frame_limit_changed = nil,
}

function runtime_settings.get_max_fps()
    return runtime_settings.max_fps or 0
end

function runtime_settings.set_max_fps(value)
    value = tonumber(value) or 0
    if value < 0 then
        value = 0
    end
    local old = runtime_settings.max_fps
    runtime_settings.max_fps = value
    if runtime_settings.max_fps ~= old then
        runtime_settings._frame_limit_dirty = true
        local cb = runtime_settings._on_frame_limit_changed
        if cb then
            cb()
        end
    end
    return runtime_settings.max_fps
end

function runtime_settings.is_vsync_enabled()
    return runtime_settings.vsync_enabled == true
end

function runtime_settings.set_vsync_enabled(enabled)
    local new_value = not not enabled
    local old = runtime_settings.vsync_enabled
    runtime_settings.vsync_enabled = new_value
    if runtime_settings.vsync_enabled ~= old then
        runtime_settings._frame_limit_dirty = true
        local cb = runtime_settings._on_frame_limit_changed
        if cb then
            cb()
        end
    end
    return runtime_settings.vsync_enabled
end

function runtime_settings.should_limit_frame_rate()
    return (not runtime_settings.is_vsync_enabled()) and runtime_settings.get_max_fps() > 0
end

function runtime_settings.is_frame_limit_dirty()
    return runtime_settings._frame_limit_dirty == true
end

function runtime_settings.clear_frame_limit_dirty()
    runtime_settings._frame_limit_dirty = false
end

function runtime_settings.set_frame_limit_changed_callback(callback)
    runtime_settings._on_frame_limit_changed = callback
end

return runtime_settings
