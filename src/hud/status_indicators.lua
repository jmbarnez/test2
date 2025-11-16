local theme = require("src.ui.theme")
local Util = require("src.hud.util")

---@diagnostic disable-next-line: undefined-global
local love = love
local g = love and love.graphics

local StatusIndicators = {}

-- Configuration for status thresholds
local THRESHOLDS = {
    CRITICAL_HEALTH = 0.15,  -- 15% or below
    LOW_HEALTH = 0.35,       -- 35% or below
    LOW_SHIELD = 0.25,       -- 25% or below
    LOW_ENERGY = 0.20,       -- 20% or below
    OVERHEATING = 0.80,      -- 80% or above
}

-- Indicator definitions with icons and colors
local INDICATORS = {
    critical_health = {
        label = "CRITICAL",
        icon = "alert",
        color = { 1.0, 0.15, 0.15, 1.0 },
        priority = 1,
        flash = true,
        flashSpeed = 3.0,
    },
    target_locked = {
        label = "TARGET LOCK",
        icon = "reticle",
        color = { 1.0, 0.3, 0.1, 1.0 },
        priority = 2,
        flash = true,
        flashSpeed = 2.5,
    },
    low_health = {
        label = "Low Hull",
        icon = "heart",
        color = { 1.0, 0.5, 0.2, 1.0 },
        priority = 3,
        flash = false,
    },
    overheating = {
        label = "Overheating",
        icon = "heat",
        color = { 1.0, 0.6, 0.0, 1.0 },
        priority = 4,
        flash = false,
    },
    low_shield = {
        label = "Low Shield",\n+        icon = "shield",
        color = { 0.2, 0.8, 1.0, 1.0 },
        priority = 5,
        flash = false,
    },
    low_energy = {
        label = "Low Energy",
        icon = "bolt",
        color = { 0.9, 0.9, 0.3, 1.0 },
        priority = 6,
        flash = false,
    },
    weapons_offline = {
        label = "Weapons Offline",
        icon = "offline",
        color = { 0.7, 0.2, 0.2, 1.0 },
        priority = 7,
        flash = false,
    },
    systems_failure = {
        label = "Systems Failure",
        icon = "fault",
        color = { 0.8, 0.3, 0.0, 1.0 },
        priority = 8,
        flash = true,
        flashSpeed = 2.0,
    },
}

local function get_time()
    local loveTimer = love and love.timer
    if loveTimer and loveTimer.getTime then
        return loveTimer.getTime()
    end
    return os.time()
end

-- Detect active status conditions
local function detect_status_conditions(player)
    if not player then
        return {}
    end

    local conditions = {}

    -- Check health/hull
    local hull_current, hull_max = Util.resolve_resource(player.hull or player.health)
    if hull_current and hull_max and hull_max > 0 then
        local hull_pct = hull_current / hull_max
        if hull_pct <= THRESHOLDS.CRITICAL_HEALTH then
            conditions.critical_health = true
        elseif hull_pct <= THRESHOLDS.LOW_HEALTH then
            conditions.low_health = true
        end
    end

    -- Check shield
    local shield_current, shield_max = Util.resolve_resource(player.shield or player.shields)
    if not shield_current and player.health then
        shield_current, shield_max = Util.resolve_resource(player.health.shield or player.health.shields)
    end
    if shield_current and shield_max and shield_max > 0 then
        local shield_pct = shield_current / shield_max
        if shield_pct <= THRESHOLDS.LOW_SHIELD then
            conditions.low_shield = true
        end
    end

    -- Check energy
    local energy_current, energy_max = Util.resolve_resource(player.energy or player.capacitor)
    if not energy_max or energy_max <= 0 then
        local thrust_max = player.maxThrust or (player.stats and player.stats.main_thrust)
        if thrust_max and thrust_max > 0 then
            energy_max = thrust_max
            energy_current = math.max(0, math.min(thrust_max, player.currentThrust or 0))
        end
    end
    if energy_current and energy_max and energy_max > 0 then
        local energy_pct = energy_current / energy_max
        if energy_pct <= THRESHOLDS.LOW_ENERGY then
            conditions.low_energy = true
        end
    end

    -- Check overheating (weapon heat or ship heat)
    local heat_current, heat_max
    if player.weapon and type(player.weapon) == "table" then
        heat_current, heat_max = Util.resolve_resource(player.weapon.heat)
    end
    if not heat_current and player.heat then
        heat_current, heat_max = Util.resolve_resource(player.heat)
    end
    if heat_current and heat_max and heat_max > 0 then
        local heat_pct = heat_current / heat_max
        if heat_pct >= THRESHOLDS.OVERHEATING then
            conditions.overheating = true
        end
    end

    -- Check if target locked (enemy has locked onto player)
    if player.targetedBy and #player.targetedBy > 0 then
        conditions.target_locked = true
    elseif player.beingTargeted or player.isTargeted then
        conditions.target_locked = true
    end

    -- Check weapons offline
    if player.weaponsDisabled or player.weapons_offline then
        conditions.weapons_offline = true
    elseif player.weapon and type(player.weapon) == "table" and player.weapon.disabled then
        conditions.weapons_offline = true
    end

    -- Check systems failure
    if player.systemsFailure or player.systems_failure then
        conditions.systems_failure = true
    elseif player.malfunctioning or (player.damage and player.damage.systems) then
        conditions.systems_failure = true
    end

    return conditions
