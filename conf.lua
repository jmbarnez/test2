---@diagnostic disable: undefined-global
local constants = require("src.constants.game")

---@param t table
function love.conf(t)
    local loveConf = constants.love
    local window = constants.window

    t.identity = loveConf.identity
    t.version = loveConf.version

    t.window.title = window.title
    t.window.width = window.width
    t.window.height = window.height
    t.window.fullscreen = window.fullscreen
    t.window.resizable = window.resizable
    t.window.vsync = window.vsync
    t.window.msaa = window.msaa

    local modules = loveConf.modules
    t.modules.joystick = modules.joystick
    t.modules.physics = modules.physics
    
    t.console = true
end
