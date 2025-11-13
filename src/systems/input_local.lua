local tiny = require("libs.tiny")
local Intent = require("src.input.intent")
local PlayerManager = require("src.player.manager")
local math_util = require("src.util.math")

local CONTROL_KEYS = { "lctrl", "rctrl" }

local function is_control_modifier_active()
    if not (love and love.keyboard and love.keyboard.isDown) then
        return false
    end

    for i = 1, #CONTROL_KEYS do
        local key = CONTROL_KEYS[i]
        ---@cast key love.KeyConstant
        if love.keyboard.isDown(key) then
            return true
        end
    end

    return false
end

local function screen_to_world(x, y, camera)
    if not camera then
        return x, y
    end

    local zoom = camera.zoom or 1
    if zoom == 0 then
        return camera.x, camera.y
    end

    local worldX = x / zoom + (camera.x or 0)
    local worldY = y / zoom + (camera.y or 0)
    return worldX, worldY
end

return function(context)
    context = context or {}
    return tiny.system {
        update = function(_, dt)
            local state = context.state
            if not state then
                return
            end

            local playerShip = PlayerManager.getCurrentShip(state)
            if not playerShip then
                return
            end

            local intent = Intent.ensure(state, playerShip.playerId)
            if not intent then
                return
            end

            Intent.reset(intent)

            if context.uiInput and context.uiInput.keyboardCaptured then
                return
            end

            local moveX = 0
            local moveY = 0

            if love.keyboard.isDown("a", "left") then
                moveX = moveX - 1
            end
            if love.keyboard.isDown("d", "right") then
                moveX = moveX + 1
            end
            if love.keyboard.isDown("w", "up") then
                moveY = moveY - 1
            end
            if love.keyboard.isDown("s", "down") then
                moveY = moveY + 1
            end

            Intent.setMove(intent, moveX, moveY)

            if love.mouse then
                local mx, my = love.mouse.getPosition()
                local worldX, worldY = screen_to_world(mx, my, context.camera)

                Intent.setAim(intent, worldX, worldY)
                local primary_down = love.mouse.isDown and love.mouse.isDown(1)
                Intent.setFirePrimary(intent, primary_down and not is_control_modifier_active())
                Intent.setFireSecondary(intent, love.mouse.isDown and love.mouse.isDown(2))
            end

            if love.keyboard then
                Intent.setAbility(intent, 1, love.keyboard.isDown("space"))
            end

        end,
    }
end
