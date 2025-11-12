local theme = require("src.ui.theme")
local Util = require("src.hud.util")

---@diagnostic disable-next-line: undefined-global
local love = love
local g = love and love.graphics

local TWO_PI = math.pi * 2

local function get_time()
    local loveTimer = love and love.timer
    if loveTimer and loveTimer.getTime then
        return loveTimer.getTime()
    end
    return os.time()
end

local function ease_out_cubic(t)
    t = Util.clamp01(t or 0)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function extract_level_value(levelData)
    if type(levelData) == "number" then
        return levelData
    elseif type(levelData) == "table" then
        return levelData.current or levelData.level or levelData.value or levelData[1]
    end
    return nil
end

local function extract_experience_data(player)
    if not player then
        return 0, 1, nil
    end

    local pilot = player.pilot
    local exp_data = pilot and pilot.level

    if type(exp_data) == "table" then
        local current_exp = tonumber(exp_data.experience or exp_data.exp or exp_data.current_exp or exp_data.xp or 0) or 0
        local max_exp = tonumber(exp_data.max_experience or exp_data.max_exp or exp_data.next_level or exp_data.xpRequired or 100) or 100

        if max_exp <= 0 then
            max_exp = 100
        end

        return math.max(0, current_exp), math.max(1, max_exp), exp_data
    end

    return 0, 1, nil
end

local function resolve_level(player)
    if not player then
        return nil
    end

    local pilot = player.pilot
    local level = extract_level_value(pilot and pilot.level) or extract_level_value(player.level)

    if type(level) == "number" then
        return math.max(0, math.floor(level + 0.5))
    end

    return nil
end

local StatusPanel = {}

