---@diagnostic disable: undefined-global

-- Shared HUD health bar renderer. Draws entity health bars and optional level
-- badges. Primarily used for NPC ships but can be reused by other entities
-- that expose the same health metadata.
local hud_health_bar = {}

local DEFAULTS = {
    width = 60,
    height = 5,
    offset = 32,
    showDuration = 0,
}

local function resolve_entity_level(entity)
    if not entity then
        return nil
    end

    local level = entity.level
    if type(level) == "table" then
        level = level.current or level.value or level.level
    end

    if not level and entity.pilot and type(entity.pilot.level) == "table" then
        level = entity.pilot.level.current or entity.pilot.level.value or entity.pilot.level.level
    end

    if type(level) == "number" then
        local rounded = math.floor(level + 0.5)
        if rounded > 0 then
            return rounded
        end
    end

    return nil
end

--- Draw an entity health bar above the entity.
-- @param entity table Entity containing health data.
-- @param options table|nil Optional overrides: width, height, offset,
--                           showDuration, color, backgroundColor.
function hud_health_bar.draw(entity, options)
    local health = entity and entity.health
    if not (health and health.max and health.max > 0) then
        return
    end

    if entity.player or entity.healthBar == false then
        return
    end

    local defaults = (options and options.defaults) or DEFAULTS
    local config = entity.healthBar or {}

    local showTimer = health.showTimer or 0
    local showDuration = config.showDuration or defaults.showDuration or DEFAULTS.showDuration or 0
    if showDuration > 0 and showTimer <= 0 then
        return
    end

    local pct = math.max(0, math.min(1, (health.current or 0) / health.max))
    local baseWidth = config.width or defaults.width or DEFAULTS.width
    local width = baseWidth * 0.5
    local height = config.height or defaults.height or DEFAULTS.height
    local offset = math.abs(config.offset or defaults.offset or DEFAULTS.offset)
    local halfWidth = width * 0.5

    local alpha = 1
    if showDuration > 0 then
        alpha = math.min(1, showTimer / showDuration)
    end

    if alpha <= 0 then
        return
    end

    local backgroundColor = config.backgroundColor or defaults.backgroundColor or { 0, 0, 0, 0.55 * alpha }
    local healthColor = config.fillColor or defaults.fillColor or { 0.35, 1, 0.6, alpha }
    local borderColor = config.borderColor or defaults.borderColor or { 0, 0, 0, 0.9 * alpha }

    love.graphics.push()
    love.graphics.translate(entity.position.x, entity.position.y - offset)

    love.graphics.setColor(backgroundColor)
    love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width, height)

    if pct > 0 then
        love.graphics.setColor(healthColor)
        love.graphics.rectangle("fill", -halfWidth, -height * 0.5, width * pct, height)
    end

    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", -halfWidth, -height * 0.5, width, height)

    local level = resolve_entity_level(entity)
    if level then
        local font = love.graphics.getFont()
        local text = tostring(level)
        local paddingX, paddingY = 3, 2
        local textWidth = font and font:getWidth(text) or (#text * 6)
        local textHeight = font and font:getHeight() or 10
        local badgeWidth = textWidth + paddingX * 2
        local badgeHeight = math.max(textHeight + paddingY * 2, height)
        local badgeX = halfWidth + 6
        local badgeY = -badgeHeight * 0.5

        love.graphics.setColor(backgroundColor)
        love.graphics.rectangle("fill", badgeX, badgeY, badgeWidth, badgeHeight)

        love.graphics.setColor(borderColor)
        love.graphics.rectangle("line", badgeX, badgeY, badgeWidth, badgeHeight)

        love.graphics.setColor(0.82, 0.88, 0.93, alpha)
        love.graphics.print(text, badgeX + paddingX, badgeY + paddingY)
    end

    love.graphics.pop()
end

return hud_health_bar
