-- Projectile renderer
-- Draws projectiles (orbs, beams, missiles) and optional travel indicators
local love = love

local projectile_renderer = {}

--- Draw a projectile entity with its visual style. Handles beams, missiles
--- and default orb-like projectiles, and draws a motion trail if present.
-- @param entity table projectile entity
function projectile_renderer.draw(entity)
    if not (entity and entity.position and entity.drawable) then
        return
    end

    local x = entity.position.x
    local y = entity.position.y
    local indicator = entity.travelIndicator
    if indicator and indicator.x and indicator.y and indicator.radius and indicator.radius > 0 then
        love.graphics.push("all")
        love.graphics.setBlendMode("add")

        indicator.timer = (indicator.timer or 0) + (love.timer and love.timer.getDelta() or 0)
        local outline = indicator.outlineColor or { 0.82, 0.96, 1.0, 0.85 }
        local inner = indicator.innerColor or { 0.62, 0.86, 1.0, 0.38 }
        local radius = math.max(indicator.radius, 6)
        local pulse = 1 + 0.08 * math.sin((indicator.timer or 0) * 4.2)
        local outerRadius = radius * pulse

        love.graphics.setLineWidth(2.4)
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4])
        love.graphics.circle("line", indicator.x or x, indicator.y or y, outerRadius)

        love.graphics.setLineWidth(1.2)
        love.graphics.setColor(inner[1], inner[2], inner[3], inner[4])
        local innerRadius = radius * 0.58 + 2.5 * math.sin((indicator.timer or 0) * 5.2)
        love.graphics.circle("line", indicator.x or x, indicator.y or y, math.max(4, innerRadius))

        love.graphics.pop()
    end

    local drawable = entity.drawable
    local size = drawable.size or 6
    local color = drawable.color or { 0.2, 0.8, 1.0 }
    local glowColor = drawable.glowColor or { 0.5, 0.9, 1.0 }
    local coreColor = drawable.coreColor or color
    local highlightColor = drawable.highlightColor or coreColor

    local outerAlpha = drawable.outerAlpha or 0.45
    local innerAlpha = drawable.innerAlpha or math.min(1, outerAlpha + 0.25)
    local coreAlpha = drawable.coreAlpha or 1
    local highlightAlpha = drawable.highlightAlpha or 1

    local outerScale = drawable.outerScale or 1.6
    local innerScale = drawable.innerScale or 1.0
    local coreScale = drawable.coreScale or 0.65
    local highlightScale = drawable.highlightScale or 0.35

    local shape = drawable.shape or drawable.form or "orb"

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    if shape == "beam" then
        local vx = entity.velocity and entity.velocity.x or 0
        local vy = entity.velocity and entity.velocity.y or 0
        local angle
        if vx ~= 0 or vy ~= 0 then
            angle = math.atan2(vy, vx)
        else
            angle = (entity.rotation or 0) - math.pi * 0.5
        end

        local baseWidth = drawable.width or size
        local length = drawable.length or drawable.beamLength
        if not length then
            local lengthScale = drawable.lengthScale or 7
            length = baseWidth * lengthScale
        end

        local halfLength = length * 0.5
        local outerWidth = baseWidth * outerScale
        local innerWidth = baseWidth * innerScale
        local coreWidth = baseWidth * coreScale
        local highlightWidth = baseWidth * highlightScale

        love.graphics.translate(x, y)
        love.graphics.rotate(angle)

        -- Outer glow rectangle
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], outerAlpha)
        love.graphics.rectangle("fill", -halfLength, -outerWidth * 0.5, length, outerWidth)

        -- Middle glow rectangle
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], innerAlpha)
        love.graphics.rectangle("fill", -halfLength, -innerWidth * 0.5, length, innerWidth)

        -- Core beam
        love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], coreAlpha)
        love.graphics.rectangle("fill", -halfLength, -coreWidth * 0.5, length, coreWidth)

        -- Highlight streak
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], highlightAlpha)
        love.graphics.rectangle("fill", -halfLength, -highlightWidth * 0.5, length, highlightWidth)

    elseif shape == "flame" then
        local vx = entity.velocity and entity.velocity.x or 0
        local vy = entity.velocity and entity.velocity.y or 0
        local angle
        if vx ~= 0 or vy ~= 0 then
            angle = math.atan2(vy, vx)
        else
            angle = (entity.rotation or 0) - math.pi * 0.5
        end

        local length = drawable.length or size * 5.2
        local width = drawable.width or size * 1.6
        local innerLength = drawable.innerLength or length * 0.85
        local coreLength = drawable.coreLength or length * 0.65
        local highlightLength = drawable.highlightLength or length * 0.5
        local tailLength = drawable.tailLength or length * 0.28
        local tipScale = drawable.tipScale or 0.22
        local wobbleScale = drawable.wobbleScale or 0.3
        local flickerSpeed = drawable.flickerSpeed or 13.0
        local flickerAmount = drawable.flickerAmount or 0.18

        local seed = entity._flameSeed
        if not seed then
            if love and love.math and love.math.random then
                seed = love.math.random() * math.pi * 2
            else
                seed = math.random() * math.pi * 2
            end
            entity._flameSeed = seed
        end

        local time = love.timer and love.timer.getTime and love.timer.getTime() or 0
        local flicker = math.sin(time * flickerSpeed + seed) * flickerAmount

        local outerWidth = width
        local innerWidth = drawable.innerWidth or width * 0.72
        local coreWidth = drawable.coreWidth or width * 0.42
        local highlightWidth = drawable.highlightWidth or width * 0.24

        love.graphics.translate(x, y)
        love.graphics.rotate(angle)

        local function draw_flame_layer(layerLength, baseWidth, colorVec, alpha, tipFactor)
            if not colorVec then
                return
            end
            local wobble = 1 + flicker * wobbleScale
            local tipWidth = math.max(baseWidth * (tipFactor or tipScale), baseWidth * 0.08)
            local forward = layerLength
            local mid = forward * 0.6
            local tail = -tailLength

            love.graphics.setColor(colorVec[1], colorVec[2], colorVec[3], alpha)
            love.graphics.polygon("fill",
                tail, 0,
                0, -baseWidth * wobble * 0.52,
                mid, -tipWidth * (1 + flicker * 0.35),
                forward, 0,
                mid, tipWidth * (1 + flicker * 0.35),
                0, baseWidth * wobble * 0.52
            )
        end

        draw_flame_layer(length, outerWidth, glowColor, outerAlpha, drawable.tipScale)
        draw_flame_layer(innerLength, innerWidth, glowColor, innerAlpha, (drawable.innerTipScale or tipScale * 0.9))
        draw_flame_layer(coreLength, coreWidth, coreColor, coreAlpha, (drawable.coreTipScale or tipScale * 0.7))
        draw_flame_layer(highlightLength, highlightWidth, highlightColor, highlightAlpha, (drawable.highlightTipScale or tipScale * 0.55))

    elseif shape == "missile" then
        local length = drawable.length or size * 4.2
        local width = drawable.width or size * 0.9
        local halfWidth = width * 0.5
        local glowThickness = drawable.glowThickness or width
        local finLength = drawable.finLength or length * 0.28

        local bodyColor = drawable.bodyColor or color
        local noseColor = drawable.noseColor or highlightColor
        local finColor = drawable.finColor or glowColor
        local outlineColor = drawable.outlineColor or { 0, 0, 0, 0.75 }
        local exhaustColor = drawable.exhaustColor or { 1.0, 0.9, 0.7, 0.8 }
        local glow = drawable.glowColor or glowColor

        local vx = entity.velocity and entity.velocity.x or 0
        local vy = entity.velocity and entity.velocity.y or 0
        local angle
        if vx ~= 0 or vy ~= 0 then
            angle = math.atan2(vy, vx)
        else
            angle = (entity.rotation or 0) - math.pi * 0.5
        end

        love.graphics.translate(x, y)
        love.graphics.rotate(angle)

        love.graphics.setColor(glow[1], glow[2], glow[3], glow[4] or 0.4)
        love.graphics.rectangle("fill", -length * 0.55, -glowThickness * 0.5, length * 1.1, glowThickness)

        love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], bodyColor[4] or 1)
        love.graphics.rectangle("fill", -length * 0.4, -halfWidth, length * 0.7, width)

        love.graphics.setColor(finColor[1], finColor[2], finColor[3], finColor[4] or 1)
        local finY = halfWidth + width * 0.35
        love.graphics.polygon("fill",
            -length * 0.25, -halfWidth,
            -length * 0.25 - finLength, -finY,
            -length * 0.15, -halfWidth * 0.4)
        love.graphics.polygon("fill",
            -length * 0.25, halfWidth,
            -length * 0.25 - finLength, finY,
            -length * 0.15, halfWidth * 0.4)

        love.graphics.setColor(noseColor[1], noseColor[2], noseColor[3], noseColor[4] or 1)
        love.graphics.polygon("fill",
            length * 0.3, 0,
            -length * 0.15, -halfWidth,
            -length * 0.15, halfWidth)

        love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 1)
        love.graphics.setLineWidth(1.6)
        love.graphics.rectangle("line", -length * 0.4, -halfWidth, length * 0.7, width)
        love.graphics.polygon("line",
            length * 0.3, 0,
            -length * 0.15, -halfWidth,
            -length * 0.15, halfWidth)

        love.graphics.setColor(exhaustColor[1], exhaustColor[2], exhaustColor[3], exhaustColor[4] or 1)
        love.graphics.circle("fill", -length * 0.45, 0, width * 0.42)

    else

        -- Outer glow
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], outerAlpha)
        love.graphics.circle("fill", x, y, size * outerScale)

        -- Middle glow
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], innerAlpha)
        love.graphics.circle("fill", x, y, size * innerScale)

        -- Core
        love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], coreAlpha)
        love.graphics.circle("fill", x, y, size * coreScale)

        -- Bright center
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], highlightAlpha)
        love.graphics.circle("fill", x, y, size * highlightScale)
    end

    love.graphics.pop()

    local trail = entity.projectileTrail
    if trail and trail.points and #trail.points > 1 then
        local baseColor = trail.color or { 1.0, 0.8, 0.4, 0.8 }
        local fadeColor = trail.fadeColor or { baseColor[1], baseColor[2], baseColor[3], 0 }
        local width = trail.width or 3

        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        love.graphics.setLineJoin("bevel")

        for i = 1, #trail.points - 1 do
            local p1 = trail.points[i]
            local p2 = trail.points[i + 1]
            local t1 = (p1.life or 0) / (p1.maxLife or 1)
            local r = fadeColor[1] + (baseColor[1] - fadeColor[1]) * t1
            local g = fadeColor[2] + (baseColor[2] - fadeColor[2]) * t1
            local b = fadeColor[3] + (baseColor[3] - fadeColor[3]) * t1
            local a = fadeColor[4] + (baseColor[4] - fadeColor[4]) * t1
            love.graphics.setColor(r, g, b, a)
            love.graphics.setLineWidth(width * t1)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end

        love.graphics.pop()
    end
end

return projectile_renderer
