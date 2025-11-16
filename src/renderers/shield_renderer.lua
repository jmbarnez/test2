---@diagnostic disable: undefined-global

-- Shared shield renderer used across entities that support shield or hull
-- impact pulses. Accepts optional configuration to override colors or radius
-- calculations while keeping sensible defaults for ships.
local shield_renderer = {}

local DEFAULTS = {
    shieldRingColor = { 0.35, 0.95, 1.0, 0.85 },
    shieldGlowColor = { 0.18, 0.7, 1.0, 0.9 },
    shieldImpactColor = { 0.82, 0.98, 1.0, 1.0 },
    hullGlowColor = { 0.85, 0.9, 1.0, 0.85 },
}

local function resolve_shield(entity)
    if not entity then
        return nil
    end

    local shield = entity.shield
    if type(shield) == "table" then
        return shield
    end

    if entity.health and type(entity.health.shield) == "table" then
        return entity.health.shield
    end

    return nil
end

local function resolve_colors(options)
    options = options or {}

    return {
        shieldGlow = options.shieldGlowColor or DEFAULTS.shieldGlowColor,
        shieldImpact = options.shieldImpactColor or DEFAULTS.shieldImpactColor,
        hullGlow = options.hullGlowColor or DEFAULTS.hullGlowColor,
    }
end

--- Draw shield/hull impact pulses for an entity.
-- @param entity table Entity containing impact pulse data
-- @param options table|nil Optional configuration overrides:
--   * fallbackRadius: number
--   * resolveDrawableRadius: fun(entity, drawable):number
--   * shieldGlowColor, shieldImpactColor, hullGlowColor: {r,g,b,a}
function shield_renderer.draw(entity, options)
    if not entity or not entity.position then
        return
    end

    local pulses = entity.impactPulses
    if type(pulses) ~= "table" or #pulses == 0 then
        return
    end

    local colors = resolve_colors(options)
    local shield = resolve_shield(entity)

    local fallbackRadius = options and options.fallbackRadius
    if not fallbackRadius and options and type(options.resolveDrawableRadius) == "function" then
        fallbackRadius = options.resolveDrawableRadius(entity, entity.drawable)
    end

    fallbackRadius = fallbackRadius
        or (shield and shield.visualRadius)
        or entity.mountRadius
        or entity.radius
        or 48

    love.graphics.push("all")
    love.graphics.translate(entity.position.x or 0, entity.position.y or 0)
    love.graphics.setBlendMode("add")

    local rotation = entity.rotation or 0
    local cosRotation
    local sinRotation
    if rotation ~= 0 then
        cosRotation = math.cos(rotation)
        sinRotation = math.sin(rotation)
    end

    ---@type love.Shader|nil
    local shader = options and options.shader or nil
    if shader == nil and type(options) == "table" then
        shader = options.shader -- preserve explicit nil
    end

    local invM11, invM12, invM21, invM22
    local shipCenterX, shipCenterY = love.graphics.transformPoint(0, 0)
    local axisXx, axisXy = love.graphics.transformPoint(1, 0)
    axisXx = axisXx - shipCenterX
    axisXy = axisXy - shipCenterY
    local axisYx, axisYy = love.graphics.transformPoint(0, 1)
    axisYx = axisYx - shipCenterX
    axisYy = axisYy - shipCenterY

    if shader then
        local det = axisXx * axisYy - axisXy * axisYx
        if math.abs(det) > 1e-6 then
            local invDet = 1 / det
            invM11 = axisYy * invDet
            invM12 = -axisXy * invDet
            invM21 = -axisYx * invDet
            invM22 = axisXx * invDet
            shader:send("shipCenter", { shipCenterX, shipCenterY })
            shader:send("invShipMatrix", { invM11, invM12, invM21, invM22 })
            shader:send("time", love.timer.getTime())
        else
            shader = nil
        end
    end

    for i = 1, #pulses do
        local pulse = pulses[i]
        local radius = math.max(pulse.radius or fallbackRadius, fallbackRadius)
        local waveRadius = pulse.waveRadius or radius
        local waveThickness = pulse.waveThickness or 3
        local waveAlpha = pulse.waveAlpha or 0
        local ringAlpha = pulse.ringAlpha or 0
        local glowAlpha = pulse.glowAlpha or 0
        local coreAlpha = pulse.coreAlpha or 0
        local impactX = pulse.impactWorldX
        local impactY = pulse.impactWorldY

        if not (impactX and impactY) then
            local legacyX = pulse.impactX or 0
            local legacyY = pulse.impactY or 0

            if cosRotation and sinRotation then
                impactX = legacyX * cosRotation - legacyY * sinRotation
                impactY = legacyX * sinRotation + legacyY * cosRotation
            else
                impactX = legacyX
                impactY = legacyY
            end
        end

        local intensity = pulse.intensity or 0.4
        local progress = pulse.progress or 0

        local pulseType = pulse.pulseType or "shield"
        local impactColor = pulseType == "hull" and colors.hullGlow or colors.shieldImpact
        local glowColor = pulseType == "hull" and colors.hullGlow or colors.shieldGlow

        if shader then
            shader:send("impactLocal", { impactX, impactY })
            shader:send("shieldRadius", radius)
            shader:send("waveRadius", waveRadius)
            shader:send("waveThickness", waveThickness)
            shader:send("impactIntensity", intensity)
            shader:send("glowAlpha", glowAlpha)
            shader:send("waveAlpha", waveAlpha)
            shader:send("ringAlpha", ringAlpha)
            shader:send("coreAlpha", coreAlpha)
            shader:send("progress", progress)
            shader:send("impactColor", {
                impactColor[1],
                impactColor[2],
                impactColor[3],
                impactColor[4] or 1,
            })
            shader:send("glowColor", {
                glowColor[1],
                glowColor[2],
                glowColor[3],
                glowColor[4] or 1,
            })

            love.graphics.setShader(shader)
            love.graphics.setColor(1, 1, 1, 1)
            local renderRadius = math.max(radius * 1.3, waveRadius + waveThickness * 2.2)
            love.graphics.circle("fill", 0, 0, renderRadius)
            love.graphics.setShader()
        else
            if glowAlpha > 0.01 then
                love.graphics.setColor(
                    glowColor[1],
                    glowColor[2],
                    glowColor[3],
                    glowAlpha * 0.35
                )
                love.graphics.circle("fill", 0, 0, radius * 1.12)

                love.graphics.setColor(
                    glowColor[1],
                    glowColor[2],
                    glowColor[3],
                    glowAlpha * 0.2
                )
                love.graphics.circle("fill", 0, 0, radius * 1.25)
            end
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return shield_renderer
