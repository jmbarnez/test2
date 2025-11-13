local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local theme = require("src.ui.theme")
local UIButton = require("src.ui.components.button")
local Starfield = require("src.states.gameplay.starfield")
local SaveLoad = require("src.util.save_load")

local TWO_PI = math.pi * 2

---@diagnostic disable-next-line: undefined-global
local love = love

local function load_font(size)
    local font_path = constants.render
        and constants.render.fonts
        and constants.render.fonts.primary

    if font_path then
        local ok, font = pcall(love.graphics.newFont, font_path, size)
        if ok and font then
            return font
        end
    end

    return love.graphics.newFont(size)
end

local function point_in_rect(x, y, rect)
    if not rect then
        return false
    end

    local width = rect.w or rect.width or 0
    local height = rect.h or rect.height or 0

    return x >= rect.x
        and x <= rect.x + width
        and y >= rect.y
        and y <= rect.y + height
end

local function draw_wrapped_arc(mode, cx, cy, radius, start_angle, end_angle)
    local two_pi = TWO_PI
    if end_angle < start_angle then
        start_angle, end_angle = end_angle, start_angle
    end

    local span = end_angle - start_angle
    if span <= 0 then
        return
    end

    if span >= two_pi then
        love.graphics.arc(mode, cx, cy, radius, 0, two_pi)
        return
    end

    local norm_start = start_angle % two_pi
    if norm_start < 0 then
        norm_start = norm_start + two_pi
    end

    local norm_end = norm_start + span
    if norm_end <= two_pi then
        love.graphics.arc(mode, cx, cy, radius, norm_start, norm_end)
    else
        love.graphics.arc(mode, cx, cy, radius, norm_start, two_pi)
        love.graphics.arc(mode, cx, cy, radius, 0, norm_end - two_pi)
    end
end

local function draw_refresh_icon(rect, hovered, active, time)
    love.graphics.push("all")

    local size = math.min(rect.width, rect.height)
    local cx = rect.x + rect.width * 0.5
    local cy = rect.y + rect.height * 0.5
    local base_alpha = active and 1.0 or hovered and 0.92 or 0.78
    local outer_radius = size * 0.36
    local inner_radius = outer_radius * 0.58
    local pulse = math.sin((time or 0) * 1.2) * 0.08 + 0.12

    love.graphics.setColor(1.0, 1.0, 1.0, base_alpha)
    love.graphics.setLineWidth(math.max(2.0, size * 0.14))
    love.graphics.setLineStyle("smooth")
    love.graphics.circle("line", cx, cy, outer_radius)

    love.graphics.setColor(1.0, 1.0, 1.0, base_alpha * 0.55)
    love.graphics.circle("line", cx, cy, inner_radius)

    love.graphics.setColor(1.0, 1.0, 1.0, base_alpha * (0.35 + pulse))
    love.graphics.circle("fill", cx, cy, inner_radius * 0.68)

    love.graphics.pop()
end

local function set_status(self, text, color)
    if not self then
        return
    end

    self.statusText = text
    self.statusColor = color or { 0.75, 0.78, 0.82, 1 }
    local timer = love and love.timer and love.timer.getTime and love.timer.getTime()
    if timer then
        self.statusExpiry = timer + 3
    else
        self.statusExpiry = nil
    end
end

local start_menu = {}

function start_menu:start_game()
    if self.transitioning then
        return
    end
    self.transitioning = true
    local gameplay = require("src.states.gameplay")
    Gamestate.switch(gameplay)
end

function start_menu:load_game()
    if self.transitioning then
        return
    end

    if not SaveLoad.saveExists() then
        set_status(self, "No save data found", { 1.0, 0.45, 0.45, 1.0 })
        return
    end

    self.transitioning = true
    local gameplay = require("src.states.gameplay")
    Gamestate.switch(gameplay, { loadGame = true })
end

function start_menu:enter()
    self.titleFont = load_font(132)
    self.fonts = theme.get_fonts() or {}
    self.buttonFont = self.fonts.body or load_font(24)
    self.buttonRects = {}
    self.buttonHovered = false
    self.transitioning = false
    self.time = 0
    self._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    self.statusText = nil
    self.statusColor = nil
    self.statusExpiry = nil

    local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local worldBounds = constants.world and constants.world.bounds or { x = 0, y = 0, width = width, height = height }

    self.viewport = {
        width = width,
        height = height,
    }

    self.worldBounds = {
        x = worldBounds.x or 0,
        y = worldBounds.y or 0,
        width = worldBounds.width or width,
        height = worldBounds.height or height,
    }

    self.camera = {
        width = self.viewport.width,
        height = self.viewport.height,
        zoom = 1,
    }

    local function center_camera()
        local bounds = self.worldBounds
        local cam = self.camera
        cam.x = bounds.x + math.max(0, (bounds.width - cam.width) * 0.5)
        cam.y = bounds.y + math.max(0, (bounds.height - cam.height) * 0.5)
    end

    center_camera()
    Starfield.initialize(self)

    self.titleText = "Novus"
    self._center_camera = center_camera
