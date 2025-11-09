local theme = require("src.ui.theme")
---@diagnostic disable-next-line: undefined-global
local love = love

local window = {}

local function set_color(color)
    if type(color) == "table" then
        love.graphics.setColor(
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            color[4] or 1
        )
        return
    end
    love.graphics.setColor(1, 1, 1, 1)
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

    local padding = options.padding or spacing.window_padding
    local corner_radius = options.corner_radius or spacing.window_corner_radius
    local top_bar_height = options.top_bar_height or metrics.top_bar_height
    local bottom_bar_height = options.bottom_bar_height or metrics.bottom_bar_height
    local glow_extra = spacing.window_glow_extra
    local shadow_offset = spacing.window_shadow_offset

    local fonts = options.fonts or theme.get_fonts()

    local previous_font = love.graphics.getFont()

    if state then
        state.width = width
        state.height = height
        if state.x == nil then
            state.x = x
        end
        if state.y == nil then
            state.y = y
        end
        x = state.x
        y = state.y
    end

    local close_button_rect
    if show_close then
        local close_size = options.close_button_size or metrics.close_button_size
        local close_x = x + width - padding - close_size
        local close_y = y + (top_bar_height - close_size) * 0.5
        close_button_rect = {
            x = close_x,
            y = close_y,
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

    local close_clicked = false

    if state then
        local mouse_x = input.x
        local mouse_y = input.y
        local just_pressed = input.just_pressed
        local is_down = input.is_down

        if just_pressed and mouse_x and mouse_y then
            if close_button_rect and mouse_x >= close_button_rect.x and mouse_x <= close_button_rect.x + close_button_rect.width and mouse_y >= close_button_rect.y and mouse_y <= close_button_rect.y + close_button_rect.height then
                close_clicked = true
            end

            if mouse_x >= top_bar_rect.x and mouse_x <= top_bar_rect.x + top_bar_rect.width and mouse_y >= top_bar_rect.y and mouse_y <= top_bar_rect.y + top_bar_rect.height then
                state.dragging = true
                state.drag_offset_x = mouse_x - x
                state.drag_offset_y = mouse_y - y
            end
        end

        if state.dragging and is_down and mouse_x and mouse_y then
            local offset_x = state.drag_offset_x or 0
            local offset_y = state.drag_offset_y or 0
            local new_x = mouse_x - offset_x
            local new_y = mouse_y - offset_y
            local screen_width = love.graphics.getWidth()
            local screen_height = love.graphics.getHeight()

            new_x = math.max(0, math.min(new_x, screen_width - width))
            new_y = math.max(0, math.min(new_y, screen_height - top_bar_height))

            state.x = new_x
            state.y = new_y
            x = new_x
            y = new_y
        end

        if not is_down then
            state.dragging = false
        end

        if state.x then
            top_bar_rect.x = state.x
        end
        if state.y then
            top_bar_rect.y = state.y
        end

        if close_button_rect then
            close_button_rect.x = (state.x or x) + width - padding - close_button_rect.size
            close_button_rect.y = (state.y or y) + (top_bar_height - close_button_rect.size) * 0.5
        end
    end

    -- Update local references in case state adjusted position
    if state then
        x = state.x or x
        y = state.y or y
    end
    top_bar_rect.x = x
    top_bar_rect.y = y
    if close_button_rect then
        close_button_rect.x = x + width - padding - close_button_rect.size
        close_button_rect.y = y + (top_bar_height - close_button_rect.size) * 0.5
    end

    -- Outer glow
    set_color(colors.glow)
    love.graphics.rectangle(
        "fill",
        x - glow_extra * 0.5,
        y - glow_extra * 0.5,
        width + glow_extra,
        height + glow_extra,
        corner_radius + 2,
        corner_radius + 2
    )

    -- Drop shadow
    set_color(colors.shadow)
    love.graphics.rectangle(
        "fill",
        x + shadow_offset,
        y + shadow_offset,
        width,
        height,
        corner_radius - 1,
        corner_radius - 1
    )

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

    -- Title text (with glow)
    if title then
        love.graphics.setFont(fonts.title)
        set_color(colors.glow)
        local title_y = y + (top_bar_height - fonts.title:getHeight()) * 0.5
        love.graphics.print(title, x + padding + 1, title_y + 1)
        set_color(colors.title_text)
        love.graphics.print(title, x + padding, title_y)
    end

    -- Close button
    if show_close then
        set_color(colors.close_button)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(close_button_rect.x, close_button_rect.y, close_button_rect.x + close_button_rect.size, close_button_rect.y + close_button_rect.size)
        love.graphics.line(close_button_rect.x, close_button_rect.y + close_button_rect.size, close_button_rect.x + close_button_rect.size, close_button_rect.y)
    end

    love.graphics.setFont(previous_font)

    return {
        padding = padding,
        top_bar_height = top_bar_height,
        bottom_bar_height = bottom_bar_height,
        content = {
            x = x + padding,
            y = y + top_bar_height + padding,
            width = width - padding * 2,
            height = height - top_bar_height - bottom_bar_height - padding * 2,
        },
        close_button = close_button_rect,
        top_bar = top_bar_rect,
        close_clicked = close_clicked,
        dragging = state and state.dragging or false,
    }
end

return window
