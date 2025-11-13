local theme = require("src.ui.theme")
local AudioManager = require("src.audio.manager")
local geometry = require("src.util.geometry")
---@diagnostic disable-next-line: undefined-global
local love = love

local ui_button = {}

local hover_state = {}

local resolve_rect = geometry.resolve_rect
local point_in_rect = geometry.point_in_rect

local function rect_key(rect, fallback)
    if fallback then
        return fallback
    end

    local x, y, width, height = resolve_rect(rect)
    return table.concat({ x or 0, y or 0, width or 0, height or 0 }, ":")
end

---Renders a themed UI button and returns interaction state
---@param options table
---@return table result
function ui_button.render(options)
    options = options or {}

    local rect = options.rect or {}
    local label = options.label or ""
    local disabled = options.disabled or false

    local fonts = options.fonts or theme.get_fonts()
    local font = options.font or fonts.body or love.graphics.getFont()

    -- Use theme colors consistently
    local window_colors = theme.colors.window or {}
    local spacing = theme.spacing or {}
    
    local base_color = options.fill_color or options.fillColor or window_colors.button or { 0.08, 0.08, 0.12, 1 }
    local hover_color = options.hover_color or options.hoverColor or window_colors.button_hover or { 0.18, 0.24, 0.32, 1 }
    local active_color = options.active_color or options.activeColor or window_colors.button_active or hover_color
    local border_color = options.border_color or options.borderColor or window_colors.border or { 0.12, 0.18, 0.28, 0.9 }
    local text_color = options.text_color or options.textColor or window_colors.title_text or { 0.85, 0.85, 0.9, 1 }
    local disabled_color = options.disabled_color or window_colors.muted or { 0.5, 0.55, 0.6, 1 }

    local x, y, width, height = resolve_rect(rect)

    local input = options.input or {}
    local mouse_x = input.x
    local mouse_y = input.y
    local just_pressed = not disabled and input.just_pressed or false
    local is_down = not disabled and input.is_down or false

    local hovered = false
    if not disabled and mouse_x and mouse_y then
        hovered = point_in_rect(mouse_x, mouse_y, rect)
    end

    local clicked = hovered and just_pressed or false
    local active = hovered and is_down or false

    -- Use theme spacing values
    local corner_radius = options.corner_radius or options.radius or spacing.button_corner_radius or 6
    local border_width = options.border_width or options.borderWidth or 1

    local fill = base_color
    local current_text_color = text_color
    local current_border_color = border_color
    
    if disabled then
        fill = options.disabled_fill or { 
            base_color[1] * 0.6, 
            base_color[2] * 0.6, 
            base_color[3] * 0.6, 
            base_color[4] or 1 
        }
        current_text_color = options.disabled_text_color or disabled_color
        current_border_color = options.border_color_disabled or options.disabled_border or border_color
    elseif active then
        fill = active_color
    elseif hovered then
        fill = hover_color
    end

    love.graphics.push("all")

    -- Draw button background
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", x, y, width, height, corner_radius, corner_radius)

    -- Draw border
    if border_width and border_width > 0 then
        love.graphics.setColor(current_border_color)
        love.graphics.setLineWidth(border_width)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, corner_radius, corner_radius)
    end

    -- Draw text
    local align = options.align or "center"
    local text_padding = options.text_padding or spacing.button_padding or 8
    local text_offset_x = options.text_offset_x or 0
    local text_offset_y = options.text_offset_y or 0

    love.graphics.setFont(font)
    love.graphics.setColor(current_text_color)

    local text_x = x + text_padding + text_offset_x
    local text_y = y + (height - font:getHeight()) * 0.5 + text_offset_y
    local text_width = math.max(0, width - text_padding * 2)

    love.graphics.printf(label, text_x, text_y, text_width, align)

    love.graphics.pop()

    local sounds = options.sounds or {}
    local click_sound = options.click_sound or options.clickSound or sounds.click or "sfx:button_click"
    local hover_sound = options.hover_sound or options.hoverSound or sounds.hover or "sfx:button_hover"

    local key = rect_key(rect, options.id)

    if click_sound and clicked then
        AudioManager.play_sfx(click_sound)
    end

    if hover_sound and not disabled then
        if hovered then
            if key and not hover_state[key] then
                AudioManager.play_sfx(hover_sound)
            end
            if key then
                hover_state[key] = true
            end
        elseif key then
            hover_state[key] = nil
        end
    elseif key then
        hover_state[key] = nil
    end

    return {
        hovered = hovered,
        active = active,
        clicked = clicked,
        disabled = disabled,
        rect = {
            x = x,
            y = y,
            width = width,
            height = height,
        },
    }
end

function ui_button.point_in_rect(px, py, rect)
    return point_in_rect(px, py, rect)
end

return ui_button
