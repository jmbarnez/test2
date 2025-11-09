-- player_control.lua
-- Handles player input and controls
-- Processes keyboard and mouse input to control the player's ship
-- Manages movement, rotation, and other player actions
-- Part of the ECS architecture using tiny-ecs

---@diagnostic disable: undefined-global, deprecated
local tiny = require("libs.tiny")

local control_keys = {
    move_up = { "w", "up" },
    move_down = { "s", "down" },
    move_left = { "a", "left" },
    move_right = { "d", "right" },
}

local function key_down(keys)
    for i = 1, #keys do
        if love.keyboard.isDown(keys[i]) then
            return true
        end
    end
    return false
end

return function(context)
    context = context or {}
    local engineTrail = context.engineTrail
    local uiInput = context.uiInput
    return tiny.system {
        filter = tiny.requireAll("player", "body"),
        process = function(_, entity, dt)
            local body = entity.body
            if not body or body:isDestroyed() then
                return
            end

            if uiInput and (uiInput.keyboardCaptured or uiInput.mouseCaptured) then
                entity.isThrusting = false
                entity.currentThrust = 0
                if engineTrail then
                    engineTrail:setActive(false)
                end
                return
            end

            local mx, my = love.mouse.getPosition()
            local cam = context.camera
            if cam then
                local zoom = cam.zoom or 1
                if zoom ~= 0 then
                    mx = mx / zoom + cam.x
                    my = my / zoom + cam.y
                else
                    mx = cam.x
                    my = cam.y
                end
            end
            local to_mouse_x = mx - entity.position.x
            local to_mouse_y = my - entity.position.y

            if to_mouse_x ~= 0 or to_mouse_y ~= 0 then
                local desired_angle = math.atan2(to_mouse_y, to_mouse_x) + math.pi * 0.5
                body:setAngularVelocity(0)
                body:setAngle(desired_angle)
                entity.rotation = desired_angle
            end

            local stats = entity.stats or {}
            local mass = stats.mass or body:getMass()
            local thrust = stats.main_thrust or stats.thrust_force or 0
            local max_speed = stats.max_speed or entity.max_speed
            local max_accel = stats.max_acceleration

            local move_x, move_y = 0, 0
            if key_down(control_keys.move_left) then
                move_x = move_x - 1
            end
            if key_down(control_keys.move_right) then
                move_x = move_x + 1
            end
            if key_down(control_keys.move_up) then
                move_y = move_y - 1
            end
            if key_down(control_keys.move_down) then
                move_y = move_y + 1
            end

            local applyingThrust = move_x ~= 0 or move_y ~= 0
            entity.isThrusting = applyingThrust

            if applyingThrust then
                local len = math.sqrt(move_x * move_x + move_y * move_y)
                move_x = move_x / len
                move_y = move_y / len

                local force_x = move_x * thrust
                local force_y = move_y * thrust

                if max_accel and max_accel > 0 and mass > 0 then
                    local max_force = max_accel * mass
                    local force_mag_sq = force_x * force_x + force_y * force_y
                    if force_mag_sq > max_force * max_force then
                        local scale = max_force / math.sqrt(force_mag_sq)
                        force_x = force_x * scale
                        force_y = force_y * scale
                    end
                end

                body:applyForce(force_x, force_y)
                entity.currentThrust = math.sqrt(force_x * force_x + force_y * force_y)
                if entity.stats and entity.stats.main_thrust then
                    entity.maxThrust = entity.stats.main_thrust
                end
            else
                entity.currentThrust = 0
            end

            if engineTrail then
                engineTrail:setActive(applyingThrust)
            end

            if max_speed and max_speed > 0 then
                local vx, vy = body:getLinearVelocity()
                local speed_sq = vx * vx + vy * vy
                local max_sq = max_speed * max_speed
                if speed_sq > max_sq then
                    local scale = max_speed / math.sqrt(speed_sq)
                    body:setLinearVelocity(vx * scale, vy * scale)
                end
            end
        end,
    }
end
