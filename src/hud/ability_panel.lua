local theme = require("src.ui.theme")

---@diagnostic disable-next-line: undefined-global
local love = love

local AbilityPanel = {}

local window_colors = theme.colors.window
local spacing = theme.spacing or {}
local set_color = theme.utils.set_color

local DEFAULT_PANEL_WIDTH = 220
local DEFAULT_PANEL_HEIGHT = 76

local function format_hotkey(ability)
    if type(ability.hotkeyLabel) == "string" and ability.hotkeyLabel ~= "" then
        return ability.hotkeyLabel
    end

    local index = tonumber(ability.intentIndex) or 1
    if index == 1 then
        return "SPACE"
    end
    return string.format("ABILITY %d", index)
end

function AbilityPanel.draw(context, player)
    if not (player and player.abilityModules and #player.abilityModules > 0) then
        return
    end

    local abilityModules = player.abilityModules
    local abilityState = player._abilityState or {}

    local fonts = theme.get_fonts()
    local padding = spacing.padding or 10
    local gap = spacing.item_gap or 10
    local panelWidth = spacing.ability_panel_width or DEFAULT_PANEL_WIDTH
    local panelHeight = spacing.ability_panel_height or DEFAULT_PANEL_HEIGHT

    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local baseX = spacing.ability_panel_x or 24
    local baseY = (spacing.ability_panel_y or (screenHeight - panelHeight - 32))

    love.graphics.push("all")

    for index = #abilityModules, 1, -1 do
        local entry = abilityModules[index]
        local ability = entry.ability or {}
        local key = entry.key
        local state = abilityState[key] or {}

        local panelY = baseY - ( #abilityModules - index ) * (panelHeight + gap)

        -- Background
        set_color(window_colors.shadow or { 0, 0, 0, 0.35 })
        love.graphics.rectangle("fill", baseX, panelY + 2, panelWidth, panelHeight, 4, 4)
        set_color(window_colors.background or { 0.02, 0.02, 0.05, 0.92 })
        love.graphics.rectangle("fill", baseX, panelY, panelWidth, panelHeight, 4, 4)

        -- Cooldown fill
        local cooldownDuration = state.cooldownDuration or ability.cooldown or 0
        local cooldown = state.cooldown or 0
        local cooldownFraction = 0
        if cooldownDuration and cooldownDuration > 0 then
            cooldownFraction = math.min(math.max(cooldown / cooldownDuration, 0), 1)
        end
        if cooldownFraction > 0 then
            set_color(window_colors.surface_subtle or { 0.15, 0.18, 0.24, 0.75 })
            local fillHeight = panelHeight * cooldownFraction
            love.graphics.rectangle("fill", baseX, panelY + panelHeight - fillHeight, panelWidth, fillHeight, 4, 4)
        end

        local hotkeyLabel = format_hotkey(ability)
        local abilityName = ability.displayName or ability.id or "Ability"
        local energyCost = ability.energyCost

        if fonts.small then love.graphics.setFont(fonts.small) end
        set_color(window_colors.muted or { 0.6, 0.65, 0.7, 1 })
        love.graphics.print(hotkeyLabel, baseX + padding, panelY + padding)

        if fonts.body then love.graphics.setFont(fonts.body) end
        set_color(window_colors.text or { 0.85, 0.9, 0.95, 1 })
        love.graphics.print(abilityName, baseX + padding, panelY + padding + 20)

        if cooldownDuration and cooldownDuration > 0 then
            local progress = 1 - cooldownFraction
            local barWidth = panelWidth - padding * 2
            local barHeight = 6
            local barX = baseX + padding
            local barY = panelY + panelHeight - padding - barHeight - 4

            set_color(window_colors.progress_background or { 0.08, 0.09, 0.12, 0.9 })
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            if progress > 0 then
                set_color(window_colors.progress_fill or window_colors.accent or { 0.3, 0.6, 0.85, 1 })
                love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
            end
            set_color(window_colors.border or { 0.22, 0.28, 0.36, 0.88 })
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", barX, barY, barWidth, barHeight)

            if cooldown > 0 then
                local timeText = string.format("%.1fs", cooldown)
                if fonts.small then love.graphics.setFont(fonts.small) end
                local textWidth = fonts.small and fonts.small:getWidth(timeText) or 0
                set_color(window_colors.muted or { 0.6, 0.65, 0.7, 1 })
                love.graphics.print(timeText, baseX + panelWidth - padding - textWidth, panelY + padding)
            end
        end
    end

    love.graphics.pop()
end

return AbilityPanel
