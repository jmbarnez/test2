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

local function resolve_range_profile(entity)
    if not entity then
        return nil, nil, nil, nil
    end

    local ai = entity.ai or {}
    local stats = entity.stats or {}
    local weapon = entity.weapon
    local weaponRange = weapon and weapon.maxRange or nil

    local detection = ai.detectionRange
        or stats.detection_range
        or ai.engagementRange
        or stats.max_range
        or weaponRange
        or (ai.wanderRadius and ai.wanderRadius * 1.5)
        or nil

    local engagement = ai.engagementRange
        or stats.max_range
        or weaponRange
        or detection

    if weaponRange then
        engagement = math.min(engagement or weaponRange, weaponRange)
        detection = math.max(detection or weaponRange, weaponRange * 1.1)
    end

    if not detection and engagement then
        detection = engagement
    end
    if not engagement and detection then
        engagement = detection
    end

    local preferred = ai.preferredDistance
        or stats.preferred_distance
        or (engagement and engagement * 0.85 or nil)

    return detection, engagement, preferred, weaponRange
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

local function resolve_behavior_label(target)
    if not target then
        return nil
    end

    local ai = target.ai
    if type(ai) ~= "table" then
        return nil
    end

    local behavior = ai.behavior or ai.mode or ai.pattern
    if type(behavior) ~= "string" or behavior == "" then
        return nil
    end

    behavior = behavior:gsub("_", " ")
    local first = behavior:sub(1, 1):upper()
    return first .. behavior:sub(2)
end

local function resolve_weapon_label(target)
    if not target then
        return nil
    end

    local weapons = target.weapons
    if type(weapons) == "table" and #weapons > 0 then
        local weapon = weapons[1]
        if type(weapon) == "table" then
            local blueprint = weapon.blueprint
            if type(blueprint) == "table" then
                if type(blueprint.name) == "string" and blueprint.name ~= "" then
                    return blueprint.name
                end
                if type(blueprint.id) == "string" and blueprint.id ~= "" then
                    local idLabel = blueprint.id:gsub("_", " ")
                    local first = idLabel:sub(1, 1):upper()
                    return first .. idLabel:sub(2)
                end
            end
        end
    end

    local component = target.weapon
    if type(component) == "table" then
        if type(component.name) == "string" and component.name ~= "" then
            return component.name
        end
        if type(component.constantKey) == "string" and component.constantKey ~= "" then
            local keyLabel = component.constantKey:gsub("_", " ")
            local first = keyLabel:sub(1, 1):upper()
            return first .. keyLabel:sub(2)
        end
    end

    return nil
end

local TargetPanel = {}