end

-- Draw a single indicator badge
local function draw_indicator_badge(x, y, width, height, indicator, time)
    local set_color = theme.utils.set_color
    local window_colors = theme.colors.window
    local fonts = theme.get_fonts()

    -- Background
    set_color(window_colors.shadow or { 0, 0, 0, 0.4 })
    g.rectangle("fill", x, y + 1, width, height, 3, 3)
    set_color(window_colors.surface or { 0.05, 0.07, 0.10, 0.95 })
    g.rectangle("fill", x, y, width, height, 3, 3)

    -- Border with indicator color
    local borderAlpha = 1.0
    if indicator.flash then
        local phase = math.sin(time * indicator.flashSpeed) * 0.5 + 0.5
        borderAlpha = 0.5 + phase * 0.5
    end

    g.setColor(indicator.color[1], indicator.color[2], indicator.color[3], borderAlpha)
    g.setLineWidth(2)
    g.rectangle("line", x + 1, y + 1, width - 2, height - 2, 3, 3)

    -- Icon
    if indicator.icon and fonts.body then
        g.setFont(fonts.body)
        local iconColor = indicator.color
        if indicator.flash then
            local phase = math.sin(time * indicator.flashSpeed) * 0.5 + 0.5
            iconColor = {
                indicator.color[1] * (0.7 + phase * 0.3),
                indicator.color[2] * (0.7 + phase * 0.3),
                indicator.color[3] * (0.7 + phase * 0.3),
                1.0
            }
        end
        set_color(iconColor)
        local iconW = fonts.body:getWidth(indicator.icon)
        g.print(indicator.icon, x + 8, y + (height - fonts.body:getHeight()) * 0.5)

        -- Label
        if fonts.small then
            g.setFont(fonts.small)
            local labelX = x + 8 + iconW + 6
            g.print(indicator.label, labelX, y + (height - fonts.small:getHeight()) * 0.5)
        end
    end
end

-- Main draw function
function StatusIndicators.draw(player, statusPanelY)
    if not (g and player) then
        return 0
    end

    local conditions = detect_status_conditions(player)
    
    -- Build list of active indicators sorted by priority
    local activeIndicators = {}
    for key, active in pairs(conditions) do
        if active and INDICATORS[key] then
            table.insert(activeIndicators, {
                key = key,
                data = INDICATORS[key],
            })
        end
    end

    if #activeIndicators == 0 then
        return 0
    end

    table.sort(activeIndicators, function(a, b)
        return a.data.priority < b.data.priority
    end)

    -- Layout configuration
    local x = 15
    local y = statusPanelY or 15
    local width = 300
    local padding = 6
    local gap = 4
    local badgeHeight = 28

    local fonts = theme.get_fonts()
    if fonts.small then
        badgeHeight = math.max(28, fonts.small:getHeight() + 12)
    end

    local totalHeight = #activeIndicators * (badgeHeight + gap) - gap + padding * 2
    local containerY = y

    -- Draw container background
    local set_color = theme.utils.set_color
    local window_colors = theme.colors.window
    local hud_colors = theme.colors.hud

    set_color(hud_colors.status_panel or window_colors.background or { 0.02, 0.02, 0.04, 0.9 })
    g.rectangle("fill", x, containerY, width, totalHeight, 4, 4)

    set_color(hud_colors.status_border or window_colors.border or { 0.22, 0.28, 0.36, 0.88 })
    g.setLineWidth(1)
    g.rectangle("line", x + 0.5, containerY + 0.5, width - 1, totalHeight - 1, 4, 4)

    -- Draw individual indicators
    local currentY = containerY + padding
    local time = get_time()

    for i, entry in ipairs(activeIndicators) do
        local badgeX = x + padding
        local badgeWidth = width - padding * 2
        draw_indicator_badge(badgeX, currentY, badgeWidth, badgeHeight, entry.data, time)
        currentY = currentY + badgeHeight + gap
    end

    g.setLineWidth(1)
    return totalHeight + 4
end

-- Allow external configuration of thresholds
function StatusIndicators.setThreshold(key, value)
    if THRESHOLDS[key:upper()] ~= nil and type(value) == "number" then
        THRESHOLDS[key:upper()] = math.max(0, math.min(1, value))
    end
end

function StatusIndicators.getThresholds()
    return THRESHOLDS
end

return StatusIndicators
