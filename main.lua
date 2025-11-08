---@diagnostic disable: undefined-global
local Gamestate = require("libs.hump.gamestate")
local constants = require("src.constants.game")
local gameplay = require("src.states.gameplay")

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
end