function TargetPanel.draw(context, player)
    context = context or {}
    local state = context.state or context
    local cache = state and state.targetingCache
    local active = cache and cache.activeEntity
    local hovered = cache and cache.hoveredEntity
    local target = active or hovered or (cache and cache.entity)

    local fonts = theme.get_fonts()
    if not fonts then
        return
    end

    local hud_colors = theme.colors.hud or {}
    local set_color = theme.utils.set_color
    local spacing = theme.spacing or {}

    local padding = math.min(10, spacing.window_padding or 10)
    local width = 280
    local screenWidth = love.graphics.getWidth()

    local x = (screenWidth - width) * 0.5
    local y = 18

    local playerShip = player or PlayerManager.getCurrentShip(state)
    local text_x = x + padding
    local text_width = width - padding * 2

    local targetPos = target and target.position
    local hull_current, hull_max, shield_current, shield_max
    local hasTarget = false

    if targetPos then
        hull_current, hull_max = Util.resolve_resource(target.health)
        shield_current, shield_max = Util.resolve_resource(target.shield or target.shields or (target.health and target.health.shield))
        hasTarget = hull_current ~= nil and hull_max ~= nil
    end

    local isLocked = hasTarget and active ~= nil and target == active or false
    local isEnemy = hasTarget and not not target.enemy or false
    local showFullPanel = hasTarget and ((not isEnemy) or isLocked) or false

    local height = hasTarget and (showFullPanel and 96 or 68) or 84

    local isLocking = false
    local lockProgress = 0
    local lockDuration = nil
    if hasTarget and cache and cache.lockCandidate == target and not isLocked then
        lockDuration = cache.lockDuration
        lockProgress = cache.lockProgress or 0
        if lockDuration and lockDuration > 0 then
            isLocking = lockProgress < 1
        end
    end

    set_color(hud_colors.status_panel or { 0.05, 0.06, 0.09, 0.95 })
    love.graphics.rectangle("fill", x, y, width, height)

    set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)

    if not hasTarget then
        local headingFont = fonts.small
        local detailFont = fonts.tiny or fonts.small
        local infoY = y + padding + 4

        love.graphics.setFont(headingFont)
        set_color(hud_colors.status_text or { 0.82, 0.88, 0.93, 1 })
        love.graphics.printf("No target selected", text_x, infoY, text_width, "center")

        love.graphics.setFont(detailFont)
        infoY = infoY + headingFont:getHeight() + 6
        set_color(hud_colors.status_muted or { 0.6, 0.66, 0.72, 1 })
        love.graphics.printf("Hover ships or interactable objects to preview them.", text_x, infoY, text_width, "center")

        infoY = infoY + detailFont:getHeight() + 4
        love.graphics.printf("Hold Ctrl + Left Mouse to lock enemies and reveal more intel.", text_x, infoY, text_width, "center")

        return
    end

    love.graphics.push("all")
    love.graphics.pop()

    if showFullPanel then
        local level = resolve_level(target)
        local distance = resolve_distance(playerShip, target)
        local speed = resolve_speed(target)

        love.graphics.setFont(fonts.small)
        set_color(hud_colors.status_muted or { 0.6, 0.66, 0.72, 1 })

        local info_y = y + padding

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
            local shield_color = hud_colors.shield_fill or { 0.3, 0.6, 0.95, 1 }
            love.graphics.setColor(shield_color[1], shield_color[2], shield_color[3], (shield_color[4] or 1) * 0.65)
            love.graphics.rectangle("fill", text_x + 1, bar_y + 1, (bar_width - 2) * shield_pct, bar_height - 2)

            -- Add subtle additive glow similar to player HUD shield overlay
            love.graphics.setBlendMode("add")
            love.graphics.setColor(0.45, 0.98, 1.0, 0.45)
            love.graphics.rectangle("fill", text_x + 3, bar_y + 3, math.max(0, (bar_width - 6) * shield_pct), math.max(0, bar_height - 6))
            love.graphics.setBlendMode("alpha")

            set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", text_x + 0.5, bar_y + 0.5, bar_width - 1, bar_height - 1)
        end

        set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", text_x + 0.5, bar_y + 0.5, bar_width - 1, bar_height - 1)

        local textBottomY = bar_y + bar_height + 5
        local detailFont = fonts.tiny or fonts.small
        love.graphics.setFont(detailFont)
        set_color(hud_colors.status_text or { 0.82, 0.88, 0.93, 1 })

        local hullText = Util.format_resource(hull_current, hull_max)
        local shieldText = (shield_current and shield_max and shield_max > 0)
            and Util.format_resource(shield_current, shield_max)
            or "--"

        love.graphics.print("Hull", text_x, textBottomY)
        love.graphics.printf(hullText, text_x, textBottomY, text_width, "right")

        local shieldLabelY = textBottomY + detailFont:getHeight() + 2
        love.graphics.print("Shield", text_x, shieldLabelY)
        love.graphics.printf(shieldText, text_x, shieldLabelY, text_width, "right")

        if isEnemy then
            local behaviorLabel = resolve_behavior_label(target)
            local weaponLabel = resolve_weapon_label(target)

            local arrowWidth = 16
            local arrowHeight = 10
            local arrowPadding = 6
            local arrowX = x + width - arrowPadding - arrowWidth
            local arrowY = y + height - arrowPadding - arrowHeight

            local mouseX, mouseY = love.mouse.getPosition()
            local arrowHovered = mouseX >= arrowX and mouseX <= arrowX + arrowWidth
                and mouseY >= arrowY and mouseY <= arrowY + arrowHeight

            if arrowHovered then
                set_color(hud_colors.status_text or { 0.82, 0.88, 0.93, 1 })
            else
                set_color(hud_colors.status_muted or { 0.6, 0.66, 0.72, 1 })
            end

            local arrowCenterX = arrowX + arrowWidth * 0.5
            local arrowTopY = arrowY
            local arrowBottomY = arrowY + arrowHeight
            love.graphics.polygon(
                "fill",
                arrowCenterX - arrowWidth * 0.5, arrowTopY,
                arrowCenterX + arrowWidth * 0.5, arrowTopY,
                arrowCenterX, arrowBottomY
            )

            local profileLabel = "Profile"
            local labelWidth = detailFont:getWidth(profileLabel)
            local labelX = arrowX - 4 - labelWidth
            local labelY = arrowY + (arrowHeight - detailFont:getHeight()) * 0.5
            love.graphics.print(profileLabel, labelX, labelY)

            if arrowHovered then
                local ai = target.ai or {}
                local stats = target.stats or {}
                local detection, engagement, preferred, weaponRange = resolve_range_profile(target)

                local entries = {}

                local levelValue = resolve_level(target)
                if levelValue then
                    entries[#entries + 1] = { "Level", tostring(levelValue) }
                end

                if behaviorLabel or ai.behavior then
                    local value = behaviorLabel or tostring(ai.behavior)
                    if ai.aggression then
                        value = string.format("%s (Agg %.2f)", value, ai.aggression)
                    end
                    entries[#entries + 1] = { "Behavior", value }
                end

                if ai.targetTag then
                    entries[#entries + 1] = { "Target Tag", tostring(ai.targetTag) }
                end

                if weaponLabel then
                    entries[#entries + 1] = { "Weapon", weaponLabel }
                end

                local primaryWeapon
                local weapons = target.weapons
                if type(weapons) == "table" and #weapons > 0 then
                    primaryWeapon = weapons[1]
                elseif type(target.weapon) == "table" then
                    primaryWeapon = { weapon = target.weapon }
                end

                local weaponComponent = primaryWeapon and primaryWeapon.weapon
                if type(weaponComponent) == "table" then
                    if weaponComponent.fireMode then
                        entries[#entries + 1] = { "Fire Mode", tostring(weaponComponent.fireMode) }
                    end
                    if weaponComponent.damage then
                        entries[#entries + 1] = { "Damage/Shot", string.format("%.1f", weaponComponent.damage) }
                    end
                    if weaponComponent.damagePerSecond then
                        entries[#entries + 1] = { "Damage/Sec", string.format("%.1f", weaponComponent.damagePerSecond) }
                    end
                    if weaponComponent.maxRange or weaponRange then
                        local wr = weaponComponent.maxRange or weaponRange
                        entries[#entries + 1] = { "Weapon Range", string.format("%.0f", wr) }
                    end
                    if weaponComponent.energyPerShot then
                        entries[#entries + 1] = { "Energy/Shot", string.format("%.1f", weaponComponent.energyPerShot) }
                    end
                    if weaponComponent.energyPerSecond then
                        entries[#entries + 1] = { "Energy/Sec", string.format("%.1f", weaponComponent.energyPerSecond) }
                    end
                end

                if detection or engagement or preferred then
                    if detection then
                        entries[#entries + 1] = { "Detect Range", string.format("%.0f", detection) }
                    end
                    if engagement then
                        entries[#entries + 1] = { "Engage Range", string.format("%.0f", engagement) }
                    end
                    if preferred then
                        entries[#entries + 1] = { "Preferred Dist", string.format("%.0f", preferred) }
                    end
                end

                if stats.max_speed then
                    entries[#entries + 1] = { "Max Speed", string.format("%.0f", stats.max_speed) }
                end
                if stats.max_acceleration then
                    entries[#entries + 1] = { "Acceleration", string.format("%.0f", stats.max_acceleration) }
                end
                if stats.main_thrust then
                    entries[#entries + 1] = { "Main Thrust", string.format("%.0f", stats.main_thrust) }
                end
                if stats.strafe_thrust then
                    entries[#entries + 1] = { "Strafe Thrust", string.format("%.0f", stats.strafe_thrust) }
                end
                if stats.reverse_thrust then
                    entries[#entries + 1] = { "Reverse Thrust", string.format("%.0f", stats.reverse_thrust) }
                end

                if stats.mass then
                    entries[#entries + 1] = { "Mass", string.format("%.1f", stats.mass) }
                end

                if target.armorType then
                    entries[#entries + 1] = { "Armor", tostring(target.armorType) }
                end

                if hull_max then
                    entries[#entries + 1] = { "Hull Max", string.format("%.0f", hull_max) }
                end
                if shield_max and shield_max > 0 then
                    entries[#entries + 1] = { "Shield Max", string.format("%.0f", shield_max) }
                end

                local entryCount = #entries
                if entryCount > 0 then
                    local profilePadding = 8
                    local lineHeight = detailFont:getHeight()
                    local lineSpacing = 2
                    local profileHeight = profilePadding * 2
                        + entryCount * lineHeight
                        + (entryCount - 1) * lineSpacing
                    local profileWidth = width
                    local profileX = x
                    local profileY = y + height + 6

                    set_color(hud_colors.status_panel or { 0.05, 0.06, 0.09, 0.95 })
                    love.graphics.rectangle("fill", profileX, profileY, profileWidth, profileHeight)

                    set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", profileX + 0.5, profileY + 0.5, profileWidth - 1, profileHeight - 1)

                    love.graphics.setFont(detailFont)
                    set_color(hud_colors.status_text or { 0.82, 0.88, 0.93, 1 })

                    local rowX = profileX + profilePadding
                    local rowY = profileY + profilePadding
                    local rowWidth = profileWidth - profilePadding * 2

                    for i = 1, entryCount do
                        local entry = entries[i]
                        if entry and entry[1] and entry[2] then
                            love.graphics.print(entry[1], rowX, rowY)
                            love.graphics.printf(entry[2], rowX, rowY, rowWidth, "right")
                            rowY = rowY + lineHeight + lineSpacing
                        end
                    end
                end
            end
        end

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
        local shield_color = hud_colors.shield_fill or { 0.3, 0.6, 0.95, 1 }
        love.graphics.setColor(shield_color[1], shield_color[2], shield_color[3], (shield_color[4] or 1) * 0.65)
        love.graphics.rectangle("fill", text_x + 1, bar_y + 1, (bar_width - 2) * shield_pct, bar_height - 2)

        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.45, 0.98, 1.0, 0.45)
        love.graphics.rectangle("fill", text_x + 3, bar_y + 3, math.max(0, (bar_width - 6) * shield_pct), math.max(0, bar_height - 6))
        love.graphics.setBlendMode("alpha")

        set_color(hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", text_x + 0.5, bar_y + 0.5, bar_width - 1, bar_height - 1)
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
