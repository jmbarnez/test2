local theme = require("src.ui.theme")
local UIStateManager = require("src.ui.state_manager")
local UIButton = require("src.ui.components.button")
local PlayerManager = require("src.player.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local map_window = {}

local function clamp(value, min_val, max_val)
    if value < min_val then return min_val end
    if value > max_val then return max_val end
    return value
end

local function point_in_rect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.width
        and py >= rect.y and py <= rect.y + rect.height
end

local function get_world_bounds(context)
    if context and context.worldBounds then
        return context.worldBounds
    end
    if context and context.world and context.world.bounds then
        return context.world.bounds
    end
    return nil
end

local function reset_view(state, context, bounds)
    bounds = bounds or get_world_bounds(context)
    if not bounds then
        return
    end

    local player = PlayerManager.resolveLocalPlayer(context)
    if player and player.position then
        state.centerX = player.position.x
        state.centerY = player.position.y
    else
        state.centerX = bounds.x + bounds.width * 0.5
        state.centerY = bounds.y + bounds.height * 0.5
    end

    state.zoom = 1
end

local function world_to_screen(wx, wy, rect, scale, centerX, centerY)
    local half_width = rect.width * 0.5
    local half_height = rect.height * 0.5

    local dx = (wx - centerX) * scale
    local dy = (wy - centerY) * scale

    return rect.x + half_width + dx, rect.y + half_height + dy
end

local function clamp_center(state, bounds, rect, scale)
    if not (state and bounds and rect and scale) then
        return
    end

    local half_view_world_width = (rect.width * 0.5) / scale
    local half_view_world_height = (rect.height * 0.5) / scale

    half_view_world_width = math.min(half_view_world_width, bounds.width * 0.5)
    half_view_world_height = math.min(half_view_world_height, bounds.height * 0.5)

    state.centerX = clamp(state.centerX, bounds.x + half_view_world_width, bounds.x + bounds.width - half_view_world_width)
    state.centerY = clamp(state.centerY, bounds.y + half_view_world_height, bounds.y + bounds.height - half_view_world_height)
end

local function get_map_rect(screen_width, screen_height)
    local spacing = theme.get_spacing()
    local margin = math.max(36, spacing and spacing.window_margin or 36)

    local rect_width = math.max(200, screen_width - margin * 2)
    local rect_height = math.max(200, screen_height - margin * 2)

    return {
        x = (screen_width - rect_width) * 0.5,
        y = (screen_height - rect_height) * 0.5,
        width = rect_width,
        height = rect_height,
    }
end

local function draw_legend(rect, fonts, colors)
    local legendItems = {
        { label = "You", color = colors.player },
        { label = "Allies", color = colors.teammate },
        { label = "Enemies", color = colors.enemy },
        { label = "Asteroids", color = colors.asteroid },
    }

    local padding = 16
    local swatchSize = 12
    local lineSpacing = 8
    local font = fonts.small or fonts.body

    local panelWidth = 160
    local panelHeight = padding * 2 + (#legendItems * (swatchSize + lineSpacing))
    panelHeight = panelHeight - lineSpacing

    local panelX = rect.x + padding
    local panelY = rect.y + padding

    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)

    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 0.5, panelY + 0.5, panelWidth - 1, panelHeight - 1, 6, 6)

    love.graphics.setFont(font)

    local textColor = colors.legend_text or { 0.8, 0.82, 0.86, 1 }
    local y = panelY + padding
    local x = panelX + padding

    for _, item in ipairs(legendItems) do
        love.graphics.setColor(item.color or textColor)
        love.graphics.rectangle("fill", x, y + (font:getHeight() - swatchSize) * 0.5, swatchSize, swatchSize, 3, 3)

        love.graphics.setColor(textColor)
        love.graphics.print(item.label, x + swatchSize + 10, y)

        y = y + font:getHeight() + lineSpacing
    end

    love.graphics.setColor(colors.legend_muted or { 0.6, 0.65, 0.7, 1 })
    love.graphics.print("Drag to pan\nScroll to zoom", x, panelY + panelHeight - padding - font:getHeight() * 2)
end

local function draw_entities(context, player, rect, bounds, colors, scale, centerX, centerY)
    if not (context and context.world) then
        return
    end

    local entities = context.world.entities or {}

    for i = 1, #entities do
        local entity = entities[i]
        if entity and entity.position then
            local color
            local radius = 3

            if entity == player then
                color = colors.player
                radius = 5
            elseif entity.player then
                color = colors.teammate
                radius = 4
            elseif entity.blueprint and entity.blueprint.category == "asteroids" then
                color = colors.asteroid
                radius = 3
            elseif entity.blueprint and entity.blueprint.category == "ships" then
                color = colors.enemy
                radius = 4
            end

            if color then
                local screenX, screenY = world_to_screen(entity.position.x, entity.position.y, rect, scale, centerX, centerY)
                if screenX >= rect.x and screenX <= rect.x + rect.width and screenY >= rect.y and screenY <= rect.y + rect.height then
                    love.graphics.setColor(color)
                    love.graphics.circle("fill", screenX, screenY, radius)
                end
            end
        end
    end

    if player and player.position then
        love.graphics.setColor(colors.player)
        local px, py = world_to_screen(player.position.x, player.position.y, rect, scale, centerX, centerY)
        love.graphics.circle("line", px, py, 9)
    end
end

