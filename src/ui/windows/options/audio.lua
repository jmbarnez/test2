-- Audio Settings: Volume controls and audio configuration UI
-- Handles volume sliders (master, music, SFX) and audio engine integration

local theme = require("src.ui.theme")
local AudioManager = require("src.audio.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local AudioSettings = {}

--- Clamps a value between 0 and 1
---@param value number|nil The value to clamp
---@return number The clamped value
local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
end

--- Applies volume settings to the audio engine
---@param settings table The settings table
function AudioSettings.apply(settings)
    if AudioManager and AudioManager.ensure_initialized then
        AudioManager.ensure_initialized()
        AudioManager.set_master_volume(settings.masterVolume or 1)
        AudioManager.set_music_volume(settings.musicVolume or settings.masterVolume or 1)
        AudioManager.set_sfx_volume(settings.sfxVolume or settings.masterVolume or 1)
    elseif love.audio and love.audio.setVolume then
        love.audio.setVolume(settings.masterVolume or 1)
    end
end

--- Draws a volume slider
---@param fonts table Font table from theme
---@param label string The slider label
---@param rect table The slider rectangle {x, y, w, h}
---@param value number The current value (0-1)
---@param registry table Table to register the rect in for interaction
local function draw_slider(fonts, label, rect, value, registry)
    local windowColors = theme.colors.window or {}
    local textColor = windowColors.text or { 0.85, 0.85, 0.9, 1 }
    local accentColor = windowColors.accent or { 0.2, 0.55, 0.95, 1 }
    local trackColor = windowColors.progress_background or { 0.06, 0.07, 0.1, 1 }
    local knobColor = windowColors.button or { 0.08, 0.08, 0.12, 1 }

    love.graphics.setFont(fonts.body)
    love.graphics.setColor(textColor)
    love.graphics.print(label, rect.x, rect.y - (fonts.body:getHeight() + 6))

    love.graphics.setColor(trackColor)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)

    love.graphics.setColor(accentColor)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w * value, rect.h, 4, 4)

    love.graphics.setColor(knobColor)
    local knobRadius = math.min(rect.h * 0.75, 8)
    love.graphics.circle("fill", rect.x + rect.w * value, rect.y + rect.h * 0.5, knobRadius)

    local percentText = string.format("%d%%", math.floor(value * 100 + 0.5))
    love.graphics.setFont(fonts.small)
    local percentWidth = fonts.small:getWidth(percentText)
    love.graphics.setColor(textColor)
    love.graphics.print(percentText, rect.x + rect.w - percentWidth, rect.y + rect.h + 4)

    registry[label] = rect
end

--- Renders the audio settings section
---@param params table {fonts, settings, viewportX, viewportY, cursorY, columnWidth, sliderRects}
---@return number The updated cursorY position
function AudioSettings.render(params)
    local fonts = params.fonts
    local settings = params.settings
    local viewportX = params.viewportX
    local viewportY = params.viewportY
    local cursorY = params.cursorY
    local columnWidth = params.columnWidth
    local sliderRects = params.sliderRects

    local windowColors = theme.colors.window or {}
    local headingColor = windowColors.title_text or { 0.9, 0.92, 0.96, 1 }

    -- Heading
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(headingColor)
    love.graphics.print("Audio", viewportX, viewportY + cursorY)
    cursorY = cursorY + fonts.title:getHeight() + 12

    -- Sliders
    local sliderHeight = 10
    local sliderWidth = columnWidth

    local sliders = {
        { label = "Master Volume", key = "masterVolume" },
        { label = "Music Volume", key = "musicVolume" },
        { label = "Effects Volume", key = "sfxVolume" },
    }

    for _, slider in ipairs(sliders) do
        cursorY = cursorY + fonts.body:getHeight() + 6
        draw_slider(fonts, slider.label, {
            x = viewportX,
            y = viewportY + cursorY,
            w = sliderWidth,
            h = sliderHeight,
        }, settings[slider.key], sliderRects)
        cursorY = cursorY + sliderHeight + 40
    end

    return cursorY
end

--- Handles mouse interaction for volume sliders
---@param state table The options UI state
---@param settings table The settings table
---@param mouseX number Mouse X position
---@param mouseY number Mouse Y position
---@param isMouseDown boolean Whether mouse is pressed
---@param justPressed boolean Whether mouse was just pressed
---@return boolean Whether any slider changed
function AudioSettings.handleInteraction(state, settings, mouseX, mouseY, isMouseDown, justPressed)
    if not isMouseDown then
        return false
    end

    local changed = false

    local function update_slider(label, key)
        local rect = state._sliderRects[label]
        if not rect then
            return false
        end

        local function point_in_rect(x, y, r)
            return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
        end

        if justPressed and point_in_rect(mouseX, mouseY, rect) then
            state.activeSlider = label
        end

        if state.activeSlider == label then
            local localX = math.max(rect.x, math.min(rect.x + rect.w, mouseX))
            settings[key] = clamp01((localX - rect.x) / rect.w)
            return true
        end

        return false
    end

    changed = update_slider("Master Volume", "masterVolume") or changed
    changed = update_slider("Music Volume", "musicVolume") or changed
    changed = update_slider("Effects Volume", "sfxVolume") or changed

    if changed then
        AudioSettings.apply(settings)
    end

    return changed
end

return AudioSettings
