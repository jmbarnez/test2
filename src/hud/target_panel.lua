local theme = require("src.ui.theme")
local PlayerManager = require("src.player.manager")
local Util = require("src.hud.util")
local vector = require("src.util.vector")

---@diagnostic disable-next-line: undefined-global
local love = love

local function resolve_level(entity)
    if not entity then
        return nil
    end

    local level = entity.level
    if type(level) == "table" then
        level = level.current or level.value or level.level
    end

    if not level and entity.pilot and type(entity.pilot.level) == "table" then
        level = entity.pilot.level.current or entity.pilot.level.value
    end

    if type(level) == "number" then
        return math.max(0, math.floor(level + 0.5))
    end

    return nil
end

local function resolve_speed(entity)
    if not entity then
        return 0
    end

    if entity.body and not entity.body:isDestroyed() then
        local vx, vy = entity.body:getLinearVelocity()
        return vector.length(vx, vy)
    end

    if entity.velocity then
        return vector.length(entity.velocity.x or 0, entity.velocity.y or 0)
    end

    return 0
end

local function resolve_distance(player, target)
    if not (player and player.position and target and target.position) then
        return nil
    end

    local dx = (target.position.x or 0) - (player.position.x or 0)
    local dy = (target.position.y or 0) - (player.position.y or 0)
    return vector.length(dx, dy)
end

local function format_number(value)
    if not value then
        return "--"
    end

    if value >= 1000 then
        return string.format("%.0fk", value / 1000)
    elseif value >= 100 then
        return string.format("%.0f", value)
    else
        return string.format("%.1f", value)
    end
end

local TargetPanel = {}

