-- Station Window: Interface for interacting with space stations

local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local geometry = require("src.util.geometry")
local QuestGenerator = require("src.stations.quest_generator")
local UIStateManager = require("src.ui.state_manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local station_window = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color
local point_in_rect = geometry.point_in_rect

local DEFAULT_WIDTH = 620
local DEFAULT_HEIGHT = 460

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

local function resolve_fonts()
    local fonts = theme.get_fonts and theme.get_fonts() or theme.fonts or {}
    if not fonts.body then
        fonts.body = love.graphics.getFont()
    end
    return fonts
end

local function resolve_station_name(context)
    local station = context and context.stationDockTarget
    if station then
        if station.name then
            return station.name
        end
        if station.stationName then
            return station.stationName
        end
    end
    return "Space Station"
end

--- Draws the station window
---@param context table The game context
function station_window.draw(context)
    if not (context and context.stationUI and context.stationUI.visible) then
        return
    end

    local state = context.stationUI
    local fonts = resolve_fonts()
    local default_font = fonts.body or love.graphics.getFont()

    if not state.quests then
        UIStateManager.refreshStationQuests(context)
    end

    local vw, vh = love.graphics.getWidth(), love.graphics.getHeight()

    state.width = state.width or math.min(DEFAULT_WIDTH, vw * 0.9)
    state.height = state.height or math.min(DEFAULT_HEIGHT, vh * 0.9)
    state.x = state.x or (vw - state.width) * 0.5
    state.y = state.y or (vh - state.height) * 0.5

    local mouse_x, mouse_y = love.mouse.getPosition()
    local mouse_down = love.mouse.isDown(1)
    local previous_down = state._mouse_down_prev or false

    local frame = window.draw_frame {
        x = state.x,
        y = state.y,
        width = state.width,
        height = state.height,
        title = resolve_station_name(context),
        state = state,
        fonts = fonts,
        bottom_bar_height = (theme_spacing.large or 40),
        input = {
            x = mouse_x,
            y = mouse_y,
            just_pressed = mouse_down and not previous_down,
            is_down = mouse_down,
        },
    }

    state._mouse_down_prev = mouse_down
    local just_pressed = mouse_down and not previous_down

    if not frame then
        return
    end

    if frame.close_clicked then
        station_window.close(context)
        return
    end

    local content = frame.content
    if not content then
        return
    end

    local frame_input = frame.input or {}

    local padding = theme_spacing.medium or 16
    local inner_x = content.x + padding
    local inner_width = math.max(0, content.width - padding * 2)
    local cursor_y = content.y + padding

    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
    love.graphics.setFont((fonts.body_bold or fonts.title or default_font))
    love.graphics.printf("Station Services", inner_x, cursor_y, inner_width, "center")

    cursor_y = cursor_y + ((fonts.body_bold or fonts.title or default_font):getHeight()) + (theme_spacing.small or math.floor(padding * 0.5))

    love.graphics.setFont(fonts.body or default_font)
    set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
    love.graphics.printf("Available Contracts", inner_x, cursor_y, inner_width, "left")

    cursor_y = cursor_y + (fonts.body or default_font):getHeight() + (theme_spacing.small or math.floor(padding * 0.5))

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
    local active_id = state.activeQuestId
    local selected_id = state.selectedQuestId

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
        local is_active = active_id == quest.id

        local fill_color
        if is_selected then
            fill_color = window_colors.accent_secondary or window_colors.accent or { 0.32, 0.52, 0.92, 0.96 }
        elseif hovered then
            fill_color = window_colors.row_hover or { 0.2, 0.26, 0.32, 0.28 }
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
        local text_width = rect.width - row_inner_padding * 2
        local top_text_y = rect.y + row_inner_padding - 2

        love.graphics.setFont(title_font)
        if is_selected then
            set_color(window_colors.title_text or { 0.92, 0.95, 1.0, 1 })
        else
            set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
        end
        love.graphics.printf(quest.title, text_x, top_text_y, text_width, "left")

        love.graphics.setFont(summary_font)
        if is_active then
            set_color(window_colors.accent_player or { 0.3, 0.78, 0.46, 1 })
            local progress_label = QuestGenerator.progressLabel(quest)
            if progress_label ~= "" then
                love.graphics.printf(progress_label, text_x, rect.y + rect.height - summary_font:getHeight() - row_inner_padding * 0.5, text_width, "right")
            else
                love.graphics.printf("Accepted", text_x, rect.y + rect.height - summary_font:getHeight() - row_inner_padding * 0.5, text_width, "right")
            end
            set_color(window_colors.text or { 0.85, 0.9, 1.0, 1 })
        else
            set_color(window_colors.muted or { 0.65, 0.7, 0.8, 1 })
        end

        local summary_y = rect.y + rect.height - summary_font:getHeight() - row_inner_padding
        love.graphics.printf(QuestGenerator.rewardLabel(quest), text_x, summary_y, text_width, "left")
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

        if active_id == selectedQuest.id then
            local progress_label = QuestGenerator.progressLabel(selectedQuest)
            local status_text = progress_label ~= "" and string.format("Active - Progress: %s", progress_label) or "This contract is active."
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

    local bottom_bar = frame.bottom_bar and frame.bottom_bar.inner
    if bottom_bar then
        local button_gap = theme_spacing.medium or 16
        local button_height = math.max(24, bottom_bar.height - button_gap)
        local button_width = math.min(168, (bottom_bar.width - button_gap * 3) * 0.5)
        local base_y = bottom_bar.y + (bottom_bar.height - button_height) * 0.5
        local accept_rect = {
            x = bottom_bar.x + button_gap,
            y = base_y,
            width = button_width,
            height = button_height,
        }
        local refresh_rect = {
            x = accept_rect.x + button_width + button_gap,
            y = base_y,
            width = button_width,
            height = button_height,
        }

        local accept_disabled = not selectedQuest or (active_id == selected_id)
        local accept_hovered = point_in_rect(mouse_x, mouse_y, accept_rect)
        local accept_active = accept_hovered and mouse_down and not accept_disabled
        if just_pressed and accept_hovered and not accept_disabled then
            state.activeQuestId = selected_id
        end

        draw_action_button(accept_rect, accept_disabled and "Accepted" or "Accept Contract", fonts, accept_hovered, accept_active, accept_disabled)

        local refresh_hovered = point_in_rect(mouse_x, mouse_y, refresh_rect)
        local refresh_active = refresh_hovered and mouse_down
        if just_pressed and refresh_hovered then
            UIStateManager.refreshStationQuests(context)
        end

        draw_action_button(refresh_rect, "Refresh Contracts", fonts, refresh_hovered, refresh_active, false)
    end
end

--- Opens the station window via UI state manager
---@param context table The game context
function station_window.open(context)
    if not context then
        return
    end
    UIStateManager.showStationUI(context)
end

--- Closes the station window via UI state manager
---@param context table The game context
function station_window.close(context)
    if not context then
        return
    end
    UIStateManager.hideStationUI(context)
end

--- Toggles the station window visibility
---@param context table The game context
function station_window.toggle(context)
    if not context then
        return
    end
    if UIStateManager.isStationUIVisible(context) then
        UIStateManager.hideStationUI(context)
    else
        UIStateManager.showStationUI(context)
    end
end

--- Checks if the station window is visible
---@param context table The game context
---@return boolean
function station_window.is_visible(context)
    return UIStateManager.isStationUIVisible(context)
end

--- Handles key input
---@param context table The game context
---@param key string
---@return boolean
function station_window.keypressed(context, key)
    if key == "escape" and station_window.is_visible(context) then
        station_window.close(context)
        return true
    end
    return false
end

--- Handles wheel scrolling
---@param context table
---@param x number
---@param y number
---@return boolean
function station_window.wheelmoved(context, x, y)
    if station_window.is_visible(context) then
        return true
    end
    return false
end

return station_window
