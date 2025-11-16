local theme = require("src.ui.theme")
local QuestGenerator = require("src.stations.quest_generator")

local quest_overlay = {}

local DEFAULT_COLORS = {
    background = { 0.06, 0.08, 0.12, 0.82 },
    border = { 0.22, 0.32, 0.46, 0.9 },
    text = { 0.85, 0.9, 1.0, 1 },
    accent = { 0.32, 0.6, 0.92, 1 },
}

local HUD_COLORS = theme.colors.hud or {}

local function resolve_color(key)
    local color = HUD_COLORS[key]
    if type(color) == "table" and color[1] then
        return color
    end
    return DEFAULT_COLORS[key]
end

local function resolve_state(context)
    if not context then
        return nil
    end

    if type(context.resolveState) == "function" then
        local ok, resolved = pcall(context.resolveState, context)
        if ok and type(resolved) == "table" then
            return resolved
        end
    end

    if type(context.state) == "table" then
        return context.state
    end

    return context
end

local function resolve_active_quests(state)
    state = resolve_state(state)
    if not (state and state.stationUI) then
        return {}
    end

    local ui = state.stationUI
    local quests = ui.quests or {}
    local activeIds = ui.activeQuestIds

    if type(activeIds) ~= "table" or next(activeIds) == nil then
        return {}
    end

    local active = {}
    for i = 1, #quests do
        local quest = quests[i]
        local id = quest and quest.id
        if id and activeIds[id] then
            quest.accepted = true
            quest.progress = quest.progress or 0
            active[#active + 1] = quest
        end
    end

    return active
end

local function draw_text(font, text, x, y, color)
    love.graphics.setFont(font)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.print(text, x, y)
end

function quest_overlay.draw(context, minimap_rect)
    if not (love and love.graphics and minimap_rect) then
        return
    end

    local state = context and (context.state or context) or nil
    local quests = resolve_active_quests(state)
    if not quests or #quests == 0 then
        return
    end

    local fonts = theme.get_fonts()
    local title_font = fonts.small_bold or fonts.body_bold or love.graphics.getFont()
    local body_font = fonts.small or fonts.body or love.graphics.getFont()

    local padding = 8
    local spacing = 4
    local line_height = body_font:getHeight()
    local title_height = title_font:getHeight()

    local overlay_width = minimap_rect.width
    local overlay_x = minimap_rect.x
    local overlay_y = minimap_rect.y + minimap_rect.height + padding

    local cursor_x = overlay_x
    local cursor_y = overlay_y

    local block_spacing = spacing * 3

    for index = 1, #quests do
        local quest = quests[index]
        local title = quest and quest.title or string.format("Contract %d", index)
        local progress_label = QuestGenerator.progressLabel(quest)
        local reward_label = QuestGenerator.rewardLabel(quest)

        draw_text(title_font, title, cursor_x, cursor_y, resolve_color("text"))
        cursor_y = cursor_y + title_height + spacing

        local progress_text = progress_label ~= "" and string.format("Progress: %s", progress_label) or "Progress: --"
        draw_text(body_font, progress_text, cursor_x, cursor_y, resolve_color("text"))
        cursor_y = cursor_y + line_height

        local reward_text = reward_label ~= "" and string.format("Reward: %s", reward_label) or "Reward: --"
        draw_text(body_font, reward_text, cursor_x, cursor_y, resolve_color("accent"))
        if index < #quests then
            cursor_y = cursor_y + line_height + block_spacing
        end
    end
end

return quest_overlay
