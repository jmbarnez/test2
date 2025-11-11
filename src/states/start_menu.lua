local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local theme = require("src.ui.theme")
local UIButton = require("src.ui.components.button")
local Starfield = require("src.states.gameplay.starfield")

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

function start_menu:start_game()
    if self.transitioning then
        return
    end
    self.transitioning = true
    local gameplay = require("src.states.gameplay")
    Gamestate.switch(gameplay)
end

local function build_aurora_shader()
    return love.graphics.newShader([[ 
        extern float time;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec4 sample = Texel(tex, texture_coords);
            float x = texture_coords.x;
            float y = texture_coords.y;
            
            // Only render aurora inside the letters
            if (sample.a < 0.1) {
                return vec4(0.0, 0.0, 0.0, 0.0);
            }
            
            // Enhanced multi-layer noise for more dynamic aurora
            float noise1 = sin(x * 12.0 + time * 1.2) * 0.5 + 0.5;
            float noise2 = sin(y * 10.0 + time * 0.9) * 0.5 + 0.5;
            float noise3 = sin((x + y) * 8.0 + time * 1.5) * 0.5 + 0.5;
            float combinedNoise = (noise1 + noise2 + noise3) / 3.0;
            
            // Flowing aurora waves
            float wave1 = sin(x * 6.0 + time * 0.8 + y * 4.0) * 0.5 + 0.5;
            float wave2 = cos(y * 8.0 + time * 1.1 + x * 3.0) * 0.5 + 0.5;
            float drift = wave1 * wave2 * combinedNoise;
            
            // Dynamic color palette with more vibrant aurora colors
            vec3 color1 = vec3(0.2, 0.8, 0.4); // Green aurora
            vec3 color2 = vec3(0.4, 0.6, 0.9); // Blue aurora
            vec3 color3 = vec3(0.8, 0.4, 0.8); // Purple aurora
            
            float colorShift = sin(time * 0.5 + x * 2.0) * 0.5 + 0.5;
            vec3 auroraColor = mix(color1, color2, colorShift);
            auroraColor = mix(auroraColor, color3, smoothstep(0.6, 1.0, drift));
            
            return vec4(auroraColor * intensity, sample.a);
        }
    ]])
end

function start_menu:enter()
    self.titleFont = load_font(132)
    self.fonts = theme.get_fonts() or {}
    self.buttonFont = self.fonts.body or load_font(24)
    self.buttonRect = nil
    self.buttonHovered = false
    self.transitioning = false
    self.time = 0
    self._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

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

    if self.auroraShader and self.titleFont then
        love.graphics.setShader(self.auroraShader)
        self.auroraShader:send("time", self.time)
        self.auroraShader:send("intensity", 1.0)
    end

    if self.titleFont and self.titleText then
        love.graphics.setFont(self.titleFont)
        local titleWidth = self.titleFont:getWidth(self.titleText)
        local titleHeight = self.titleFont:getHeight()
        local titleX = (width - titleWidth) * 0.5
        local titleY = height * 0.22 - titleHeight * 0.5
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(self.titleText, titleX, titleY)
    end

    love.graphics.setShader()

    local button_width = math.min(120, width * 0.14)
    local button_height = 32
    local button_x = (width - button_width) * 0.5
    local button_y = height * 0.56

    local mouse_x, mouse_y = love.mouse.getPosition()
    local button_rect = {
        x = button_x,
        y = button_y,
        width = button_width,
        height = button_height,
        w = button_width,
        h = button_height,
    }
    self.buttonRect = button_rect

    local is_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    local just_pressed = is_mouse_down and not self._was_mouse_down
    self._was_mouse_down = is_mouse_down

    local button_label = "New Game"
    local result = UIButton.render {
        rect = button_rect,
        label = button_label,
        font = self.buttonFont,
        input = {
            x = mouse_x,
            y = mouse_y,
            is_down = is_mouse_down,
            just_pressed = just_pressed,
        },
    }

    self.buttonHovered = result.hovered

    if result.clicked then
        self:start_game()
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
