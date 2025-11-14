---@diagnostic disable: undefined-global

local ship_renderer = require("src.renderers.ship")
local math_util = require("src.util.math")

local station_renderer = {}

local function clamp_color_component(value, fallback)
    local number = tonumber(value)
    if not number then
        return fallback
    end
    return math_util.clamp(number, 0, 1)
end

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
