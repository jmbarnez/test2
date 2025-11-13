local theme = require("src.ui.theme")
local window = require("src.ui.components.window")
local Diagnostics = require("src.hud.diagnostics")
local PlayerManager = require("src.player.manager")
local UIStateManager = require("src.ui.state_manager")
local math_util = require("src.util.math")

---@diagnostic disable-next-line: undefined-global
local love = love

local debug_window = {}

local function get_dimensions()
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    local spacing = theme.get_spacing() or {}

    local margin = spacing.window_margin or 48
    local width = math.min(520, screen_width - margin * 2)
    local height = math.min(420, screen_height - margin * 2)

    local x = (screen_width - width) * 0.5
    local y = (screen_height - height) * 0.5

    x = math_util.clamp(x, margin, screen_width - width - margin)
    y = math_util.clamp(y, margin, screen_height - height - margin)

    return {
        x = x,
        y = y,
        width = width,
        height = height,
    }
end

local function clamp_scroll(state, content_height, viewport_height)
    if not state then
        return 0
    end

    local max_offset = math.max(0, content_height - viewport_height)
    if state.scrollOffset == nil then
        state.scrollOffset = 0
    end

    state.scrollOffset = math_util.clamp(state.scrollOffset, 0, max_offset)
    return state.scrollOffset
end

local function draw_background_panel(content_rect, colors)
    love.graphics.setColor(colors.panel or { 0.05, 0.06, 0.09, 0.9 })
    love.graphics.rectangle("fill", content_rect.x, content_rect.y, content_rect.width, content_rect.height)

    love.graphics.setColor(colors.border or { 0.18, 0.22, 0.3, 1 })
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", content_rect.x + 0.5, content_rect.y + 0.5, content_rect.width - 1, content_rect.height - 1)
end

local function draw_entries(context, state, content_rect, fonts, colors)
    local player = PlayerManager.resolveLocalPlayer(context)
    local lines = Diagnostics.collect(context, player) or {}

    if #lines == 0 then
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(colors.muted or { 0.6, 0.66, 0.72, 1 })
        love.graphics.printf("No diagnostics available.", content_rect.x, content_rect.y + (content_rect.height - fonts.body:getHeight()) * 0.5, content_rect.width, "center")
        return
    end

    local line_font = fonts.small or fonts.body
    local line_height = line_font:getHeight()
    local spacing = 6
    local row_height = line_height + spacing

    local heading_font = fonts.body or line_font
    local heading_height = heading_font:getHeight()

    local cursor_y = content_rect.y + 6

    local hint_font = fonts.tiny or fonts.small or line_font
    love.graphics.setFont(heading_font)
    love.graphics.setColor(colors.heading or { 0.82, 0.88, 0.95, 1 })
    love.graphics.print("DIAGNOSTICS", content_rect.x + 8, cursor_y)

    love.graphics.setFont(hint_font)
    love.graphics.setColor(colors.hint or { 0.58, 0.64, 0.7, 1 })
    love.graphics.print("F1 to toggle", content_rect.x + content_rect.width - hint_font:getWidth("F1 to toggle") - 8, cursor_y)

    cursor_y = cursor_y + heading_height + spacing

    love.graphics.setFont(line_font)

    local total_height = cursor_y - content_rect.y
    total_height = total_height + (#lines * row_height)

    local offset = clamp_scroll(state, total_height, content_rect.height)

    love.graphics.push("all")
    love.graphics.setScissor(content_rect.x, content_rect.y, content_rect.width, content_rect.height)
    love.graphics.translate(0, -offset)

    for index = 1, #lines do
        love.graphics.setColor(colors.text or { 0.78, 0.83, 0.88, 1 })
        love.graphics.print(lines[index], content_rect.x + 12, cursor_y + (index - 1) * row_height)
    end

    love.graphics.pop()

    state._contentRect = {
        x = content_rect.x,
        y = content_rect.y,
        width = content_rect.width,
        height = content_rect.height,
        contentHeight = total_height,
    }
end

function debug_window.draw(context)
    local state = context and context.debugUI
    if not state then
        state = {}
        if context then
            context.debugUI = state
        end
    end

    local mouse_is_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

    if not state.visible then
        state.dragging = false
        state._was_mouse_down = mouse_is_down
        state._contentRect = nil
        return false
    end

    local fonts = theme.get_fonts()
    local colors = theme.colors.window or {}

    local mouse_x, mouse_y = 0, 0
    if love.mouse and love.mouse.getPosition then
        mouse_x, mouse_y = love.mouse.getPosition()
    end

    local is_mouse_down = mouse_is_down
    local just_pressed = is_mouse_down and not state._was_mouse_down

    if state._just_opened then
        state.scrollOffset = 0
        state._just_opened = false
    end

    local dims = get_dimensions()

    love.graphics.push("all")
    love.graphics.origin()

    local frame = window.draw_frame {
        x = state.x or dims.x,
        y = state.y or dims.y,
        width = state.width or dims.width,
        height = state.height or dims.height,
        title = "Debug Diagnostics",
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
    draw_background_panel(content, colors)
    draw_entries(context, state, content, fonts, {
        panel = colors.background,
        border = colors.border,
        text = colors.text,
        heading = colors.title_text,
        hint = colors.muted,
        muted = colors.muted,
    })

    if frame.close_clicked then
        love.graphics.pop()
        state._was_mouse_down = is_mouse_down
        state._contentRect = nil
        if context then
            UIStateManager.hideDebugUI(context)
        end
        return true
    end

    love.graphics.pop()

    state._was_mouse_down = is_mouse_down
    return true
end

function debug_window.wheelmoved(context, x, y)
    local state = context and context.debugUI
    if not (state and state.visible) then
        return false
    end

    local rect = state._contentRect
    if not rect then
        return false
    end

    if not (y and y ~= 0) then
        return false
    end

    local mouse_x, mouse_y = 0, 0
    if love.mouse and love.mouse.getPosition then
        mouse_x, mouse_y = love.mouse.getPosition()
    end

    if mouse_x < rect.x or mouse_x > rect.x + rect.width or mouse_y < rect.y or mouse_y > rect.y + rect.height then
        return false
    end

    local scroll_step = 40
    local current = clamp_scroll(state, rect.contentHeight, rect.height)
    state.scrollOffset = clamp_scroll(state, rect.contentHeight, rect.height)
    state.scrollOffset = math.max(0, current - y * scroll_step)
    state.scrollOffset = clamp_scroll(state, rect.contentHeight, rect.height)
    return true
end

return debug_window
