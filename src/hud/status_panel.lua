local theme = require("src.ui.theme")
local Util = require("src.hud.util")

---@diagnostic disable-next-line: undefined-global
local love = love

local hud_colors = theme.colors.hud
local set_color = theme.utils.set_color

local function extract_level_value(levelData)
    if type(levelData) == "number" then
        return levelData
    elseif type(levelData) == "table" then
        return levelData.current or levelData.level or levelData.value or levelData[1]
    end
    return nil
end

local function extract_experience_data(player)
    if not player then return 0, 1 end
    
    local pilot = player.pilot
    local exp_data = pilot and pilot.level
    
    if type(exp_data) == "table" then
        local current_exp = exp_data.experience or exp_data.exp or exp_data.current_exp or 0
        local max_exp = exp_data.max_experience or exp_data.max_exp or exp_data.next_level or 100
        return current_exp, max_exp
    end
    
    return 0, 1
end

local function resolve_level(player)
    if not player then return nil end
    
    local pilot = player.pilot
    local level = extract_level_value(pilot and pilot.level) or extract_level_value(player.level)
    
    if type(level) == "number" then
        return math.max(0, math.floor(level + 0.5))
    end
    
    return nil
end

local StatusPanel = {}

function StatusPanel.draw(player)
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
    
    local has_hull, has_energy = hull_max and hull_max > 0, energy_max and energy_max > 0
    if not (has_hull or has_energy) then return 0 end
    
    local level_text = resolve_level(player) and tostring(resolve_level(player)) or "--"
    local exp_current, exp_max = extract_experience_data(player)
    
    local x, y = 15, 15
    local width = 300
    local padding = 8
    local level_width = 80
    local gap = 12
    local hull_height = 18
    local energy_height = 8
    
    local fonts = theme.get_fonts()
    local small_font = fonts.small or love.graphics.getFont()
    local tiny_font = fonts.tiny or small_font
    local title_font = fonts.title or small_font
    
    local content_height = 0
    if has_hull then content_height = content_height + small_font:getHeight() + 4 + hull_height end
    if has_hull and has_energy then content_height = content_height + 8 end
    if has_energy then content_height = content_height + tiny_font:getHeight() + 2 + energy_height end
    
    local panel_height = padding * 2 + math.max(content_height, level_width + 4)
    local bar_x = x + padding + level_width + gap
    local bar_width = width - padding - level_width - gap * 2
    
    -- Panel background
    set_color(hud_colors.status_shadow)
    love.graphics.rectangle("fill", x, y + 2, width, panel_height, 8, 8)
    
    set_color(hud_colors.status_panel)
    love.graphics.rectangle("fill", x, y, width, panel_height, 8, 8)
    
    set_color(hud_colors.status_border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, panel_height - 1, 8, 8)
    
    -- Level section with experience circle
    local level_center_x = x + padding + level_width / 2
    local level_center_y = y + padding + level_width / 2
    local circle_radius = 28
    
    -- Experience circle background
    set_color(hud_colors.status_bar_background)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", level_center_x, level_center_y, circle_radius)
    
    -- Experience arc
    if exp_max > 0 then
        local exp_pct = Util.clamp01(exp_current / exp_max)
        local arc_length = exp_pct * 2 * math.pi
        
        set_color(hud_colors.energy_fill)
        love.graphics.setLineWidth(4)
        love.graphics.arc("line", "open", level_center_x, level_center_y, circle_radius, -math.pi/2, -math.pi/2 + arc_length)
        
        -- Experience glow
        set_color(hud_colors.energy_glow)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", level_center_x, level_center_y, circle_radius, -math.pi/2, -math.pi/2 + arc_length)
    end
    
    -- Level text
    love.graphics.setFont(title_font)
    set_color(hud_colors.status_text)
    local level_text_width = title_font:getWidth(level_text)
    love.graphics.print(level_text, level_center_x - level_text_width/2, level_center_y - title_font:getHeight()/2)
    
    -- LVL label
    love.graphics.setFont(tiny_font)
    set_color(hud_colors.status_muted)
    local lvl_width = tiny_font:getWidth("LVL")
    love.graphics.print("LVL", level_center_x - lvl_width/2, level_center_y + title_font:getHeight()/2 + 2)
    
    -- Separator
    local sep_x = bar_x - gap * 0.5
    set_color(hud_colors.status_border)
    love.graphics.line(sep_x, y + padding, sep_x, y + panel_height - padding)
    
    -- Resource bars
    local current_y = y + padding
    
    if has_hull then
        love.graphics.setFont(small_font)
        local hull_text = Util.format_resource(hull_current, hull_max)
        local shield_text = shield_max and shield_max > 0 and Util.format_resource(shield_current, shield_max) or ""
        
        set_color(hud_colors.status_text)
        love.graphics.print("Hull", bar_x, current_y)
        love.graphics.print(hull_text, bar_x + bar_width - small_font:getWidth(hull_text), current_y)
        
        -- Shield text if present
        if shield_text ~= "" then
            set_color(hud_colors.status_muted)
            love.graphics.print("Shield: " .. shield_text, bar_x, current_y + small_font:getHeight())
            current_y = current_y + small_font:getHeight() * 2 + 4
        else
            current_y = current_y + small_font:getHeight() + 4
        end
        
        local hull_pct = Util.clamp01(hull_current / hull_max)
        local shield_pct = shield_max and shield_max > 0 and Util.clamp01(shield_current / shield_max) or 0
        
        -- Hull bar background
        set_color(hud_colors.status_bar_background)
        love.graphics.rectangle("fill", bar_x, current_y, bar_width, hull_height, 4, 4)
        
        -- Hull fill
        if hull_pct > 0 then
            local hull_w = (bar_width - 2) * hull_pct
            set_color(hud_colors.hull_fill)
            love.graphics.rectangle("fill", bar_x + 1, current_y + 1, hull_w, hull_height - 2, 4, 4)
            set_color(hud_colors.hull_glow)
            love.graphics.rectangle("fill", bar_x + 1, current_y + 1, hull_w, (hull_height - 2) * 0.4, 4, 4)
        end
        
        -- Shield overlay
        if shield_pct > 0 then
            local shield_w = (bar_width - 2) * shield_pct
            set_color(hud_colors.shield_fill)
            love.graphics.rectangle("fill", bar_x + 1, current_y + hull_height/2, shield_w, hull_height/2 - 1, 4, 4)
            set_color(hud_colors.shield_glow)
            love.graphics.rectangle("fill", bar_x + 1, current_y + hull_height/2, shield_w, (hull_height/2 - 1) * 0.6, 4, 4)
        end
        
        -- Divider line between hull and shield
        if shield_pct > 0 then
            set_color(hud_colors.status_border)
            love.graphics.setLineWidth(1)
            love.graphics.line(bar_x + 1, current_y + hull_height/2, bar_x + bar_width - 1, current_y + hull_height/2)
        end
        
        current_y = current_y + hull_height + 8
    end
    
    if has_energy then
        love.graphics.setFont(tiny_font)
        local energy_text = Util.format_resource(energy_current, energy_max)
        
        set_color(hud_colors.status_muted)
        love.graphics.print("Energy", bar_x, current_y)
        love.graphics.print(energy_text, bar_x + bar_width - tiny_font:getWidth(energy_text), current_y)
        
        current_y = current_y + tiny_font:getHeight() + 2
        
        local energy_pct = Util.clamp01(energy_current / energy_max)
        
        set_color(hud_colors.status_bar_background)
        love.graphics.rectangle("fill", bar_x, current_y, bar_width, energy_height, 3, 3)
        
        if energy_pct > 0 then
            local energy_w = (bar_width - 2) * energy_pct
            set_color(hud_colors.energy_fill)
            love.graphics.rectangle("fill", bar_x + 1, current_y + 1, energy_w, energy_height - 2, 3, 3)
            set_color(hud_colors.energy_glow)
            love.graphics.rectangle("fill", bar_x + 1, current_y + 1, energy_w, (energy_height - 2) * 0.5, 3, 3)
        end
    end
    
    return panel_height + 4
end

return StatusPanel
