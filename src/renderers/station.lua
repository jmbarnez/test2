---@diagnostic disable: undefined-global
-- Station renderer
-- Builds on ship renderer to show station-specific overlays like
-- influence rings and optional fill/accents.
local ship_renderer = require("src.renderers.ship")
local math_util = require("src.util.math")

local station_renderer = {}

--- Clamp a numeric component to [0, 1], falling back when invalid.
local function clamp_color_component(value, fallback)
    local number = tonumber(value)
    if not number then
        return fallback
    end
    return math_util.clamp(number, 0, 1)
end

--- Apply a color to love.graphics, using a fallback if the color is invalid.
local function apply_color(color, fallback)
    if type(color) ~= "table" then
        if fallback then
            love.graphics.setColor(fallback[1], fallback[2], fallback[3], fallback[4])
        end
        return
    end

    local r = clamp_color_component(color[1], 1)
    local g = clamp_color_component(color[2], 1)
    local b = clamp_color_component(color[3], 1)
    local a = clamp_color_component(color[4], 1)
    love.graphics.setColor(r, g, b, a)
end

--- Modulate a color by brightness and alpha multiplier returning a new RGBA color table.
local function modulate_color(color, brightness, alphaScale)
    if type(color) ~= "table" then
        return nil
    end

    brightness = brightness or 1
    alphaScale = alphaScale or 1

    local r = clamp_color_component(color[1] and color[1] * brightness, color[1] or 1)
    local g = clamp_color_component(color[2] and color[2] * brightness, color[2] or 1)
    local b = clamp_color_component(color[3] and color[3] * brightness, color[3] or 1)
    local a = clamp_color_component((color[4] or 1) * alphaScale, color[4] or 1)

    return { r, g, b, a }
end

--- Draws the station influence ring (optional glow/accents) around the station.
-- The ring shows active/inactive states and adapts color/alpha.
local function draw_influence_ring(entity, context)
    local influence = entity and entity.stationInfluence
    if not influence then
        return
    end

    local position = entity.position
    if not (position and position.x and position.y) then
        return
    end

    local radius = influence.radius or entity.influenceRadius
    if not (radius and radius > 0) then
        return
    end

    local lineWidth = influence.lineWidth or 2
    local accentOffset = influence.accentOffset or math.max(6, lineWidth * 2)

    local isActive = entity.stationInfluenceActive
    if not isActive and context and context.state and context.state.playerUnderStationInfluence then
        isActive = context.state.stationInfluenceSource == entity
    end

    local fallbackColor = influence.fallbackColor or { 0.18, 0.46, 0.78, 0.22 }
    local baseColor = (isActive and influence.activeColor) or influence.color or fallbackColor
    local accentColor = influence.accentColor or baseColor or fallbackColor

    if isActive then
        local activeBrightness = influence.activeBrightness or 1.35
        local activeAlpha = influence.activeAlpha or 1.25
        baseColor = modulate_color(baseColor, activeBrightness, activeAlpha) or baseColor
        accentColor = modulate_color(accentColor, influence.activeAccentBrightness or 1.15, influence.activeAccentAlpha or 1.1) or accentColor
    end

    love.graphics.push("all")

    love.graphics.setLineWidth(lineWidth)
    apply_color(baseColor, fallbackColor)
    love.graphics.circle("line", position.x, position.y, radius)

    if accentOffset and accentOffset > 0 then
        love.graphics.setLineWidth(lineWidth * 0.65)
        apply_color(accentColor, baseColor or fallbackColor)
        love.graphics.circle("line", position.x, position.y, radius + accentOffset)
    end

    if influence.fillAlpha and influence.fillAlpha > 0 then
        local fillColor = influence.fillColor or baseColor or fallbackColor
        apply_color({
            fillColor[1],
            fillColor[2],
            fillColor[3],
            clamp_color_component(influence.fillAlpha, 0.15),
        }, baseColor or fallbackColor)
        love.graphics.circle("line", position.x, position.y, radius - math.max(1, lineWidth * 1.2))
    end

    if isActive then
        local time = love.timer and love.timer.getTime and love.timer.getTime() or 0
        local pulseSpeed = influence.glowPulseSpeed or 2.6
        local pulse = 0.78 + 0.22 * math.sin(time * pulseSpeed)
        local glowAlpha = (influence.glowAlpha or 0.45) * pulse
        local glowWidth = math.max(lineWidth * 1.8, 4)
        local glowRadiusOffset = influence.glowRadiusOffset or (accentOffset or lineWidth * 2)

        love.graphics.setBlendMode("add")
        love.graphics.setLineWidth(glowWidth)
        apply_color({
            baseColor[1] or fallbackColor[1],
            baseColor[2] or fallbackColor[2],
            baseColor[3] or fallbackColor[3],
            glowAlpha,
        }, baseColor or fallbackColor)
        love.graphics.circle("line", position.x, position.y, radius + glowRadiusOffset * 0.45)

        love.graphics.setLineWidth(glowWidth * 0.7)
        apply_color({
            accentColor[1] or fallbackColor[1],
            accentColor[2] or fallbackColor[2],
            accentColor[3] or fallbackColor[3],
            glowAlpha * 0.7,
        }, accentColor or baseColor)
        love.graphics.circle("line", position.x, position.y, radius + glowRadiusOffset)

        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
end

---Draws a station entity using shared ship body rendering while allowing
---station-specific overlays in the future.
---@param entity table
---@param context table|nil
function station_renderer.draw(entity, context)
    draw_influence_ring(entity, context)

    if not ship_renderer.draw_body(entity, context) then
        return
    end

    ship_renderer.draw_shield_pulses(entity)

    -- Additional station overlays can be rendered here in the future.
end

return station_renderer