function StatusPanel.draw(player)
    if not g then
        return 0
    end

    local hull_current, hull_max = Util.resolve_resource(player and (player.hull or player.health))
    local shield_current, shield_max = Util.resolve_resource(player and (player.shield or player.shields))

    if not shield_current and player and player.health then
        shield_current, shield_max = Util.resolve_resource(player.health.shield or player.health.shields)
    end

    local energy_current, energy_max = Util.resolve_resource(player and (player.energy or player.capacitor))

    if (not energy_max or energy_max <= 0) and player then
        local thrust_max = player.maxThrust or (player.stats and player.stats.main_thrust)
        if thrust_max and thrust_max > 0 then
            energy_max = thrust_max
            energy_current = math.max(0, math.min(thrust_max, player.currentThrust or 0))
        end
    end

    local has_hull = hull_max and hull_max > 0
    local has_energy = energy_max and energy_max > 0
    if not (has_hull or has_energy) then
        return 0
    end

    local resolved_level = resolve_level(player)
    local level_text = resolved_level and tostring(resolved_level) or "--"
    local exp_current, exp_max, level_state = extract_experience_data(player)
    local xp_pct = exp_max > 0 and Util.clamp01(exp_current / exp_max) or 0

    local x, y = 15, 15
    local width = 300
    local spacing = theme.spacing or {}
    local padding = spacing.window_padding and math.min(12, spacing.window_padding) or 8
    local level_width = math.max(64, spacing.status_level_width or 80)
    local gap = spacing.status_gap or spacing.small or 12
    local hull_height = 18
    local energy_height = 8

    local fonts = theme.get_fonts()
    local font_title = fonts.title
    local font_small = fonts.small
    local font_tiny = fonts.tiny
    local title_height = font_title:getHeight()
    local small_height = font_small:getHeight()
    local tiny_height = font_tiny:getHeight()

    local hud_colors = theme.colors.hud
    local set_color = theme.utils.set_color
    local palette = theme.palette or {}
    local accent = palette.accent or { 0.46, 0.64, 0.72, 1 }
    local text_color = hud_colors.status_text or { 0.85, 0.89, 0.93, 1 }
    local muted_color = hud_colors.status_muted or { 0.46, 0.52, 0.58, 1 }

    local gainInfo = level_state and level_state.lastGain
    local highlightScale = 1
    local highlightAlpha = 0

    if gainInfo then
        local timestamp = tonumber(gainInfo.timestamp) or 0
        local duration = math.max(0.4, tonumber(gainInfo.duration) or 1.2)
        local elapsed = get_time() - timestamp

        if elapsed < duration then
            local t = Util.clamp01(elapsed / duration)
            local eased = ease_out_cubic(t)

            highlightScale = 1 + 0.12 * (1 - eased)
            highlightAlpha = 0.55 * (1 - t)
        else
            level_state.lastGain = nil
        end
    end

    local content_height = 0
    if has_hull then
        content_height = content_height + small_height + 4 + hull_height
    end
    if has_hull and has_energy then
        content_height = content_height + gap
    end
    if has_energy then
        content_height = content_height + tiny_height + 2 + energy_height
    end

    local panel_height = padding * 2 + math.max(content_height, level_width + 4)
    local bar_x = x + padding + level_width + gap
    local bar_width = math.max(0, width - padding - level_width - gap * 2)

    local function print_right(font, text, px, py, available_width)
        g.setFont(font)
        g.print(text, px + available_width - font:getWidth(text), py)
    end

    local function draw_progress_bar(px, py, bar_width, bar_height, pct, fill_color)
        set_color(hud_colors.status_bar_background)
        g.rectangle("fill", px, py, bar_width, bar_height)
        if pct > 0 then
            set_color(fill_color)
            g.rectangle("fill", px + 1, py + 1, (bar_width - 2) * pct, bar_height - 2)
        end
    end

    local function draw_scale_markers(px, py, bar_width, bar_height, segments)
        if not segments or segments <= 1 then
            return
        end

        set_color(hud_colors.status_bar_scale)
        g.setLineWidth(1)
        local inner_width = bar_width - 2
        local top = py + 1
        local bottom = py + bar_height - 1
        for i = 1, segments - 1 do
            local t = i / segments
            local line_x = px + 1 + inner_width * t
            g.line(line_x, top, line_x, bottom)
        end
    end

    -- Panel background
    set_color(hud_colors.status_panel)
    g.rectangle("fill", x, y, width, panel_height)

    set_color(hud_colors.status_border)
    g.setLineWidth(1)
    g.rectangle("line", x + 0.5, y + 0.5, width - 1, panel_height - 1)

    -- Level section with experience circle
    local level_center_x = x + padding + level_width / 2
    local level_center_y = y + padding + level_width / 2
    local circle_radius = math.max(24, math.floor((level_width - 8) * 0.5))
    circle_radius = math.min(circle_radius, level_width / 2 - 2)

    set_color(hud_colors.status_bar_background)
    g.setLineWidth(4)
    g.circle("line", level_center_x, level_center_y, circle_radius)

    if exp_max > 0 then
        local arc_end = -math.pi / 2 + xp_pct * TWO_PI
        set_color(hud_colors.energy_fill)
        g.setLineWidth(4)
        g.arc("line", "open", level_center_x, level_center_y, circle_radius, -math.pi / 2, arc_end)
    end

    if highlightAlpha > 0 then
        g.setColor(accent[1], accent[2], accent[3], highlightAlpha)
        g.setLineWidth(6)
        g.circle("line", level_center_x, level_center_y, circle_radius * highlightScale)
        g.setLineWidth(1)
    end

    g.setFont(font_title)
    set_color(text_color)
    g.print(level_text, level_center_x - font_title:getWidth(level_text) / 2, level_center_y - title_height / 2)

    g.setFont(font_tiny)
    set_color(muted_color)
    local lvl_width = font_tiny:getWidth("LVL")
    g.print("LVL", level_center_x - lvl_width / 2, level_center_y + title_height / 2 + 2)

    -- Separator
    local sep_x = bar_x - gap * 0.5
    set_color(hud_colors.status_border)
    g.line(sep_x, y + padding, sep_x, y + panel_height - padding)

    local current_y = y + padding

    if has_hull then
        g.setFont(font_small)
        set_color(text_color)
        g.print("Hull", bar_x, current_y)
        print_right(font_small, Util.format_resource(hull_current, hull_max), bar_x, current_y, bar_width)

        local shield_text = shield_max and shield_max > 0 and Util.format_resource(shield_current, shield_max) or ""
        if shield_text ~= "" then
            set_color(muted_color)
            g.setFont(font_small)
            g.print("Shield: " .. shield_text, bar_x, current_y + small_height)
            current_y = current_y + small_height * 2 + 4
        else
            current_y = current_y + small_height + 4
        end

        local hull_pct = Util.clamp01(hull_current / hull_max)
        local shield_pct = shield_max and shield_max > 0 and Util.clamp01(shield_current / shield_max) or 0

        draw_progress_bar(bar_x, current_y, bar_width, hull_height, hull_pct, hud_colors.hull_fill)

        if shield_pct > 0 then
            set_color(hud_colors.shield_fill)
            g.rectangle("fill", bar_x + 1, current_y + hull_height / 2, (bar_width - 2) * shield_pct, hull_height / 2 - 1)
            set_color(hud_colors.status_border)
            g.setLineWidth(1)
            g.line(bar_x + 1, current_y + hull_height / 2, bar_x + bar_width - 1, current_y + hull_height / 2)
        end

        draw_scale_markers(bar_x, current_y, bar_width, hull_height, 4)

        current_y = current_y + hull_height + (has_energy and gap or 0)
    end

    if has_energy then
        g.setFont(font_tiny)
        set_color(muted_color)
        g.print("Energy", bar_x, current_y)
        print_right(font_tiny, Util.format_resource(energy_current, energy_max), bar_x, current_y, bar_width)

        current_y = current_y + tiny_height + 2

        local energy_pct = Util.clamp01(energy_current / energy_max)
        draw_progress_bar(bar_x, current_y, bar_width, energy_height, energy_pct, hud_colors.energy_fill)
    end

    g.setLineWidth(1)
    return panel_height + 4
end

return StatusPanel
