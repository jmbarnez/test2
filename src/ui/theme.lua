local constants = require("src.constants.game")
---@diagnostic disable-next-line: undefined-global
local love = love

local theme = {
    font_sizes = {
        title = 16,
        body = 13,
        small = 11,
        tiny = 9,
    },
    colors = {
        window = {
            shadow = { 0, 0, 0, 0.9 },
            background = { 0.02, 0.02, 0.04, 0.98 },
            border = { 0.08, 0.08, 0.12, 0.8 },
            top_bar = { 0.01, 0.01, 0.02, 1 },
            bottom_bar = { 0.01, 0.01, 0.02, 1 },
            title_text = { 0.85, 0.85, 0.9, 1 },
            text = { 0.75, 0.75, 0.8, 1 },
            muted = { 0.4, 0.4, 0.45, 1 },
            row_alternate = { 0.04, 0.04, 0.06, 0.5 },
            row_hover = { 0.06, 0.06, 0.1, 0.3 },
            progress_background = { 0.03, 0.03, 0.05, 1 },
            progress_fill = { 0.15, 0.4, 0.6, 1 },
            warning = { 0.7, 0.3, 0.3, 1 },
            accent = { 0.2, 0.5, 0.7, 1 },
            button = { 0.05, 0.05, 0.08, 1 },
            button_hover = { 0.08, 0.08, 0.12, 1 },
            icon_background = { 0.03, 0.03, 0.05, 0.9 },
            icon_border = { 0.1, 0.1, 0.15, 0.6 },
            slot_background = { 0.02, 0.02, 0.04, 0.95 },
            slot_border = { 0.08, 0.08, 0.12, 0.5 },
            close_button = { 0.5, 0.5, 0.55, 1 },
            close_button_hover = { 0.8, 0.3, 0.3, 1 },
            glow = { 0.2, 0.5, 0.7, 0.2 },
        },
        text = {
            heading = { 0.85, 0.85, 0.9, 1 },
            body = { 0.75, 0.75, 0.8, 1 },
            muted = { 0.4, 0.4, 0.45, 1 },
            warning = { 0.7, 0.3, 0.3, 1 },
        },
        hud = {
            health_border = { 0, 0, 0, 1 },
            health_fill = { 0.15, 0.6, 0.3, 0.9 },
            minimap_background = { 0, 0, 0, 0.8 },
            minimap_border = { 0.15, 0.15, 0.2, 1 },
            minimap_player = { 0, 0.8, 0, 1 },
            minimap_teammate = { 0.2, 0.6, 1, 1 },
            minimap_asteroid = { 0.4, 0.35, 0.3, 0.7 },
            minimap_ship = { 0.8, 0.2, 0.2, 1 },
            diagnostics = { 0.7, 0.7, 0.75, 1 },
        },
        tooltip = {
            background = { 0.03, 0.03, 0.05, 0.96 },
            border = { 0.2, 0.5, 0.7, 0.9 },
            shadow = { 0, 0, 0, 0.4 },
            heading = { 0.9, 0.9, 0.95, 1 },
            text = { 0.78, 0.78, 0.82, 1 },
        },
    },
    spacing = {
        window_margin = 50,
        window_padding = 20,
        window_corner_radius = 2,
        window_shadow_offset = 1,
        window_glow_extra = 2,
        slot_size = 56,
        slot_padding = 4,
        slot_text_height = 16,
        tooltip_padding = 8,
        tooltip_max_width = 240,
        tooltip_offset_x = 18,
        tooltip_offset_y = 16,
        tooltip_shadow_offset = 4,
        tooltip_line_spacing = 2,
    },
    window = {
        top_bar_height = 24,
        bottom_bar_height = 28,
        close_button_size = 14,
    },
}

local function load_font(size)
    local font_path = constants.render and constants.render.fonts and constants.render.fonts.primary
    if font_path then
        local ok, font = pcall(love.graphics.newFont, font_path, size)
        if ok and font then
            return font
        end
    end
    return love.graphics.newFont(size)
end

function theme.get_fonts()
    if theme._fonts then
        return theme._fonts
    end

    theme._fonts = {
        title = load_font(theme.font_sizes.title),
        body = load_font(theme.font_sizes.body),
        small = load_font(theme.font_sizes.small),
        tiny = load_font(theme.font_sizes.tiny),
    }

    return theme._fonts
end

return theme
