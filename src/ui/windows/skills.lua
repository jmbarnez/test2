local theme = require("src.ui.theme")
local window = require("src.ui.window")
local UIStateManager = require("src.ui.state_manager")
local PlayerManager = require("src.player.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local skills_window = {}

local window_colors = theme.colors.window or {}
local spacing = theme.spacing or theme.get_spacing()
local set_color = theme.utils.set_color

local function get_dimensions()
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    local margin = (spacing and spacing.window_margin) or 48
    local width = math.min(520, screen_width - margin * 2)
    local height = math.min(480, screen_height - margin * 2)
    local x = (screen_width - width) * 0.5
    local y = (screen_height - height) * 0.5

    x = math.max(margin, math.min(x, screen_width - width - margin))
    y = math.max(margin, math.min(y, screen_height - height - margin))

    return {
        x = x,
        y = y,
        width = width,
        height = height,
    }
end

local function sort_entries(source, key_name)
    local entries = {}
    for id, data in pairs(source or {}) do
        if type(data) == "table" then
            entries[#entries + 1] = {
                id = id,
                data = data,
            }
        end
    end

    table.sort(entries, function(a, b)
        local da = a.data or {}
        local db = b.data or {}
        local order_a = da.order or 0
        local order_b = db.order or 0
        if order_a == order_b then
            local label_a = (da.label or a.id or ""):lower()
            local label_b = (db.label or b.id or ""):lower()
            return label_a < label_b
        end
        return order_a < order_b
    end)

    return entries
end

local function resolve_pilot(context)
    if not context then
        return nil
    end

    local state = context.state or context

    if state.playerPilot then
        return state.playerPilot
    end

    local ship = PlayerManager.getCurrentShip(state)
    if ship then
        if ship.pilot then
            return ship.pilot
        end

        local pilot = PlayerManager.ensurePilot(state, ship.playerId)
        if pilot then
            ship.pilot = pilot
            pilot.currentShip = pilot.currentShip or ship
            return pilot
        end
    end

    if state.localPlayerId then
        return PlayerManager.ensurePilot(state, state.localPlayerId)
    end

    return nil
end

local function draw_skill_entry(skill, x, y, width, fonts, alternate)
    skill = skill or {}

    local name_font = fonts.body
    local meta_font = fonts.tiny or fonts.small or fonts.body

    local row_padding = 12
    local bar_height = 12
    local spacing_small = 8

    local row_height = row_padding * 2 + name_font:getHeight() + spacing_small + bar_height

    if alternate and window_colors.row_alternate then
        set_color(window_colors.row_alternate)
        love.graphics.rectangle("fill", x, y, width, row_height)
    end

    local text_color = window_colors.text or { 0.75, 0.78, 0.82, 1 }

    local cursor_y = y + row_padding
    local inner_width = math.max(0, width - row_padding * 2)

    love.graphics.setFont(name_font)
    set_color(text_color)
    love.graphics.print(skill.label or skill.name or "Skill", x + row_padding, cursor_y)

    local level_text = string.format("Lv %d", math.max(1, math.floor((skill.level or 1) + 0.5)))
    love.graphics.printf(level_text, x + row_padding, cursor_y, inner_width, "right")

    cursor_y = cursor_y + name_font:getHeight() + spacing_small

    local xp = math.max(0, skill.xp or 0)
    local required = math.max(1, skill.xpRequired or 1)
    local progress = math.min(1, xp / required)

    local bar_x = x + row_padding
    local bar_width = inner_width

    set_color(window_colors.progress_background or { 0.07, 0.08, 0.11, 1 })
    love.graphics.rectangle("fill", bar_x, cursor_y, bar_width, bar_height, 2, 2)

    local fill_width = math.floor(bar_width * progress + 0.5)
    if fill_width > 0 then
        set_color(window_colors.progress_fill or window_colors.accent or { 0.25, 0.55, 0.92, 1 })
        love.graphics.rectangle("fill", bar_x, cursor_y, fill_width, bar_height, 2, 2)
    end

    set_color(window_colors.border or { 0.12, 0.16, 0.22, 0.8 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bar_x + 0.5, cursor_y + 0.5, bar_width - 1, bar_height - 1, 2, 2)

    set_color(text_color)
    love.graphics.setFont(meta_font)
    local xp_text = string.format("%d / %d XP", math.floor(xp + 0.5), math.floor(required + 0.5))
    love.graphics.printf(xp_text, bar_x, cursor_y + (bar_height - meta_font:getHeight()) * 0.5, bar_width, "center")

    return row_height
end

function skills_window.draw(context)
    local state = context.skillsUI
    if not state then
        state = {}
        context.skillsUI = state
    end

    if not state.visible then
        state.dragging = false
        state._was_mouse_down = love.mouse.isDown(1)
        return false
    end

    local ui_input = context.uiInput
    if ui_input then
        ui_input.mouseCaptured = true
        ui_input.keyboardCaptured = true
    end

    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_mouse_down = love.mouse.isDown(1)
    local just_pressed = is_mouse_down and not state._was_mouse_down

    local fonts = theme.get_fonts()
    local dims = get_dimensions()

    love.graphics.push("all")
    love.graphics.origin()

    local frame = window.draw_frame {
        x = state.x or dims.x,
        y = state.y or dims.y,
        width = state.width or dims.width,
        height = state.height or dims.height,
        title = "Skills",
        fonts = fonts,
        state = state,
        show_close = true,
        input = {
            x = mouse_x,
            y = mouse_y,
            is_down = is_mouse_down,
            just_pressed = just_pressed,
        },
    }

    local content = frame.content

    love.graphics.setScissor(content.x, content.y, content.width, content.height)

    local pilot = resolve_pilot(context)
    local categories = pilot and sort_entries(pilot.skills, "skills") or {}

    local cursor_y = content.y
    local category_spacing = 18
    local row_spacing = 10

    if #categories == 0 then
        love.graphics.setFont(fonts.body)
        set_color(window_colors.muted or { 0.45, 0.5, 0.55, 1 })
        love.graphics.printf("No skills tracked yet.", content.x, content.y + (content.height - fonts.body:getHeight()) * 0.5, content.width, "center")
    else
        for _, entry in ipairs(categories) do
            local category = entry.data or {}
            local heading = (category.label or entry.id or "Category"):upper()

            love.graphics.setFont(fonts.small or fonts.body)
            set_color(window_colors.title_text or { 0.86, 0.9, 0.94, 1 })
            love.graphics.print(heading, content.x, cursor_y)
            cursor_y = cursor_y + (fonts.small or fonts.body):getHeight() + 6

            local skills = sort_entries(category.skills or {})
            if #skills == 0 then
                love.graphics.setFont(fonts.tiny or fonts.small or fonts.body)
                set_color(window_colors.muted or { 0.45, 0.5, 0.55, 1 })
                love.graphics.print("No tracked skills in this category.", content.x + 8, cursor_y)
                cursor_y = cursor_y + (fonts.tiny or fonts.small or fonts.body):getHeight() + category_spacing
            else
                for index, skill_entry in ipairs(skills) do
                    local row_height = draw_skill_entry(skill_entry.data, content.x, cursor_y, content.width, fonts, index % 2 == 0)
                    cursor_y = cursor_y + row_height + row_spacing
                end
                cursor_y = cursor_y + category_spacing
            end
        end
    end

    love.graphics.setScissor()

    if frame.close_clicked then
        love.graphics.pop()
        UIStateManager.hideSkillsUI(context)
        state._was_mouse_down = is_mouse_down
        return true
    end

    love.graphics.pop()

    state._was_mouse_down = is_mouse_down

    return true
end

return skills_window
