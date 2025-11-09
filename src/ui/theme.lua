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
            shadow = { 0, 0, 0, 0.8 },
            background = { 0.08, 0.08, 0.12, 0.98 },
            border = { 0.2, 0.25, 0.35, 0.9 },
            top_bar = { 0.05, 0.05, 0.08, 1 },
            bottom_bar = { 0.05, 0.05, 0.08, 1 },
            title_text = { 0.95, 0.95, 1, 1 },
            text = { 0.9, 0.9, 0.95, 1 },
            muted = { 0.55, 0.6, 0.7, 1 },
            row_alternate = { 0.12, 0.12, 0.18, 0.6 },
            row_hover = { 0.15, 0.2, 0.35, 0.4 },
            progress_background = { 0.1, 0.1, 0.15, 1 },
            progress_fill = { 0.2, 0.6, 0.9, 1 },
            warning = { 0.9, 0.4, 0.4, 1 },
            accent = { 0.3, 0.7, 1, 1 },
            button = { 0.12, 0.15, 0.22, 1 },
            button_hover = { 0.18, 0.22, 0.32, 1 },
            icon_background = { 0.1, 0.12, 0.18, 0.9 },
            icon_border = { 0.25, 0.3, 0.4, 0.8 },
            slot_background = { 0.08, 0.1, 0.15, 0.95 },
            slot_border = { 0.2, 0.25, 0.35, 0.7 },
            close_button = { 0.7, 0.75, 0.8, 1 },
            close_button_hover = { 1, 0.5, 0.5, 1 },
            glow = { 0.3, 0.7, 1, 0.3 },
        },
        text = {
            heading = { 0.95, 0.95, 1, 1 },
            body = { 0.9, 0.9, 0.95, 1 },
            muted = { 0.55, 0.6, 0.7, 1 },
            warning = { 0.9, 0.4, 0.4, 1 },
        },
        hud = {
            health_border = { 0, 0, 0, 1 },
            health_fill = { 0.2, 0.8, 0.4, 0.95 },
            minimap_background = { 0, 0, 0, 0.7 },
            minimap_border = { 0.3, 0.3, 0.3, 1 },
            minimap_player = { 0, 1, 0, 1 },
            minimap_asteroid = { 0.6, 0.5, 0.4, 0.8 },
            minimap_ship = { 1, 0.3, 0.3, 1 },
            diagnostics = { 0.9, 0.9, 1, 1 },
        },
    },
    spacing = {
        window_margin = 50,
        window_padding = 24,
        window_corner_radius = 4,
        window_shadow_offset = 2,
        window_glow_extra = 4,
        slot_size = 56,
        slot_padding = 6,
        slot_text_height = 18,
    },
    window = {
        top_bar_height = 36,
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
