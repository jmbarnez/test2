---@diagnostic disable: undefined-global
local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local AudioManager = require("src.audio.manager")
local gameplay = require("src.states.gameplay")
local start_menu = require("src.states.start_menu")
local runtime_settings = require("src.settings.runtime")

local TARGET_FPS = 0
local TARGET_FRAME_TIME = 0
local USE_FRAME_LIMIT = false

local function refresh_frame_limit_state()
    local maxFps = runtime_settings.get_max_fps() or 0
    if maxFps > 0 then
        TARGET_FPS = maxFps
        TARGET_FRAME_TIME = 1 / maxFps
    else
        TARGET_FPS = 0
        TARGET_FRAME_TIME = 0
    end

    USE_FRAME_LIMIT = runtime_settings.should_limit_frame_rate()
    runtime_settings.clear_frame_limit_dirty()
end

runtime_settings.set_frame_limit_changed_callback(refresh_frame_limit_state)
refresh_frame_limit_state()

function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end

    local dt = 0
    local frameStart = love.timer and love.timer.getTime() or 0

    return function()
        -- Mark the start of the frame to compute sleep time later
        if love.timer then
            frameStart = love.timer.getTime()
        end

        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                end
                local handler = love.handlers and love.handlers[name]
                if handler then handler(a, b, c, d, e, f) end
            end
        end

        if love.timer then
            dt = love.timer.step()
        else
            dt = 0
        end

        if love.update then love.update(dt) end

        if love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            if love.draw then love.draw() end
            love.graphics.present()
        end

        -- Manual frame limiting only when vsync is disabled
        if runtime_settings.is_frame_limit_dirty() then
            refresh_frame_limit_state()
        end
        if USE_FRAME_LIMIT and love.timer and TARGET_FPS > 0 then
            local elapsed = love.timer.getTime() - frameStart
            local remaining = TARGET_FRAME_TIME - elapsed
            if remaining > 0 then
                love.timer.sleep(remaining)
            end
        end
    end
end

function love.load(arg, unfilteredArg)
    -- Accept standard LÖVE arguments (unused in this implementation)
    local window = constants.window
    if love.window and window then
        love.window.setTitle(window.title or "Game")
        love.window.setMode(window.width, window.height, {
            resizable = window.resizable,
            vsync = window.vsync, -- respect numeric vsync setting (0, 1, or adaptive if supported)
            fullscreen = window.fullscreen,
            msaa = window.msaa,
        })
        if not window.fullscreen and love.window.getDesktopDimensions and love.window.setPosition then
            local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
            if desktopWidth and desktopHeight then
                local centerX = math.floor((desktopWidth - window.width) / 2)
                local centerY = math.floor((desktopHeight - window.height) / 2)
                love.window.setPosition(centerX, centerY)
            end
        end
        runtime_settings.set_vsync_enabled((window.vsync or 0) ~= 0)
        if window.max_fps then
            runtime_settings.set_max_fps(window.max_fps)
        end
        refresh_frame_limit_state()
    end

    if love.graphics and love.graphics.setDefaultFilter then
        love.graphics.setDefaultFilter("nearest", "nearest", 1)
    end

    local physics = constants.physics
    if love.physics and physics then
        love.physics.setMeter(physics.meter_scale or 64)
    end

    if love.math and love.timer then
        love.math.setRandomSeed(love.timer.getTime() * 100000)
    elseif love.math then
        love.math.setRandomSeed(os.time())
    end

    AudioManager.initialize()

    Gamestate.registerEvents()
    Gamestate.switch(start_menu)

end
