local constants = require("src.constants.game")

local runtime_settings = {
    max_fps = math.max(0, (constants.window and constants.window.max_fps) or 0),
    vsync_enabled = (constants.window and ((constants.window.vsync or 0) ~= 0)) or false,
}

function runtime_settings.get_max_fps()
    return runtime_settings.max_fps or 0
end

function runtime_settings.set_max_fps(value)
    value = tonumber(value) or 0
    if value < 0 then
        value = 0
    end
    runtime_settings.max_fps = value
    return runtime_settings.max_fps
end

function runtime_settings.is_vsync_enabled()
    return runtime_settings.vsync_enabled == true
end

function runtime_settings.set_vsync_enabled(enabled)
    runtime_settings.vsync_enabled = not not enabled
    return runtime_settings.vsync_enabled
end

function runtime_settings.should_limit_frame_rate()
    return (not runtime_settings.is_vsync_enabled()) and runtime_settings.get_max_fps() > 0
end

return runtime_settings
