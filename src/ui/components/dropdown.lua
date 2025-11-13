local theme = require("src.ui.theme")
local geometry = require("src.util.geometry")

---@diagnostic disable-next-line: undefined-global
local love = love

local dropdown = {}

dropdown.defaults = {
    base_height = 32,
    item_height = 32,
    placeholder = "Select",
}

function dropdown.create_state(initial)
    local state = {
        open = false,
        itemRects = {},
        rect = nil,
        selected_index = nil,
        selected_label = nil,
    }

    if type(initial) == "table" then
        state.open = not not initial.open
    end

    return state
end

local resolve_rect = geometry.resolve_rect
local point_in_rect = geometry.point_in_rect

function dropdown.measure(options)
    options = options or {}

    local base_height = options.base_height or dropdown.defaults.base_height
    local item_height = options.item_height or options.base_height or dropdown.defaults.item_height
    local state = options.state
    local is_open = options.is_open

    if is_open == nil and state then
        is_open = state.open
    end

    local items = options.items or (state and state.items) or {}
    if is_open then
        return base_height + item_height * #items
    end

    return base_height
end

local function get_item_label(item)
    if type(item) == "table" then
        return item.label or item.text or item.name or (item.value and tostring(item.value)) or tostring(item[1] or "")
    end

    if item == nil then
        return ""
    end

    return tostring(item)
end

function dropdown.render(options)
    options = options or {}

    local rect = options.rect or {}
    local items = options.items or {}
    local state = options.state or {}
    local fonts = options.fonts or theme.get_fonts()
    local input = options.input or {}

    local window_colors = theme.colors.window or {}
    local text_color = window_colors.text or { 0.85, 0.85, 0.9, 1 }
    local border_color = window_colors.border or { 0.12, 0.18, 0.28, 0.9 }
    local base_color = window_colors.input_background or { 0.06, 0.07, 0.1, 1 }
    local arrow_color = window_colors.title_text or window_colors.text or text_color
    local hover_color = window_colors.button_hover or { 0.18, 0.24, 0.32, 1 }
    local active_color = window_colors.button_active or hover_color
    local list_color = window_colors.button or { 0.12, 0.16, 0.22, 1 }

    local x, y, width, height = resolve_rect(rect)
    local item_height = options.item_height or height or dropdown.defaults.item_height
    local base_height = options.base_height or height or dropdown.defaults.base_height

    state.open = state.open == true
    state.itemRects = state.itemRects or {}
    for i = #state.itemRects, 1, -1 do
        state.itemRects[i] = nil
    end

    state.rect = { x = x, y = y, w = width, h = base_height }
    state.items = items
    state.item_height = item_height

    local selected_index = options.selected_index
    local selected_label = options.selected_label
    if (not selected_label or selected_label == "") and selected_index and items[selected_index] then
        if type(options.label_formatter) == "function" then
            selected_label = options.label_formatter(items[selected_index], selected_index)
        else
            selected_label = get_item_label(items[selected_index])
        end
    end

    if not selected_label or selected_label == "" then
        selected_label = options.placeholder or dropdown.defaults.placeholder
    end

    state.selected_index = selected_index
    state.selected_label = selected_label

    love.graphics.push("all")

    love.graphics.setColor(base_color)
    love.graphics.rectangle("fill", x, y, width, base_height, 4, 4)

    love.graphics.setColor(border_color)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, base_height - 1, 4, 4)

    love.graphics.setFont(fonts.body or love.graphics.getFont())
    love.graphics.setColor(text_color)
    local base_font = fonts.body or love.graphics.getFont()
    love.graphics.printf(selected_label, x + 10, y + (base_height - base_font:getHeight()) * 0.5, width - 40, "left")

    local arrow_x = x + width - 18
    local arrow_y = y + base_height * 0.5
    love.graphics.setColor(arrow_color)
    if state.open then
        love.graphics.polygon("fill", arrow_x - 6, arrow_y - 2, arrow_x + 6, arrow_y - 2, arrow_x, arrow_y + 4)
    else
        love.graphics.polygon("fill", arrow_x - 6, arrow_y + 2, arrow_x + 6, arrow_y + 2, arrow_x, arrow_y - 4)
    end

    if state.open and #items > 0 then
        local list_font = fonts.small or base_font
        love.graphics.setFont(list_font)
        local mouse_x = input.x
        local mouse_y = input.y

        for index, item in ipairs(items) do
            local item_y = y + base_height + (index - 1) * item_height
            local item_rect = {
                x = x,
                y = item_y,
                w = width,
                h = item_height,
            }

            state.itemRects[index] = item_rect

            local hovered = mouse_x and mouse_y and point_in_rect(mouse_x, mouse_y, item_rect)
            local fill = list_color

            if hovered then
                fill = hover_color
            elseif selected_index == index then
                fill = active_color
            end

            love.graphics.setColor(fill)
            love.graphics.rectangle("fill", item_rect.x, item_rect.y, item_rect.w, item_rect.h, 4, 4)

            love.graphics.setColor(border_color)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", item_rect.x + 0.5, item_rect.y + 0.5, item_rect.w - 1, item_rect.h - 1, 4, 4)

            love.graphics.setColor(text_color)
            love.graphics.printf(get_item_label(item), item_rect.x + 10, item_rect.y + (item_rect.h - list_font:getHeight()) * 0.5, item_rect.w - 20, "left")
        end
    else
        for i = #state.itemRects, 1, -1 do
            state.itemRects[i] = nil
        end
    end

    love.graphics.pop()

    return dropdown.measure {
        base_height = base_height,
        item_height = item_height,
        state = state,
        items = items,
    }
end

function dropdown.handle_mouse(state, input)
    if not (state and input and input.just_pressed) then
        return nil
    end

    local mouse_x = input.x
    local mouse_y = input.y

    if not (mouse_x and mouse_y) then
        return nil
    end

    local consumed = false
    local selected_index
    local toggled = false

    if state.rect and point_in_rect(mouse_x, mouse_y, state.rect) then
        state.open = not state.open
        consumed = true
        toggled = true
        return {
            consumed = consumed,
            toggled = toggled,
            open = state.open,
        }
    end

    if not state.open then
        return nil
    end

    local was_open = true
    local item_rects = state.itemRects or {}
    for index, item_rect in ipairs(item_rects) do
        if point_in_rect(mouse_x, mouse_y, item_rect) then
            selected_index = index
            consumed = true
            break
        end
    end

    state.open = false

    if selected_index then
        state.selected_index = selected_index
        state.selected_label = nil
        return {
            consumed = true,
            selected_index = selected_index,
            open = state.open,
        }
    end

    return {
        consumed = consumed or was_open,
        open = state.open,
    }
end

return dropdown
