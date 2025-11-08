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

            for i = 1, #beams do
                local beam = beams[i]
                love.graphics.push("all")
                love.graphics.setLineStyle("smooth")
                
                love.graphics.setColor(0.4, 0.7, 1, 0.3)
                love.graphics.setLineWidth(3)
                love.graphics.line(beam.x1, beam.y1, beam.x2, beam.y2)

                love.graphics.setColor(0.6, 0.85, 1, 0.9)
                love.graphics.setLineWidth(1.5)
                love.graphics.line(beam.x1, beam.y1, beam.x2, beam.y2)

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(0.5)
                love.graphics.line(beam.x1, beam.y1, beam.x2, beam.y2)
                
                love.graphics.pop()
            end
        end,
    }
end
