local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local theme = require("src.ui.theme")
local Starfield = require("src.states.gameplay.starfield")
local gameplay = require("src.states.gameplay")

---@diagnostic disable-next-line: undefined-global
local love = love

local start_menu = {}

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
    return rect
        and x >= rect.x
        and x <= rect.x + rect.w
        and y >= rect.y
        and y <= rect.y + rect.h
end

function start_menu:start_game()
    if self.transitioning then
        return
    end
    self.transitioning = true
    Gamestate.switch(gameplay)
end

local function draw_primary_button(x, y, width, height, label, hovered, font)
    local window_colors = theme.colors.window or {}
    local fill_base = { 0.1, 0.2, 0.14, 1 }
    local fill_hover = { 0.18, 0.34, 0.24, 1 }
    local border = { 0.22, 0.38, 0.28, 1 }
    local text_color = { 0.82, 0.96, 0.86, 1 }
    local glow_color = { 0.36, 0.85, 0.58, 0.42 }

    local fill = fill_base
    local radius = 6

    love.graphics.push("all")

    -- Base fill
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", x, y, width, height, radius, radius)

    -- Border
    love.graphics.setColor(border)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, radius, radius)

    -- Label
    love.graphics.setFont(font)
    love.graphics.setColor(text_color)
    love.graphics.print(
        label,
        x + (width - font:getWidth(label)) * 0.5,
        y + (height - font:getHeight()) * 0.5
    )

    love.graphics.pop()
end

local function build_aurora_shader()
    return love.graphics.newShader([[ 
        extern float time;
        extern float intensity;
        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec4 sample = Texel(tex, texture_coords);
            float x = texture_coords.x;
            float y = texture_coords.y;
            float wave = sin(x * 18.0 + time * 1.6) * 0.08;
            float band = clamp(1.0 - smoothstep(0.0, 0.45, abs(y - 0.5) - wave), 0.0, 1.0);
            float shimmer = 0.65 + 0.35 * sin(time * 2.8 + x * 8.5);
            float ripple = 0.5 + 0.5 * sin(time * 1.3 + y * 6.0 + x * 3.0);
            float mixFactor = clamp(band * shimmer * ripple, 0.0, 1.0);
            vec3 base = vec3(0.18, 0.52, 0.92);
            vec3 mid = vec3(0.42, 0.9, 0.78);
            vec3 highlight = vec3(1.0, 0.96, 0.82);
            vec3 aurora = mix(base, mid, mixFactor);
            aurora = mix(aurora, highlight, smoothstep(0.6, 1.0, mixFactor));
            float baseAlpha = 0.35;
            float alpha = clamp(baseAlpha + mixFactor * intensity * 0.75, 0.0, 1.0) * sample.a;
            return vec4(aurora * sample.rgb, alpha);
        }
    ]])
end

function start_menu:enter()
    self.titleFont = load_font(72)
    self.fonts = theme.get_fonts()
    self.buttonFont = self.fonts.body
    self.buttonRect = nil
    self.buttonHovered = false
    self.transitioning = false
    self.time = 0

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
    local titleWidth = math.ceil(self.titleFont:getWidth(self.titleText))
    local titleHeight = math.ceil(self.titleFont:getHeight())
    self.titleCanvas = love.graphics.newCanvas(titleWidth, titleHeight)
    love.graphics.push("all")
    love.graphics.setCanvas(self.titleCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.titleText, 0, 0)
    love.graphics.setCanvas()
    love.graphics.pop()

    self.auroraShader = build_aurora_shader()
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

    if self.auroraShader and self.titleCanvas then
        love.graphics.setShader(self.auroraShader)
        self.auroraShader:send("time", self.time)
        self.auroraShader:send("intensity", 1.0)
    end

    if self.titleCanvas then
        local titleX = (width - self.titleCanvas:getWidth()) * 0.5
        local titleY = height * 0.26 - self.titleCanvas:getHeight() * 0.5
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.titleCanvas, titleX, titleY)
    end

    love.graphics.setShader()

    local button_width = math.min(240, width * 0.28)
    local button_height = 52
    local button_x = (width - button_width) * 0.5
    local button_y = height * 0.6

    local mouse_x, mouse_y = love.mouse.getPosition()
    local button_rect = {
        x = button_x,
        y = button_y,
        w = button_width,
        h = button_height,
    }
    self.buttonRect = button_rect

    local hovered = point_in_rect(mouse_x, mouse_y, button_rect)
    self.buttonHovered = hovered

    local button_label = "New Game"
    draw_primary_button(button_x, button_y, button_width, button_height, button_label, hovered, self.buttonFont)

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
end

function start_menu:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        self:start_game()
    elseif key == "escape" then
        love.event.quit()
    end
end

function start_menu:mousepressed(x, y, button)
    if button == 1 and point_in_rect(x, y, self.buttonRect) then
        self:start_game()
    end
end

return start_menu
