local theme = require("src.ui.theme")
---@diagnostic disable-next-line: undefined-global
local love = love

local window = {}
local set_color = theme.utils.set_color

local function point_in_rect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.width and
           py >= rect.y and py <= rect.y + rect.height
end

local function clamp(value, min_val, max_val)
    return math.max(min_val, math.min(value, max_val))
end

function window.draw_frame(options)
    local colors = theme.colors.window
    local spacing = theme.spacing
    local metrics = theme.window

    local x = options.x or 0
    local y = options.y or 0
    local width = options.width or 0
    local height = options.height or 0
    local title = options.title
    local show_close = options.show_close ~= false
    local state = options.state
    local input = options.input or {}
    local mouse_x = input.x
    local mouse_y = input.y
    local just_pressed = input.just_pressed
    local is_down = input.is_down

    local padding = options.padding or spacing.window_padding
    local corner_radius = options.corner_radius or spacing.window_corner_radius
    local top_bar_height = options.top_bar_height or metrics.top_bar_height
    local bottom_bar_height = options.bottom_bar_height or metrics.bottom_bar_height
    local fonts = options.fonts or theme.get_fonts()
    local previous_font = love.graphics.getFont()

    -- Initialize state position
    if state then
        state.width = width
        state.height = height
        state.x = state.x or x
        state.y = state.y or y
        x = state.x
        y = state.y
    end

    -- Define close button rect
    local close_button_rect
    if show_close then
        local close_size = options.close_button_size or metrics.close_button_size
        close_button_rect = {
            x = x + width - padding - close_size,
            y = y + (top_bar_height - close_size) * 0.5,
            width = close_size,
            height = close_size,
            size = close_size,
        }
    end

    local top_bar_rect = {
        x = x,
        y = y,
        width = width,
        height = top_bar_height,
    }

    local bottom_bar_rect
    if bottom_bar_height > 0 then
        local bar_y = y + height - bottom_bar_height
        bottom_bar_rect = {
            x = x,
            y = bar_y,
            width = width,
            height = bottom_bar_height,
        }
    end

    local close_clicked = false
    local close_hovered = false

    -- Handle input
    if state and mouse_x and mouse_y then
        if just_pressed then
            if close_button_rect and point_in_rect(mouse_x, mouse_y, close_button_rect) then
                close_clicked = true
            elseif point_in_rect(mouse_x, mouse_y, top_bar_rect) then
                state.dragging = true
                state.drag_offset_x = mouse_x - x
                state.drag_offset_y = mouse_y - y
            end
        end

        if state.dragging and is_down then
            local offset_x = state.drag_offset_x or 0
            local offset_y = state.drag_offset_y or 0
            local screen_width = love.graphics.getWidth()
            local screen_height = love.graphics.getHeight()

            state.x = clamp(mouse_x - offset_x, 0, screen_width - width)
            state.y = clamp(mouse_y - offset_y, 0, screen_height - top_bar_height)
            x = state.x
            y = state.y
        end

        if not is_down then
            state.dragging = false
        end

        -- Update rects after position change
        top_bar_rect.x = x
        top_bar_rect.y = y
        if close_button_rect then
            close_button_rect.x = x + width - padding - close_button_rect.size
            close_button_rect.y = y + (top_bar_height - close_button_rect.size) * 0.5
            close_hovered = point_in_rect(mouse_x, mouse_y, close_button_rect)
        end
    end

    -- Main window background
    set_color(colors.background)
    love.graphics.rectangle("fill", x, y, width, height, corner_radius, corner_radius)

    -- Window border
    set_color(colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, corner_radius, corner_radius)

    -- Top bar
    set_color(colors.top_bar)
    love.graphics.rectangle("fill", x + 1, y + 1, width - 2, top_bar_height, corner_radius, corner_radius)

    -- Top bar accent line
    set_color(colors.accent)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 1, y + top_bar_height + 1, x + width - 1, y + top_bar_height + 1)

    -- Bottom bar
    if bottom_bar_rect then
        set_color(colors.bottom_bar or colors.background)
        love.graphics.rectangle(
            "fill",
            x + 1,
            bottom_bar_rect.y + 1,
            math.max(0, width - 2),
            math.max(0, bottom_bar_height - 2)
        )

        set_color(colors.accent)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 1, bottom_bar_rect.y, x + width - 1, bottom_bar_rect.y)

        bottom_bar_rect.inner = {
            x = x + padding,
            y = bottom_bar_rect.y + 2,
            width = math.max(0, width - padding * 2),
            height = math.max(0, bottom_bar_height - 4),
        }
    end

    -- Title text (with glow)
    if title then
        love.graphics.setFont(fonts.title)
        local title_y = y + (top_bar_height - fonts.title:getHeight()) * 0.5
        set_color(colors.glow)
        love.graphics.print(title, x + padding + 1, title_y + 1)
        set_color(colors.title_text)
        love.graphics.print(title, x + padding, title_y)
    end

    -- Close button
    if show_close and close_button_rect then
        set_color(close_hovered and colors.close_button_hover or colors.close_button)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(
            close_button_rect.x,
            close_button_rect.y,
            close_button_rect.x + close_button_rect.size,
            close_button_rect.y + close_button_rect.size
        )
        love.graphics.line(
            close_button_rect.x,
            close_button_rect.y + close_button_rect.size,
            close_button_rect.x + close_button_rect.size,
            close_button_rect.y
        )
    end

    love.graphics.setFont(previous_font)

    local content_y = y + top_bar_height
    local content_height = math.max(0, height - top_bar_height - bottom_bar_height)
    local inner_width = math.max(0, width - padding * 2)
    local inner_height = math.max(0, content_height - padding * 2)

    if bottom_bar_rect and not bottom_bar_rect.inner then
        bottom_bar_rect.inner = {
            x = x + padding,
            y = bottom_bar_rect.y + 2,
            width = math.max(0, width - padding * 2),
            height = math.max(0, bottom_bar_height - 4),
        }
    end

    return {
        padding = padding,
        top_bar_height = top_bar_height,
        bottom_bar_height = bottom_bar_height,
        content = {
            x = x + padding,
            y = content_y + padding,
            width = inner_width,
            height = inner_height,
        },
        content_full = {
            x = x,
            y = content_y,
            width = width,
            height = content_height,
        },
        bottom_bar = bottom_bar_rect,
        close_button = close_button_rect,
        top_bar = top_bar_rect,
        close_clicked = close_clicked,
        close_hovered = close_hovered,
        dragging = state and state.dragging or false,
    }
end

return window
