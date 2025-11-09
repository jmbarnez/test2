---@diagnostic disable: undefined-global
local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local gameplay = require("src.states.gameplay")
local NetworkManager = require("src.network.manager")

local TARGET_FPS = 60
local TARGET_FRAME_TIME = 1 / TARGET_FPS

function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end
    
    local dt = 0
    
    return function()
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
            end
        end
        
        if love.timer then dt = love.timer.step() end
        
        if love.update then love.update(dt) end
        
        if love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            
            if love.draw then love.draw() end
            
            love.graphics.present()
        end
        
        -- Frame rate limiting to 60 FPS
        if love.timer then
            local frameTime = love.timer.getTime()
            local nextFrameTime = frameTime + TARGET_FRAME_TIME
            local sleepTime = nextFrameTime - love.timer.getTime()
            if sleepTime > 0 then
                love.timer.sleep(sleepTime)
            end
        end
    end
end

local function setMultiplayerStatus(status)
    if gameplay.multiplayerUI then
        gameplay.multiplayerUI.status = status or ""
    end
end

function love.load()
    local window = constants.window
    love.window.setTitle(window.title)
    love.window.setMode(window.width, window.height, {
        resizable = window.resizable,
        vsync = window.vsync == 1,
        fullscreen = window.fullscreen,
        msaa = window.msaa,
    })

    local physics = constants.physics
    love.physics.setMeter(physics.meter_scale)
    love.math.setRandomSeed(os.time())
    Gamestate.registerEvents()
    Gamestate.switch(gameplay)

    if gameplay then
        setMultiplayerStatus("")
        gameplay.networkManager = NetworkManager.new({
            state = gameplay,
            host = constants.network and constants.network.host,
            port = constants.network and constants.network.port,
            autoConnect = false,
            onConnect = function()
                setMultiplayerStatus("Connected")
            end,
            onDisconnect = function(_, code)
                if code and code ~= 0 then
                    setMultiplayerStatus(string.format("Disconnected (code %s)", tostring(code)))
                else
                    setMultiplayerStatus("Disconnected")
                end
            end,
            onTimeout = function()
                setMultiplayerStatus("Connection timed out")
            end,
        })
    end
end