function map_window.draw(context)
    local state = context and context.mapUI
    if not (state and state.visible) then
        return false
    end

    local bounds = get_world_bounds(context)
    if not bounds then
        return false
    end

    local fonts = theme.get_fonts()
    local colors = theme.colors.map or {}

    if context and context.uiInput then
        context.uiInput.mouseCaptured = true
        context.uiInput.keyboardCaptured = true
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local rect = get_map_rect(screenWidth, screenHeight)

    state.zoom = clamp(state.zoom or 1, state.min_zoom or 0.35, state.max_zoom or 6)

    if state._just_opened or not (state.centerX and state.centerY) then
        reset_view(state, context, bounds)
        state._just_opened = false
    end

    local baseScale = math.min(rect.width / bounds.width, rect.height / bounds.height)
    local scale = baseScale * state.zoom

    clamp_center(state, bounds, rect, scale)

    local mouseX, mouseY = love.mouse.getPosition()
    local isMouseDown = love.mouse.isDown(1)
    local justPressed = isMouseDown and not state._was_mouse_down

    if justPressed and point_in_rect(mouseX, mouseY, rect) then
        state.dragging = true
        state.drag_start_mouse_x = mouseX
        state.drag_start_mouse_y = mouseY
        state.drag_start_center_x = state.centerX
        state.drag_start_center_y = state.centerY
    elseif not isMouseDown then
        state.dragging = false
    end

    if state.dragging and isMouseDown then
        local dx = (mouseX - (state.drag_start_mouse_x or mouseX)) / scale
        local dy = (mouseY - (state.drag_start_mouse_y or mouseY)) / scale

        state.centerX = (state.drag_start_center_x or state.centerX) - dx
        state.centerY = (state.drag_start_center_y or state.centerY) - dy
        clamp_center(state, bounds, rect, scale)
    end

    state._was_mouse_down = isMouseDown

    love.graphics.push("all")
    love.graphics.origin()

    love.graphics.setColor(colors.overlay or { 0, 0, 0, 0.78 })
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    love.graphics.setColor(colors.background or { 0.05, 0.06, 0.08, 0.95 })
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 8, 8)

    love.graphics.setColor(colors.border or { 0.2, 0.26, 0.34, 1 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rect.x + 1, rect.y + 1, rect.width - 2, rect.height - 2, 8, 8)

    love.graphics.push()
    love.graphics.setScissor(rect.x, rect.y, rect.width, rect.height)

    if colors.grid then
        love.graphics.setColor(colors.grid)
        love.graphics.setLineWidth(1)
        local gridStep = 500
        local startX = math.floor(bounds.x / gridStep) * gridStep
        local endX = bounds.x + bounds.width
        local startY = math.floor(bounds.y / gridStep) * gridStep
        local endY = bounds.y + bounds.height

        for gx = startX, endX, gridStep do
            local x1, y1 = world_to_screen(gx, bounds.y, rect, scale, state.centerX, state.centerY)
            local x2, y2 = world_to_screen(gx, bounds.y + bounds.height, rect, scale, state.centerX, state.centerY)
            love.graphics.line(x1, y1, x2, y2)
        end

        for gy = startY, endY, gridStep do
            local x1, y1 = world_to_screen(bounds.x, gy, rect, scale, state.centerX, state.centerY)
            local x2, y2 = world_to_screen(bounds.x + bounds.width, gy, rect, scale, state.centerX, state.centerY)
            love.graphics.line(x1, y1, x2, y2)
        end
    end

    local boundsX1, boundsY1 = world_to_screen(bounds.x, bounds.y, rect, scale, state.centerX, state.centerY)
    local boundsX2, boundsY2 = world_to_screen(bounds.x + bounds.width, bounds.y + bounds.height, rect, scale, state.centerX, state.centerY)

    love.graphics.setColor(colors.bounds or { 0.46, 0.64, 0.72, 0.8 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boundsX1, boundsY1, boundsX2 - boundsX1, boundsY2 - boundsY1)

    local player = PlayerManager.resolveLocalPlayer(context)
    draw_entities(context, player, rect, bounds, colors, scale, state.centerX, state.centerY)

    love.graphics.setScissor()
    love.graphics.pop()

    draw_legend(rect, fonts, colors)

    local buttonWidth = 150
    local buttonHeight = 36
    local buttonRect = {
        x = rect.x + 20,
        y = rect.y + rect.height - buttonHeight - 20,
        width = buttonWidth,
        height = buttonHeight,
    }

    local buttonResult = UIButton.render {
        rect = buttonRect,
        label = "Reset View",
        fonts = fonts,
        font = fonts.body,
        input = {
            x = mouseX,
            y = mouseY,
            is_down = isMouseDown,
            just_pressed = justPressed,
        },
    }

    if buttonResult.clicked then
        reset_view(state, context, bounds)
        clamp_center(state, bounds, rect, baseScale * state.zoom)
    end

    love.graphics.pop()

    return true
end

function map_window.keypressed(context, key)
    if key == nil then
        return false
    end

    local state = context and context.mapUI
    if not (state and state.visible) then
        return false
    end

    if key == "escape" or key == "m" then
        UIStateManager.hideMapUI(context)
        return true
    end

    return true
end

function map_window.wheelmoved(context, x, y)
    local state = context and context.mapUI
    if not (state and state.visible) then
        return false
    end

    y = tonumber(y)
    if not y or y == 0 then
        return false
    end

    local zoomStep = 0.15
    local newZoom
    if y > 0 then
        newZoom = state.zoom * (1 + zoomStep)
    else
        newZoom = state.zoom / (1 + zoomStep)
    end

    local clamped = clamp(newZoom, state.min_zoom or 0.35, state.max_zoom or 6)
    if math.abs(clamped - state.zoom) < 1e-4 then
        return false
    end

    state.zoom = clamped
    return true
end

return map_window