end

function start_menu:draw()
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local window_colors = theme.colors.window or {}

    love.graphics.clear(0, 0, 0, 1)

    if self.viewport then
        local viewportChanged = (self.viewport.width ~= width) or (self.viewport.height ~= height)
        if viewportChanged then
            self.viewport.width = width
            self.viewport.height = height
            if self.camera then
                self.camera.width = width
                self.camera.height = height
                if self._center_camera then
                    self:_center_camera()
                end
            end
            Starfield.refresh(self)
        end
    end

    Starfield.draw(self)

    love.graphics.push("all")

    if self.titleFont and self.titleText then
        love.graphics.setFont(self.titleFont)
        local titleWidth = self.titleFont:getWidth(self.titleText)
        local titleHeight = self.titleFont:getHeight()
        local titleX = (width - titleWidth) * 0.5
        local titleY = height * 0.22 - titleHeight * 0.5
        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        local glow_time = self.time or 0
        local base_radius = 4.5
        local layer_count = 8
        local rotation_speed = 0.18
        local pulse_speed = 0.35

        for i = 1, layer_count do
            local t = (i - 1) / layer_count
            local angle = glow_time * rotation_speed + t * math.pi * 2
            local pulse = math.sin(glow_time * pulse_speed + t * 4.0) * 0.5 + 0.5
            local radius = base_radius + pulse * 3.0 + t * 2.0
            local alpha = 0.04 + t * 0.06 + pulse * 0.02

            love.graphics.setColor(1.0, 1.0, 1.0, alpha)
            local offset_x = math.cos(angle) * radius
            local offset_y = math.sin(angle * 0.87) * radius
            love.graphics.print(self.titleText, titleX + offset_x, titleY + offset_y)
        end

        love.graphics.setColor(1.0, 1.0, 1.0, 0.22)
        love.graphics.print(self.titleText, titleX, titleY - 1)
        love.graphics.print(self.titleText, titleX, titleY + 1)
        love.graphics.pop()

        love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        love.graphics.print(self.titleText, titleX, titleY)
    end

    local button_width = math.min(140, width * 0.16)
    local button_height = 36
    local button_x = (width - button_width) * 0.5
    local button_y = height * 0.56
    local button_spacing = 16

    local mouse_x, mouse_y = love.mouse.getPosition()
    self.buttonRects = {}

    local is_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    local just_pressed = is_mouse_down and not self._was_mouse_down
    self._was_mouse_down = is_mouse_down

    local save_available = SaveLoad.saveExists()

    local shared_button_colors = {
        fill = { 1.0, 1.0, 1.0, 0.05 },
        hover = { 1.0, 1.0, 1.0, 0.12 },
        active = { 1.0, 1.0, 1.0, 0.18 },
        border = { 1.0, 1.0, 1.0, 0.85 },
        text = { 1.0, 1.0, 1.0, 1.0 },
        disabled_fill = { 1.0, 1.0, 1.0, 0.02 },
        disabled_border = { 1.0, 1.0, 1.0, 0.25 },
        disabled_text = { 1.0, 1.0, 1.0, 0.35 },
    }

    local refresh_size = math.min(40, width * 0.05)
    local refresh_margin = 24
    local refresh_rect = {
        x = width - refresh_margin - refresh_size,
        y = refresh_margin,
        width = refresh_size,
        height = refresh_size,
    }

    local refresh_result = UIButton.render {
        rect = refresh_rect,
        label = "",
        font = self.fonts.small or self.buttonFont,
        fonts = self.fonts,
        disabled = false,
        fill_color = shared_button_colors.fill,
        hover_color = shared_button_colors.hover,
        active_color = shared_button_colors.active,
        border_color = shared_button_colors.border,
        text_color = shared_button_colors.text,
        input = {
            x = mouse_x,
            y = mouse_y,
            is_down = is_mouse_down,
            just_pressed = just_pressed,
        },
    }

    draw_refresh_icon(refresh_rect, refresh_result.hovered, refresh_result.active, self.time)

    self.buttonHovered = refresh_result.hovered or false

    if refresh_result.clicked then
        Starfield.refresh(self, true)
        set_status(self, "Background regenerated", { 0.7, 0.94, 1.0, 1.0 })
    end

    self.buttonRects[#self.buttonRects + 1] = {
        rect = refresh_rect,
        action = "refresh",
        disabled = false,
    }

    local buttons = {
        { label = "New Game", action = "new", disabled = false, colors = shared_button_colors },
        { label = "Load Game", action = "load", disabled = not save_available, colors = shared_button_colors },
    }

    self.buttonHovered = self.buttonHovered or false

    for index = 1, #buttons do
        local button = buttons[index]
        local rect = {
            x = button_x,
            y = button_y + (index - 1) * (button_height + button_spacing),
            width = button_width,
            height = button_height,
            w = button_width,
            h = button_height,
        }

        self.buttonRects[#self.buttonRects + 1] = {
            rect = rect,
            action = button.action,
            disabled = button.disabled,
        }

        local colors = button.colors or {}

        local result = UIButton.render {
            rect = rect,
            label = button.label,
            font = self.buttonFont,
            fonts = self.fonts,
            disabled = button.disabled,
            fill_color = colors.fill,
            hover_color = colors.hover,
            active_color = colors.active,
            border_color = colors.border,
            text_color = colors.text,
            disabled_fill = colors.disabled_fill,
            border_color_disabled = colors.disabled_border,
            disabled_text_color = colors.disabled_text,
            input = {
                x = mouse_x,
                y = mouse_y,
                is_down = is_mouse_down,
                just_pressed = just_pressed,
            },
        }

        self.buttonHovered = self.buttonHovered or result.hovered

        if result.clicked and not button.disabled then
            if button.action == "new" then
                self:start_game()
            elseif button.action == "load" then
                self:load_game()
            end
            break
        end
    end

    if self.statusText then
        local color = self.statusColor or { 0.75, 0.78, 0.82, 1 }
        love.graphics.setFont(self.fonts.small or self.buttonFont)
        love.graphics.setColor(color)
        local statusY = button_y + (#buttons) * (button_height + button_spacing) + 8
        love.graphics.printf(self.statusText, button_x - 60, statusY, button_width + 120, "center")
    end

    love.graphics.pop()
end

function start_menu:update(dt)
    self.time = (self.time or 0) + dt
    Starfield.update(self, dt)

    if self.camera and self.worldBounds then
        local bounds = self.worldBounds
        local cam = self.camera
        cam.width = cam.width or self.viewport.width
        cam.height = cam.height or self.viewport.height

        local centerX = bounds.x + math.max(0, (bounds.width - cam.width) * 0.5)
        local centerY = bounds.y + math.max(0, (bounds.height - cam.height) * 0.5)
        local horizontalDrift = math.min(800, math.max(200, bounds.width * 0.02))
        local verticalDrift = math.min(600, math.max(120, bounds.height * 0.015))

        cam.x = centerX + math.cos(self.time * 0.03) * horizontalDrift
        cam.y = centerY + math.sin(self.time * 0.025) * verticalDrift

        local maxX = bounds.x + bounds.width - cam.width
        local maxY = bounds.y + bounds.height - cam.height
        cam.x = math.max(bounds.x, math.min(maxX, cam.x))
        cam.y = math.max(bounds.y, math.min(maxY, cam.y))
    end

    if self.statusText and self.statusExpiry then
        local now = love.timer and love.timer.getTime and love.timer.getTime()
        if now and now >= self.statusExpiry then
            self.statusText = nil
            self.statusColor = nil
            self.statusExpiry = nil
        end
    end
end

function start_menu:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        self:start_game()
    elseif key == "escape" then
        love.event.quit()
    end
end

function start_menu:mousepressed(x, y, button)
    if button ~= 1 or not self.buttonRects then
        return
    end

    for i = 1, #self.buttonRects do
        local entry = self.buttonRects[i]
        if entry and not entry.disabled and point_in_rect(x, y, entry.rect) then
            if entry.action == "new" then
                self:start_game()
            elseif entry.action == "load" then
                self:load_game()
            elseif entry.action == "refresh" then
                Starfield.refresh(self, true)
                set_status(self, "Background regenerated", { 0.7, 0.94, 1.0, 1.0 })
            end
            break
        end
    end
end

return start_menu
