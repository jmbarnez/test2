-- player_control.lua
-- Handles player input and controls
-- Processes keyboard and mouse input to control the player's ship
-- Manages movement, rotation, and other player actions
-- Part of the ECS architecture using tiny-ecs

----@diagnostic disable: undefined-global
local tiny = require("libs.tiny")
local vector = require("src.util.vector")
local GameContext = require("src.states.gameplay.context")
local Bindings = require("src.input.bindings")

local keyboard_isDown = love and love.keyboard and love.keyboard.isDown

---@class PlayerControlSystemContext
---@field state table               # Gameplay state or context-resolvable state
---@field camera table|nil          # Camera used for mouse-to-world aim
---@field engineTrail table|nil     # Optional engine trail effect
---@field uiInput table|nil         # Optional UI input capture state
---@field intentHolder table|nil    # Optional holder for playerIntents/localPlayerId

return function(context)
    context = GameContext.compose(GameContext.resolveState(context) or context, context)
    local engineTrail = context.engineTrail
    local uiInput = context.uiInput
    return tiny.system {
        filter = tiny.requireAll("player", "body"),
        process = function(_, entity, dt)
            local body = entity.body
            if not body or body:isDestroyed() then
                return
            end

            local gameplayState = context.state or GameContext.resolveState(context)
            local intentHolder = context.intentHolder or gameplayState
            local localPlayerId = intentHolder and intentHolder.localPlayerId
            local uiInput = context.uiInput

            -- Poll mouse for aiming (local player only)
            local aimX, aimY
            if entity.playerId and localPlayerId and entity.playerId == localPlayerId and context.camera and love.mouse then
                if love.mouse.getPosition and not (uiInput and uiInput.mouseCaptured) then
                    local mx, my = love.mouse.getPosition()
                    local cam = context.camera
                    local zoom = cam.zoom or 1
                    if zoom ~= 0 then
                        aimX = mx / zoom + cam.x
                        aimY = my / zoom + cam.y
                    else
                        aimX = cam.x
                        aimY = cam.y
                    end
                end
            end

            if aimX and aimY then
                local to_mouse_x = aimX - entity.position.x
                local to_mouse_y = aimY - entity.position.y

                if to_mouse_x ~= 0 or to_mouse_y ~= 0 then
                    local desired_angle = math.atan2(to_mouse_y, to_mouse_x) + math.pi * 0.5
                    body:setAngularVelocity(0)
                    body:setAngle(desired_angle)
                    entity.rotation = desired_angle
                end
            end

            local stats = entity.stats or {}
            local mass = stats.mass or body:getMass()
            local thrust = stats.main_thrust or stats.thrust_force or 0
            local max_speed = stats.max_speed or entity.max_speed
            local max_accel = stats.max_acceleration

            -- Poll local player input directly using bindings
            local move_x, move_y = 0, 0
            if entity.playerId and localPlayerId and entity.playerId == localPlayerId then
                if not (uiInput and uiInput.keyboardCaptured) and keyboard_isDown then
                    local bindings = Bindings.getCurrentBindings()
                    
                    -- Check movement keys based on current bindings
                    local function isBindingActive(intentName)
                        local binding = bindings[intentName]
                        if not (binding and binding.keys) then
                            return false
                        end
                        for _, key in ipairs(binding.keys) do
                            if keyboard_isDown(key) then
                                return true
                            end
                        end
                        return false
                    end
                    
                    if isBindingActive("moveLeft") then
                        move_x = move_x - 1
                    end
                    if isBindingActive("moveRight") then
                        move_x = move_x + 1
                    end
                    if isBindingActive("moveUp") then
                        move_y = move_y - 1
                    end
                    if isBindingActive("moveDown") then
                        move_y = move_y + 1
                    end
                    
                    -- Debug logging
                    -- Movement logging removed after debugging
                end
            end

            local applyingThrust = move_x ~= 0 or move_y ~= 0
            entity.isThrusting = applyingThrust

            if applyingThrust then
                local moveDirX, moveDirY = vector.normalize(move_x, move_y)
                move_x, move_y = moveDirX, moveDirY

                local force_x = move_x * thrust
                local force_y = move_y * thrust

                if max_accel and max_accel > 0 and mass > 0 then
                    local max_force = max_accel * mass
                    force_x, force_y = vector.clamp(force_x, force_y, max_force)
                end

                body:applyForce(force_x, force_y)
                entity.currentThrust = vector.length(force_x, force_y)
                entity.engineTrailThrustVectorX = force_x
                entity.engineTrailThrustVectorY = force_y
            else
                entity.currentThrust = 0
                entity.engineTrailThrustVectorX = 0
                entity.engineTrailThrustVectorY = 0
            end

            if engineTrail then
                engineTrail:setActive(applyingThrust)
            end

            if max_speed and max_speed > 0 and not entity._dashActive then
                local vx, vy = body:getLinearVelocity()
                local clampedVX, clampedVY = vector.clamp(vx, vy, max_speed)
                if clampedVX ~= vx or clampedVY ~= vy then
                    body:setLinearVelocity(clampedVX, clampedVY)
                end
            end
        end,
    }
end
