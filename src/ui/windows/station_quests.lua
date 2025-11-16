local theme = require("src.ui.theme")
local geometry = require("src.util.geometry")
local QuestGenerator = require("src.stations.quest_generator")
local UIStateManager = require("src.ui.state_manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local station_quests = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color
local point_in_rect = geometry.point_in_rect

local function clear_array(list)
    if type(list) ~= "table" then
        return {}
    end

    for i = #list, 1, -1 do
        list[i] = nil
    end

    return list
end

local function compute_text_block_height(font, text, max_width)
    if not (font and text) or text == "" then
        return 0
    end

    local _, wrapped = font:getWrap(text, max_width)
    local line_count = math.max(1, #wrapped)
    return font:getHeight() * line_count
end

local function draw_action_button(rect, label, fonts, hovered, active, disabled)
    if not rect then
        return
    end

    local fill = window_colors.button
    local border = window_colors.border
    local text_color = window_colors.text or { 0.85, 0.9, 1.0, 1 }

    if disabled then
        fill = window_colors.muted or { 0.45, 0.5, 0.58, 0.7 }
        text_color = window_colors.muted or text_color
    elseif active then
        fill = window_colors.button_active or fill
    elseif hovered then
        fill = window_colors.button_hover or fill
    end

    set_color(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 4, 4)

    set_color(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1, 4, 4)

    love.graphics.setFont(fonts.body or love.graphics.getFont())
    set_color(text_color)
    love.graphics.printf(label, rect.x, rect.y + (rect.height - (fonts.body and fonts.body:getHeight() or 14)) * 0.5, rect.width, "center")
end

---@param context table
---@param params table
function station_quests.draw(context, params)
    local state = params.state or (context and context.stationUI) or {}
    local fonts = params.fonts
    local default_font = params.default_font or love.graphics.getFont()
    local content = params.content
    local mouse_x = params.mouse_x or 0
    local mouse_y = params.mouse_y or 0
    local mouse_down = params.mouse_down == true
    local just_pressed = params.just_pressed == true
    local bottom_bar = params.bottom_bar

    if type(state.activeQuestIds) ~= "table" then
        state.activeQuestIds = {}
    end

    if not state.quests then
        UIStateManager.refreshStationQuests(context)
    end

    local padding = theme_spacing.medium or 16
    local inner_x = content.x + padding
    local inner_width = math.max(0, content.width - padding * 2)
    local cursor_y = content.y + padding

    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
    love.graphics.setFont((fonts.body_bold or fonts.title or default_font))
    love.graphics.printf("Available Contracts", inner_x, cursor_y, inner_width, "left")

    cursor_y = cursor_y + ((fonts.body_bold or fonts.title or default_font):getHeight()) + (theme_spacing.small or math.floor(padding * 0.5))

    love.graphics.setFont(fonts.body or default_font)
    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })

    local area_top = cursor_y
    local area_height = math.max(0, content.y + content.height - area_top)

    local gap = theme_spacing.large or 24
    local list_width = math.floor(inner_width * 0.42)
    if inner_width - list_width - gap < 160 then
        gap = theme_spacing.medium or 16
        list_width = math.max(160, math.min(inner_width - gap - 160, math.floor(inner_width * 0.55)))
    end

    list_width = math.max(160, math.min(list_width, inner_width - gap - 140))
    local detail_width = math.max(0, inner_width - list_width - gap)

    local list_x = inner_x
    local detail_x = list_x + list_width + gap

    local quests = state.quests or {}
    state._questItemRects = clear_array(state._questItemRects)
    local quest_rects = state._questItemRects

    local row_spacing = math.max(theme_spacing.small or 0, math.floor(padding * 0.5))
    local row_inner_padding = math.max(math.floor(padding * 0.75), 14)
    local summary_font = fonts.small or fonts.body or default_font
    local title_font = fonts.body_bold or fonts.title or default_font
    local row_height = title_font:getHeight() + summary_font:getHeight() + row_inner_padding * 3

    local display_area_height = area_height
    local selectedQuest
    local selected_id = state.selectedQuestId
    local activeIds = state.activeQuestIds

    if selected_id then
        for i = 1, #quests do
            local quest = quests[i]
            if quest and quest.id == selected_id then
                selectedQuest = quest
                break
            end
        end
    end

    if not selectedQuest and quests[1] then
        selectedQuest = quests[1]
        selected_id = selectedQuest.id
        state.selectedQuestId = selected_id
    end

    local list_bg_color = window_colors.row_alternate or { 0.09, 0.11, 0.14, 0.8 }
    set_color(list_bg_color)
    love.graphics.rectangle("fill", list_x, area_top, list_width, display_area_height, 4, 4)

    set_color(window_colors.border or { 0.22, 0.28, 0.36, 0.9 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", list_x + 0.5, area_top + 0.5, list_width - 1, display_area_height - 1, 4, 4)

    local row_y = area_top
    for i = 1, #quests do
        local quest = quests[i]
        local rect = {
            x = list_x + 6,
            y = row_y + 6,
            width = list_width - 12,
            height = row_height,
        }

        row_y = row_y + row_height + row_spacing

        quest_rects[#quest_rects + 1] = {
            rect = rect,
            id = quest.id,
        }

        local hovered = point_in_rect(mouse_x, mouse_y, rect)
        local is_selected = selected_id == quest.id
        local is_active = activeIds and activeIds[quest.id]

        local fill_color
        if is_selected then
            fill_color = window_colors.accent_secondary or window_colors.accent or { 0.32, 0.52, 0.92, 0.96 }
        elseif hovered then
            fill_color = window_colors.row_hover or { 0.2, 0.26, 0.32, 0.28 }
        elseif is_active then
            fill_color = window_colors.row_alternate or { 0.09, 0.11, 0.14, 0.8 }
        else
            fill_color = window_colors.background or { 0.04, 0.05, 0.07, 0.96 }
        end

        set_color(fill_color)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 4, 4)

        set_color(window_colors.border or { 0.22, 0.28, 0.36, 0.88 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1, 4, 4)

        if just_pressed and hovered then
            state.selectedQuestId = quest.id
            selectedQuest = quest
            selected_id = quest.id
        end

        local text_x = rect.x + row_inner_padding
        local button_width = math.max(92, row_inner_padding * 3)
        local button_height = math.max(summary_font:getHeight() + row_inner_padding * 0.6, 26)
        local button_x = rect.x + rect.width - row_inner_padding - button_width
        local button_y = rect.y + (rect.height - button_height) * 0.5
        local button_rect = {
            x = button_x,
            y = button_y,
            width = button_width,
            height = button_height,
        }

        local text_width = button_rect.x - text_x - row_inner_padding
        if text_width < 80 then
            text_width = rect.width - row_inner_padding * 2
        end

        local top_text_y = rect.y + row_inner_padding - 2

        love.graphics.setFont(title_font)
        if is_selected then
            set_color(window_colors.title_text or { 0.92, 0.95, 1.0, 1 })
        else
            set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
        end
        love.graphics.printf(quest.title, text_x, top_text_y, text_width, "left")

        love.graphics.setFont(summary_font)
        local status_y = rect.y + rect.height - summary_font:getHeight() - row_inner_padding * 0.5
        if is_active then
            set_color(window_colors.accent_player or { 0.3, 0.78, 0.46, 1 })
            local progress_label = QuestGenerator.progressLabel(quest)
            local status_label = progress_label ~= "" and progress_label or "Accepted"
            love.graphics.printf(status_label, text_x, status_y, text_width, "right")
            set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
        else
            set_color(window_colors.muted or { 0.65, 0.7, 0.8, 1 })
        end

        local summary_y = rect.y + rect.height - summary_font:getHeight() - row_inner_padding
        love.graphics.printf(QuestGenerator.rewardLabel(quest), text_x, summary_y, text_width, "left")

        local button_hovered = point_in_rect(mouse_x, mouse_y, button_rect)
        local button_active = button_hovered and mouse_down
        local was_active = is_active

        local function select_fallback_tracked()
            if not state or type(activeIds) ~= "table" then
                return
            end

            for i = 1, #quests do
                local candidate = quests[i]
                local id = candidate and candidate.id
                if id and activeIds[id] then
                    state.activeQuestId = id
                    return
                end
            end

            state.activeQuestId = nil
        end

        if just_pressed and button_hovered then
            if was_active then
                if activeIds then
                    activeIds[quest.id] = nil
                end
                quest.accepted = nil
                if state and state.activeQuestId == quest.id then
                    select_fallback_tracked()
                end
            else
                activeIds[quest.id] = true
                quest.accepted = true
                quest.progress = quest.progress or 0
                if state then
                    state.activeQuestId = quest.id
                end
            end
        end

        local button_label = was_active and "Abandon" or "Accept"
        draw_action_button(button_rect, button_label, fonts, button_hovered, button_active, false)
    end

    local detail_top = area_top
    local detail_height = display_area_height

    set_color(window_colors.background or { 0.04, 0.05, 0.07, 0.96 })
    love.graphics.rectangle("fill", detail_x, detail_top, detail_width, detail_height, 4, 4)

    set_color(window_colors.border or { 0.22, 0.28, 0.36, 0.9 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", detail_x + 0.5, detail_top + 0.5, detail_width - 1, detail_height - 1, 4, 4)

    local detail_cursor_y = detail_top + padding * 0.75
    local detail_inner_x = detail_x + padding * 0.75
    local detail_inner_width = math.max(0, detail_width - padding * 1.5)

    if selectedQuest then
        local title_text = selectedQuest.title or ""
        love.graphics.setFont(title_font)
        set_color(window_colors.title_text or { 0.92, 0.95, 1.0, 1 })
        love.graphics.printf(title_text, detail_inner_x, detail_cursor_y, detail_inner_width, "left")
        local title_height = compute_text_block_height(title_font, title_text, detail_inner_width)
        detail_cursor_y = detail_cursor_y + title_height + row_spacing * 1.5

        local objective_text = selectedQuest.objective or ""
        if objective_text ~= "" then
            love.graphics.setFont(summary_font)
            set_color(window_colors.accent or { 0.46, 0.64, 0.72, 1 })
            love.graphics.printf(objective_text, detail_inner_x, detail_cursor_y, detail_inner_width, "left")
            local objective_height = compute_text_block_height(summary_font, objective_text, detail_inner_width)
            detail_cursor_y = detail_cursor_y + objective_height + row_spacing * 1.25
        end

        local summary_text = selectedQuest.summary or ""
        if summary_text ~= "" then
            local body_font = fonts.body or default_font
            love.graphics.setFont(body_font)
            set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
            love.graphics.printf(summary_text, detail_inner_x, detail_cursor_y, detail_inner_width, "left")
            local summary_height = compute_text_block_height(body_font, summary_text, detail_inner_width)
            detail_cursor_y = detail_cursor_y + summary_height + row_spacing * 1.5
        end

        local reward_label = QuestGenerator.rewardLabel(selectedQuest)
        if reward_label ~= "" then
            love.graphics.setFont(summary_font)
            set_color(window_colors.accent_secondary or window_colors.accent or { 0.38, 0.52, 0.58, 1 })
            love.graphics.printf(string.format("Reward: %s", reward_label), detail_inner_x, detail_cursor_y, detail_inner_width, "left")
            local reward_height = compute_text_block_height(summary_font, reward_label, detail_inner_width)
            detail_cursor_y = detail_cursor_y + reward_height + row_spacing * 1.5
        end

        local selected_active = activeIds[selectedQuest.id]
        if selected_active then
            local progress_label = QuestGenerator.progressLabel(selectedQuest)
            local status_text
            if progress_label ~= "" then
                status_text = string.format("Accepted - Progress: %s", progress_label)
            else
                status_text = "This contract is accepted."
            end
            love.graphics.setFont(summary_font)
            set_color(window_colors.accent_player or { 0.3, 0.78, 0.46, 1 })
            love.graphics.printf(status_text, detail_inner_x, detail_cursor_y, detail_inner_width, "left")
            local status_height = compute_text_block_height(summary_font, status_text, detail_inner_width)
            detail_cursor_y = detail_cursor_y + status_height
        end
    else
        love.graphics.setFont(fonts.body or default_font)
        set_color(window_colors.muted or { 0.65, 0.7, 0.8, 1 })
        love.graphics.printf("No contracts available.", detail_inner_x, detail_cursor_y, detail_inner_width, "left")
    end

    if bottom_bar then
        local button_gap = theme_spacing.medium or 16
        local button_height = math.max(24, bottom_bar.height - button_gap)
        local button_width = math.min(200, bottom_bar.width - button_gap * 2)
        local base_y = bottom_bar.y + (bottom_bar.height - button_height) * 0.5
        local refresh_rect = {
            x = bottom_bar.x + (bottom_bar.width - button_width) * 0.5,
            y = base_y,
            width = button_width,
            height = button_height,
        }

        local refresh_hovered = point_in_rect(mouse_x, mouse_y, refresh_rect)
        local refresh_active = refresh_hovered and mouse_down
        if just_pressed and refresh_hovered then
            UIStateManager.refreshStationQuests(context)
        end

        draw_action_button(refresh_rect, "Refresh Contracts", fonts, refresh_hovered, refresh_active, false)
    end
end

return station_quests
