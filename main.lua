---@diagnostic disable: undefined-global
local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local gameplay = require("src.states.gameplay")
local NetworkManager = require("src.network.manager")

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
        vsync = window.vsync,
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
            autoConnect = true,
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

function love.update(dt)
    if gameplay and gameplay.networkManager then
        gameplay.networkManager:update(dt)
    end
    if gameplay and gameplay.networkServer then
        gameplay.networkServer:update(dt)
    end
end
