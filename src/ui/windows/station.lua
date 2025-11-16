-- Station Window: Interface for interacting with space stations

local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local geometry = require("src.util.geometry")
local window_geometry = require("src.ui.util.window_geometry")
local QuestGenerator = require("src.stations.quest_generator")
local UIStateManager = require("src.ui.state_manager")
local StationQuests = require("src.ui.windows.station_quests")
local StationShop = require("src.ui.windows.station_shop")

---@diagnostic disable-next-line: undefined-global
local love = love

local station_window = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color
local point_in_rect = geometry.point_in_rect

local DEFAULT_WIDTH = 640
local DEFAULT_HEIGHT = 520

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
    local uiInput = context.uiInput
    if uiInput then
        uiInput.mouseCaptured = true
        uiInput.keyboardCaptured = true
    end

    local fonts = resolve_fonts()
    local default_font = fonts.body or love.graphics.getFont()

    if not state.quests then
        UIStateManager.refreshStationQuests(context)
    end

    local dims = window_geometry.centered({
        preferred_width = DEFAULT_WIDTH,
        preferred_height = DEFAULT_HEIGHT,
        min_width = 520,
        min_height = 420,
    })

    local mouse_x, mouse_y = love.mouse.getPosition()
    local mouse_down = love.mouse.isDown(1)
    local previous_down = state._mouse_down_prev or false

    local frame = window.draw_frame {
        x = state.x or dims.x,
        y = state.y or dims.y,
        width = dims.width,
        height = dims.height,
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

    local padding = theme_spacing.medium or 16
    local tab_spacing = theme_spacing.small or math.floor(padding * 0.5)
    local tab_height = (fonts.body_bold or fonts.title or default_font):getHeight() + tab_spacing * 2

    state.activeTab = state.activeTab or "shop"

    local tabs = {
        { id = "shop", label = "Shop" },
        { id = "quests", label = "Quests" },
    }

    local tab_x = content.x + padding
    local tab_y = content.y + padding * 0.5
    local tab_max_width = math.max(80, (content.width - padding * 2) / #tabs)

    state._tabRects = state._tabRects or {}
    for i = 1, #state._tabRects do
        state._tabRects[i] = nil
    end

    love.graphics.setFont(fonts.body_bold or fonts.title or default_font)

    for index = 1, #tabs do
        local tab = tabs[index]
        local label = tab.label
        local text_width = love.graphics.getFont():getWidth(label)
        local width = math.min(tab_max_width, text_width + padding * 2)
        local rect = {
            x = tab_x,
            y = tab_y,
            width = width,
            height = tab_height,
        }

        state._tabRects[#state._tabRects + 1] = {
            id = tab.id,
            rect = rect,
        }

        local hovered = point_in_rect(mouse_x, mouse_y, rect)
        local is_active = state.activeTab == tab.id

        local bg_color
        if is_active then
            bg_color = window_colors.accent_secondary or window_colors.accent or { 0.26, 0.42, 0.78, 1 }
        elseif hovered then
            bg_color = window_colors.row_hover or { 0.18, 0.22, 0.3, 1 }
        else
            bg_color = window_colors.top_bar or window_colors.background or { 0.04, 0.05, 0.07, 1 }
        end

        set_color(bg_color)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 4, 4)

        set_color(window_colors.border or { 0.22, 0.28, 0.36, 0.9 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.width - 1, rect.height - 1, 4, 4)

        if just_pressed and hovered then
            state.activeTab = tab.id
        end

        local text_y = rect.y + (rect.height - love.graphics.getFont():getHeight()) * 0.5
        set_color(window_colors.title_text or window_colors.text or { 0.85, 0.9, 1.0, 1 })
        love.graphics.print(label, rect.x + (rect.width - text_width) * 0.5, text_y)

        tab_x = tab_x + width + tab_spacing
    end

    local content_top = tab_y + tab_height + padding * 0.5
    local inner_content = {
        x = content.x,
        y = content_top,
        width = content.width,
        height = math.max(0, content.y + content.height - content_top),
    }

    local child_params = {
        state = state,
        fonts = fonts,
        default_font = default_font,
        content = inner_content,
        mouse_x = mouse_x,
        mouse_y = mouse_y,
        mouse_down = mouse_down,
        just_pressed = just_pressed,
        bottom_bar = frame.bottom_bar and frame.bottom_bar.inner,
    }

    if state.activeTab == "quests" then
        StationQuests.draw(context, child_params)
    else
        StationShop.draw(context, child_params)
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
    if not station_window.is_visible(context) then
        return false
    end
    
    local state = context and context.stationUI
    if not state then
        return true
    end
    
    -- Forward to active tab
    if state.activeTab == "shop" and StationShop.wheelmoved then
        return StationShop.wheelmoved(context, x, y)
    elseif state.activeTab == "quests" and StationQuests.wheelmoved then
        return StationQuests.wheelmoved(context, x, y)
    end
    
    return true
end

return station_window
