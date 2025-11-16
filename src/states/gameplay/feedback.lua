--- UI Feedback System
-- Manages floating text notifications and status toasts

local PlayerManager = require("src.player.manager")
local FloatingText = require("src.effects.floating_text")

local Feedback = {}

--- Show a status toast message
---@param state table Gameplay state
---@param message string Message to display
---@param color table Optional RGBA color table
function Feedback.showToast(state, message, color)
    if not (state and message and FloatingText and FloatingText.add) then
        return
    end

    local player = PlayerManager.getCurrentShip(state)
    local position
    local offsetY = 28

    if player and player.position then
        position = {
            x = player.position.x or 0,
            y = player.position.y or 0,
        }
        offsetY = (player.mountRadius or 36) + 24
    elseif state.camera then
        local cam = state.camera
        local width = cam.width or state.viewport and state.viewport.width or 0
        local height = cam.height or state.viewport and state.viewport.height or 0
        position = {
            x = (cam.x or 0) + width * 0.5,
            y = (cam.y or 0) + height * 0.5,
        }
        offsetY = math.max(24, height * 0.1)
    end

    if not position then
        return
    end

    FloatingText.add(state, position, message, {
        color = color,
        offsetY = offsetY,
        rise = 32,
        scale = 1.1,
    })
end

return Feedback
