---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local constants = require("src.constants.game")

local DEFAULT_LASER_OFFSET = 30

local function compute_muzzle_origin(entity)
    local laser = entity.laser or {}
    local mount = entity.weaponMount
    local angle = entity.rotation or 0
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)

    local localOffsetX = 0
    local localOffsetY = 0

    if mount then
        local forward = mount.forward or mount.length or 0
        local inset = mount.inset or 0
        local lateral = mount.lateral or 0
        local vertical = mount.vertical or 0
        local mountOffsetX = mount.offsetX or 0
        local mountOffsetY = mount.offsetY or 0

        localOffsetX = localOffsetX + lateral + mountOffsetX
        localOffsetY = localOffsetY - (forward - inset) + vertical + mountOffsetY
    else
        localOffsetY = localOffsetY - (laser.offset or DEFAULT_LASER_OFFSET)
    end

    local muzzleOffset = laser.muzzleOffset or laser.offsetLocal
    if muzzleOffset then
        localOffsetX = localOffsetX + (muzzleOffset.x or 0)
        localOffsetY = localOffsetY + (muzzleOffset.y or 0)
    end

    local startX = entity.position.x + localOffsetX * cosAngle - localOffsetY * sinAngle
    local startY = entity.position.y + localOffsetX * sinAngle + localOffsetY * cosAngle

    return startX, startY
end

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity
    local laserConst = constants.weapons and constants.weapons.laser or {}

    return tiny.system {
        filter = tiny.requireAll("laser", "position"),
        init = function(self)
            self.active_beams = {}
        end,
        update = function(self, dt)
            local world = self.world
            if not world then
                return
            end

            local mx, my = love.mouse.getPosition()
            local cam = context.camera
            if cam then
                mx = mx + cam.x
                my = my + cam.y
            end

            local playerFiring = love.mouse.isDown(1)
            local beams = self.active_beams
            for i = 1, #beams do
                beams[i] = nil
            end

            for i = 1, #world.entities do
                local entity = world.entities[i]
                if self.filter(entity) then
                    local laser = entity.laser
                    local angle = entity.rotation or 0
                    local forwardX = math.cos(angle - math.pi * 0.5)
                    local forwardY = math.sin(angle - math.pi * 0.5)
                    local startX, startY = compute_muzzle_origin(entity)

                    local fire = false
                    local targetX, targetY

                    if entity.player then
                        fire = playerFiring
                        targetX = mx
                        targetY = my
                    else
                        fire = laser.firing or laser.alwaysFire
                        targetX = laser.targetX
                        targetY = laser.targetY
                    end

                    if fire then
                        local dirX, dirY
                        if targetX and targetY then
                            dirX = targetX - startX
                            dirY = targetY - startY
                        else
                            dirX = forwardX
                            dirY = forwardY
                        end

                        local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
                        if dirLen < 1e-5 then
                            dirX = forwardX
                            dirY = forwardY
                        else
                            dirX = dirX / dirLen
                            dirY = dirY / dirLen
                        end

                        local maxRange = laser.maxRange or laserConst.max_range or 600
                        local endX = startX + dirX * maxRange
                        local endY = startY + dirY * maxRange

                        local hitInfo
                        if physicsWorld then
                            local closestFraction = 1
                            physicsWorld:rayCast(startX, startY, endX, endY, function(fixture, x, y, xn, yn, fraction)
                                if fixture:getBody() == entity.body then
                                    return -1
                                end
                                local user = fixture:getUserData()
                                if type(user) == "table" and user.entity then
                                    if fraction < closestFraction then
                                        closestFraction = fraction
                                        hitInfo = {
                                            entity = user.entity,
                                            x = x,
                                            y = y,
                                            collider = user.collider,
                                            fraction = fraction,
                                            type = user.type,
                                        }
                                    end
                                    return fraction
                                end
                                return -1
                            end)
                        end

                        if hitInfo then
                            endX = hitInfo.x
                            endY = hitInfo.y
                            local target = hitInfo.entity
                            local shouldDamage = true
                            if target then
                                if entity.faction and target.faction and entity.faction == target.faction then
                                    shouldDamage = false
                                elseif entity.player and target.player then
                                    shouldDamage = false
                                elseif entity.enemy and target.enemy then
                                    shouldDamage = false
                                end
                            end

                            if shouldDamage and damageEntity and target then
                                local dps = laser.damagePerSecond or laserConst.damage_per_second or 0
                                local damage = dps * dt
                                if damage > 0 then
                                    damageEntity(target, damage)
                                end
                            end
                        end

                        beams[#beams + 1] = {
                            x1 = startX,
                            y1 = startY,
                            x2 = endX,
                            y2 = endY,
                        }
                    end
                end
            end
        end,
        draw = function(self)
            local beams = self.active_beams
            if not beams then
                return
            end

            love.graphics.push("all")
            love.graphics.setBlendMode("add")
            
            for i = 1, #beams do
                local beam = beams[i]
                local dx = beam.x2 - beam.x1
                local dy = beam.y2 - beam.y1
                local length = math.sqrt(dx * dx + dy * dy)
                local angle = math.atan2(dy, dx)
                
                love.graphics.push()
                love.graphics.translate(beam.x1, beam.y1)
                love.graphics.rotate(angle)
                
                -- Outer glow
                love.graphics.setColor(0.2, 0.4, 1, 0.1)
                love.graphics.setLineWidth(8)
                love.graphics.line(0, 0, length, 0)
                
                -- Middle beam
                love.graphics.setColor(0.4, 0.7, 1, 0.6)
                love.graphics.setLineWidth(4)
                love.graphics.line(0, 0, length, 0)
                
                -- Inner core
                love.graphics.setColor(0.8, 0.9, 1, 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.line(0, 0, length, 0)
                
                -- Bright center
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(0.8)
                love.graphics.line(0, 0, length, 0)
                
                love.graphics.pop()
            end
            
            love.graphics.pop()
        end,
    }
end