function TargetPanel.draw(context, player)
    context = context or {}
    local state = context.state or context
    local cache = state and state.targetingCache
    local active = cache and cache.activeEntity
    local hovered = cache and cache.hoveredEntity
    local target = active or hovered or (cache and cache.entity)

    if not target then
        return
    end

    local targetPos = target.position
    if not targetPos then
        return
    end

    local fonts = theme.get_fonts()
    if not fonts then
        return
    end

    local isLocked = active ~= nil and target == active
    local isEnemy = not not target.enemy
    local showFullPanel = (not isEnemy) or isLocked

    local hud_colors = theme.colors.hud or {}
    local set_color = theme.utils.set_color
    local spacing = theme.spacing or {}

    local padding = math.min(10, spacing.window_padding or 10)
    local width = 280
    local height = showFullPanel and 96 or 68
    local screenWidth = love.graphics.getWidth()

    local x = (screenWidth - width) * 0.5
    local y = 18

    local playerShip = player or PlayerManager.getCurrentShip(state)

    local hull_current, hull_max = Util.resolve_resource(target.health)
    local shield_current, shield_max = Util.resolve_resource(target.shield or target.shields or (target.health and target.health.shield))

    if not (hull_current and hull_max) then
        return
    end

    local name = target.name
        or (target.blueprint and (target.blueprint.name or target.blueprint.id))
        or "Unknown Target"

    set_color(hud_colors.status_panel or { 0.05, 0.06, 0.09, 0.95 })
    love.graphics.rectangle("fill", x, y, width, height)

    set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)

    local text_x = x + padding
    local text_width = width - padding * 2

    if showFullPanel then
        local level = resolve_level(target)
        local distance = resolve_distance(playerShip, target)
        local speed = resolve_speed(target)

        local name = target.name
            or (target.blueprint and (target.blueprint.name or target.blueprint.id))
            or "Unknown Target"

        love.graphics.setFont(fonts.body)
        set_color(hud_colors.status_text or hud_colors.diagnostics or { 0.82, 0.88, 0.93, 1 })
        love.graphics.printf(name, text_x, y + padding, text_width, "left")

        local info_y = y + padding + fonts.body:getHeight() + 4

        love.graphics.setFont(fonts.small)
        set_color(hud_colors.status_muted or { 0.6, 0.66, 0.72, 1 })

        local levelText = level and string.format("Lv %d", level) or "Lv --"
        local distanceText = string.format("Dist %s", distance and format_number(distance) or "--")
        local speedText = string.format("Speed %s", format_number(speed))

        love.graphics.print(levelText, text_x, info_y)
        love.graphics.printf(distanceText, text_x, info_y, text_width, "center")
        love.graphics.printf(speedText, text_x, info_y, text_width, "right")

        local bar_y = info_y + fonts.small:getHeight() + 6
        local bar_height = 12
        local bar_width = text_width

        set_color(hud_colors.status_bar_background or { 0.09, 0.1, 0.14, 1 })
        love.graphics.rectangle("fill", text_x, bar_y, bar_width, bar_height)

        local hull_pct = Util.clamp01(hull_current / hull_max)
        if hull_pct > 0 then
            set_color(hud_colors.hull_fill or { 0.85, 0.4, 0.38, 1 })
            love.graphics.rectangle("fill", text_x + 1, bar_y + 1, (bar_width - 2) * hull_pct, bar_height - 2)
        end

        local shield_pct = 0
        if shield_current and shield_max and shield_max > 0 then
            shield_pct = Util.clamp01(shield_current / shield_max)
        end

        if shield_pct > 0 then
            set_color(hud_colors.shield_fill or { 0.3, 0.6, 0.95, 1 })
            love.graphics.rectangle("fill", text_x + 1, bar_y + 1, (bar_width - 2) * shield_pct, (bar_height - 2) * 0.5)
        end

        set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", text_x + 0.5, bar_y + 0.5, bar_width - 1, bar_height - 1)

        local textBottomY = bar_y + bar_height + 5
        love.graphics.setFont(fonts.tiny or fonts.small)
        set_color(hud_colors.status_text or { 0.82, 0.88, 0.93, 1 })

        local hullText = Util.format_resource(hull_current, hull_max)
        local shieldText = (shield_current and shield_max and shield_max > 0)
            and Util.format_resource(shield_current, shield_max)
            or "--"

        love.graphics.print("Hull", text_x, textBottomY)
        love.graphics.printf(hullText, text_x, textBottomY, text_width, "right")

        local shieldLabelY = textBottomY + (fonts.tiny and fonts.tiny:getHeight() or fonts.small:getHeight()) + 2
        love.graphics.print("Shield", text_x, shieldLabelY)
        love.graphics.printf(shieldText, text_x, shieldLabelY, text_width, "right")

        return
    end

    -- Health-only presentation when target is merely hovered and is an enemy
    local bar_height = 14
    local bar_width = text_width
    local bar_y = y + padding

    set_color(hud_colors.status_bar_background or { 0.09, 0.1, 0.14, 1 })
    love.graphics.rectangle("fill", text_x, bar_y, bar_width, bar_height)

    local hull_pct = Util.clamp01(hull_current / hull_max)
    if hull_pct > 0 then
        set_color(hud_colors.hull_fill or { 0.85, 0.4, 0.38, 1 })
        love.graphics.rectangle("fill", text_x + 1, bar_y + 1, (bar_width - 2) * hull_pct, bar_height - 2)
    end

    local shield_pct = 0
    if shield_current and shield_max and shield_max > 0 then
        shield_pct = Util.clamp01(shield_current / shield_max)
    end

    if shield_pct > 0 then
        set_color(hud_colors.shield_fill or { 0.3, 0.6, 0.95, 1 })
        love.graphics.rectangle("fill", text_x + 1, bar_y + 1, (bar_width - 2) * shield_pct, (bar_height - 2) * 0.5)
    end

    set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", text_x + 0.5, bar_y + 0.5, bar_width - 1, bar_height - 1)

    love.graphics.setFont(fonts.small)
    set_color(hud_colors.status_text or { 0.82, 0.88, 0.93, 1 })

    local label_y = bar_y + bar_height + 6
    love.graphics.print("Hull", text_x, label_y)
    love.graphics.printf(Util.format_resource(hull_current, hull_max), text_x, label_y, text_width, "right")

    if shield_pct > 0 then
        local shieldLabelY = label_y + fonts.small:getHeight() + 4
        love.graphics.print("Shield", text_x, shieldLabelY)
        love.graphics.printf(Util.format_resource(shield_current, shield_max), text_x, shieldLabelY, text_width, "right")
    end

end

return TargetPanel
