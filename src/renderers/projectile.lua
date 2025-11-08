local love = love

local projectile_renderer = {}

function projectile_renderer.draw(entity)
    if not (entity and entity.position and entity.drawable) then
        return
    end

    local x = entity.position.x
    local y = entity.position.y
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

        love.graphics.pop()
        return
    end

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

    love.graphics.pop()
end

return projectile_renderer
