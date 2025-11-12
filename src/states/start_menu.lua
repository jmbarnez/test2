local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local theme = require("src.ui.theme")
local UIButton = require("src.ui.components.button")
local Starfield = require("src.states.gameplay.starfield")
local SaveLoad = require("src.util.save_load")

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

local function build_aurora_shader()
    return love.graphics.newShader([[
        extern float time;
        extern float intensity;

        float hash(vec2 p) {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
        }

        float noise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            float a = hash(i);
            float b = hash(i + vec2(1.0, 0.0));
            float c = hash(i + vec2(0.0, 1.0));
            float d = hash(i + vec2(1.0, 1.0));
            vec2 u = f * f * (3.0 - 2.0 * f);
            return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
        }

        float fbm(vec2 p) {
            float v = 0.0;
            float a = 0.5;
            for (int i = 0; i < 5; i++) {
                v += a * noise(p);
                p = p * 2.02 + vec2(37.1, 9.2);
                a *= 0.5;
            }
            return v;
        }

        vec3 palette(float t) {
            vec3 a = vec3(0.15, 0.55, 0.35); // deep green
            vec3 b = vec3(0.10, 0.40, 0.95); // blue
            vec3 c = vec3(0.85, 0.35, 0.85); // purple
            vec3 g = mix(a, b, smoothstep(0.0, 0.6, t));
            return mix(g, c, smoothstep(0.6, 1.0, t));
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec4 sample = Texel(tex, texture_coords);

            // Only render aurora inside the letters
            if (sample.a < 0.08) {
                return vec4(0.0);
            }

            // Normalized screen UV (built-in love_ScreenSize)
            vec2 uv = screen_coords / love_ScreenSize.xy;

            // Stretch X for curtain-like flow
            vec2 p = uv * vec2(1.8, 1.0);
            float t = time;

            // Domain-warped FBM for organic motion
            float base = fbm(p * 2.5 + vec2(0.0, t * 0.05));
            vec2 warp = vec2(
                fbm(p * 3.0 + vec2(13.2, -7.1) + base * 2.0 + t * 0.08),
                fbm(p * 3.0 + vec2(-5.7, 21.4) - base * 2.0 - t * 0.07)
            );

            // Flowing vertical bands
            float bands = sin(p.y * 10.0 + warp.x * 6.0 + t * 1.25) * 0.5 + 0.5;
            bands = smoothstep(0.25, 0.85, bands);

            // Aurora energy field
            float glow = fbm(p + warp * 1.7 + vec2(0.0, t * 0.10));
            float energy = clamp(glow * 0.8 + bands * 0.7, 0.0, 1.0);

            // Subtle twinkle
            float twinkle = smoothstep(0.97, 1.0, noise(p * 24.0 + t * 0.4)) * 0.25;

            // Color palette with slow hue shift
            float hueShift = 0.5 + 0.5 * sin(t * 0.4 + uv.x * 3.0);
            vec3 aurora = palette(clamp(energy * 0.9 + hueShift * 0.15, 0.0, 1.0));

            // Emphasize bright cores and soften glyph edges
            float edge = smoothstep(0.05, 0.95, sample.a);
            float core = pow(energy, 1.2);

            vec3 finalColor = aurora * (core * 1.3 + 0.15) + vec3(twinkle);
            finalColor *= edge * intensity;

            return vec4(finalColor, sample.a);
        }
    ]])
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
    local buttons = {
        { label = "New Game", action = "new", disabled = false },
        { label = "Load Game", action = "load", disabled = not save_available },
    }

    self.buttonHovered = false

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

        self.buttonRects[index] = {
            rect = rect,
            action = button.action,
            disabled = button.disabled,
        }

        local result = UIButton.render {
            rect = rect,
            label = button.label,
            font = self.buttonFont,
            fonts = self.fonts,
            disabled = button.disabled,
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
            end
            break
        end
    end
end

return start_menu
