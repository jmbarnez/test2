-- Options Data: Central management for game options/settings
-- Handles defaults, persistence, synchronization, and state management

local constants = require("src.constants.game")
local runtime_settings = require("src.settings.runtime")
local AudioManager = require("src.audio.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local OptionsData = {}

-- Default values
local DEFAULT_MAX_FPS = math.max(0, (constants.window and constants.window.max_fps) or 0)
local DEFAULT_MASTER_VOLUME = AudioManager.get_default_master_volume()

local DEFAULT_KEYBINDINGS = {
    moveLeft = { "a", "left" },
    moveRight = { "d", "right" },
    moveUp = { "w", "up" },
    moveDown = { "s", "down" },
    cycleWeaponPrev = { "q" },
    cycleWeaponNext = { "e" },
    toggleCargo = { "tab" },
    toggleMap = { "m" },
    toggleSkills = { "k" },
    pause = { "escape" },
}

--- Clamps a value between 0 and 1
---@param value number|nil The value to clamp
---@return number The clamped value
local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
end

--- Creates a deep copy of keybindings
---@param source table The source keybindings
---@return table A copy of the keybindings
local function copy_bindings(source)
    local copy = {}
    for action, keys in pairs(source) do
        copy[action] = {}
        for i = 1, #keys do
            copy[action][i] = keys[i]
        end
    end
    return copy
end

--- Gets the default keybindings
---@return table The default keybindings
function OptionsData.getDefaultKeybindings()
    return copy_bindings(DEFAULT_KEYBINDINGS)
end

--- Ensures settings structure exists and has valid values
---@param state table The options state
---@param context table|nil Optional context for additional settings sources
---@return table The settings table
function OptionsData.ensure(state, context)
    local settings = context and context.settings or state.settings or {}

    state.settings = settings
    if context then
        context.settings = settings
    end

    -- Ensure keybindings
    settings.keybindings = settings.keybindings or copy_bindings(DEFAULT_KEYBINDINGS)
    for action, defaults in pairs(DEFAULT_KEYBINDINGS) do
        if type(settings.keybindings[action]) ~= "table" then
            settings.keybindings[action] = copy_bindings({ [action] = defaults })[action]
        end
    end

    -- Sync from engine if needed
    if state.syncPending or not settings.masterVolume then
        state.syncPending = false

        settings.masterVolume = clamp01((love.audio and love.audio.getVolume and love.audio.getVolume()) or settings.masterVolume or DEFAULT_MASTER_VOLUME)
        settings.musicVolume = clamp01(settings.musicVolume or settings.masterVolume)
        settings.sfxVolume = clamp01(settings.sfxVolume or settings.masterVolume)

        if love.window and love.window.getMode then
            local width, height, flags = love.window.getMode()
            settings.windowWidth = width
            settings.windowHeight = height
            settings.flags = settings.flags or {}
            for k, v in pairs(flags) do
                settings.flags[k] = v
            end
            settings.fullscreen = not not flags.fullscreen
            if type(flags.vsync) == "boolean" then
                settings.vsync = flags.vsync
            else
                settings.vsync = flags.vsync ~= 0
            end
        else
            settings.windowWidth = settings.windowWidth or 1600
            settings.windowHeight = settings.windowHeight or 900
            settings.flags = settings.flags or { fullscreen = false, vsync = 0 }
            settings.fullscreen = not not settings.flags.fullscreen
            local vs = settings.flags.vsync
            if type(vs) == "boolean" then
                settings.vsync = vs
            else
                settings.vsync = vs ~= 0
            end
        end
    else
        settings.fullscreen = not not settings.fullscreen
        if type(settings.vsync) == "boolean" then
            -- keep value
        else
            settings.vsync = settings.vsync ~= 0
        end
    end

    -- Normalize volume values
    settings.masterVolume = clamp01(settings.masterVolume)
    settings.musicVolume = clamp01(settings.musicVolume)
    settings.sfxVolume = clamp01(settings.sfxVolume)

    -- Normalize boolean flags
    settings.fullscreen = not not settings.fullscreen
    settings.vsync = not not settings.vsync

    -- Update flags table
    settings.flags = settings.flags or {}
    settings.flags.fullscreen = settings.fullscreen
    settings.flags.vsync = settings.vsync

    -- Sync runtime settings
    runtime_settings.set_vsync_enabled(settings.vsync)

    -- Handle FPS limit
    settings.maxFps = math.max(0, tonumber(settings.maxFps or DEFAULT_MAX_FPS) or 0)
    runtime_settings.set_max_fps(settings.maxFps)

    return settings
end

--- Resets all settings to defaults
---@param settings table The settings table
function OptionsData.resetToDefaults(settings)
    if not settings then
        return
    end

    settings.masterVolume = DEFAULT_MASTER_VOLUME
    settings.musicVolume = DEFAULT_MASTER_VOLUME
    settings.sfxVolume = DEFAULT_MASTER_VOLUME
    settings.fullscreen = false
    settings.vsync = false
    settings.maxFps = DEFAULT_MAX_FPS
    settings.keybindings = copy_bindings(DEFAULT_KEYBINDINGS)
end

--- Gets the default FPS limit value
---@return number The default FPS limit
function OptionsData.getDefaultMaxFps()
    return DEFAULT_MAX_FPS
end

return OptionsData
