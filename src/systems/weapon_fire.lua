---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local constants = require("src.constants.game")
local vector = require("src.util.vector")
local Intent = require("src.input.intent")
local damage_util = require("src.util.damage")
local ProjectileFactory = require("src.entities.projectile_factory")

local love = love

local DEFAULT_WEAPON_OFFSET = 30

local function resolve_damage_multiplier(shooter)
    if shooter and shooter.enemy then
        return 0.5
    end
    return 1
end

local function compute_muzzle_origin(entity)
    local weapon = entity.weapon or {}
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

        -- Forward offset: move forward along ship's forward axis (negative Y in local space)
        -- Inset: move back from the forward point (reduces forward distance)
        localOffsetX = localOffsetX + lateral + mountOffsetX
        localOffsetY = localOffsetY - (forward - inset) + vertical + mountOffsetY
    else
        localOffsetY = localOffsetY - (weapon.offset or DEFAULT_WEAPON_OFFSET)
    end

    local muzzleOffset = weapon.muzzleOffset or weapon.offsetLocal
    if muzzleOffset then
        localOffsetX = localOffsetX + (muzzleOffset.x or 0)
        localOffsetY = localOffsetY + (muzzleOffset.y or 0)
    end

    local startX = entity.position.x + localOffsetX * cosAngle - localOffsetY * sinAngle
    local startY = entity.position.y + localOffsetX * sinAngle + localOffsetY * cosAngle

    return startX, startY
end
local function spawn_beam_sparks(container, x, y, dirX, dirY, beamColor)
    if not container then
        return
    end

    local baseAngle = math.atan2(dirY, dirX) + math.pi
    local primaryColor = {
        (beamColor[1] or 0.7) * 1.1,
        (beamColor[2] or 0.85) * 1.05,
        (beamColor[3] or 1.0) * 1.05,
        1.0,
    }

    for _ = 1, 12 do
        local jitter = (love.math.random() - 0.5) * math.pi * 0.6
        local angle = baseAngle + jitter
        local speed = love.math.random(140, 240)
        local lifetime = 0.2 + love.math.random() * 0.18

        local spark = {
            x = x + (love.math.random() - 0.5) * 3,
            y = y + (love.math.random() - 0.5) * 3,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            lifetime = lifetime,
            maxLifetime = lifetime,
            size = love.math.random() * 2 + 1.2,
            baseSize = nil,
            color = {
                math.min(1, primaryColor[1]),
                math.min(1, primaryColor[2]),
                math.min(1, primaryColor[3]),
                1.0,
            },
        }
        spark.baseSize = spark.size
        container[#container + 1] = spark
    end
end

local function has_energy(entity, amount)
    local energy = entity and entity.energy
    if not energy then
        return true
    end

    local current = tonumber(energy.current) or 0
    local maxEnergy = tonumber(energy.max) or 0
    local drain = math.max(0, amount)
    local canSpend = current >= drain - 1e-6

    if canSpend and drain > 0 then
        energy.current = current - drain
        if maxEnergy > 0 then
            energy.percent = math.max(0, energy.current / maxEnergy)
        end
        energy.rechargeTimer = energy.rechargeDelay or 0
        energy.isDepleted = energy.current <= 0
    end

    return canSpend
end

local function fire_hitscan(entity, startX, startY, dirX, dirY, weapon, physicsWorld, damageEntity, dt, beams, impacts)
    local weaponConst = constants.weapons or {}
    local beamConst = weaponConst[weapon.constantKey or "laser"] or {}
    
    local maxRange = weapon.maxRange or beamConst.max_range or 600
    local endX = startX + dirX * maxRange
    local endY = startY + dirY * maxRange

    if entity and entity.player then
        local drainPerSecond = weapon.energyPerSecond or weapon.energyDrain or 14
        local energyCost = math.max(0, drainPerSecond * dt)
        if not has_energy(entity, energyCost) then
            return
        end
    end

    local hitInfo
    if physicsWorld then
        local closestFraction = 1
        physicsWorld:rayCast(startX, startY, endX, endY, function(fixture, x, y, xn, yn, fraction)
            if fixture:getBody() == entity.body then
                return -1
            end
            local user = fixture:getUserData()
            if type(user) == "table" and user.entity then
                if user.type == "projectile" then
                    return -1
                end
                if fraction < closestFraction then
                    closestFraction = fraction
                    hitInfo = {
                        entity = user.entity,
                        x = x,
                        y = y,
                        collider = user.collider,
                        fraction = fraction,
                        type = user.type,
                        nx = xn,
                        ny = yn,
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
            local dps = weapon.damagePerSecond or beamConst.damage_per_second or 0
            dps = dps * resolve_damage_multiplier(entity)
            local damage = dps * dt
            if damage > 0 then
                local damageType = weapon.damageType
                local armorType = target.armorType
                local multiplier = damage_util.resolve_multiplier(damageType, armorType)
                damage = damage * multiplier
                if damage > 0 then
                    damageEntity(target, damage, entity, {
                        x = hitInfo.x,
                        y = hitInfo.y,
                    })
                end
            end
        end
    end

    local beamWidth = weapon.width or beamConst.width or 3

    local beamColor = weapon.color or beamConst.color or { 0.6, 0.85, 1.0 }
    local beamGlow = weapon.glowColor or beamConst.glow_color or { 1.0, 0.8, 0.6 }

    if hitInfo and impacts then
        spawn_beam_sparks(impacts, endX, endY, dirX, dirY, beamColor)
    end

    beams[#beams + 1] = {
        x1 = startX,
        y1 = startY,
        x2 = endX,
        y2 = endY,
        width = beamWidth,
        color = beamColor,
        glow = beamGlow,
    }
end

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity

    return tiny.system {
        filter = tiny.requireAll("weapon", "position"),
        init = function(self)
            self.active_beams = {}
            self.beamImpacts = {}
        end,
        update = function(self, dt)
            local world = self.world
            if not world then
                return
            end

            local cam = context.camera
            local intentHolder = context.intentHolder or context.state or context
            local localPlayerId = intentHolder and intentHolder.localPlayerId
            local localPlayerEntity = intentHolder and (intentHolder.player or intentHolder.playerShip)
            local beams = self.active_beams
            local beamImpacts = self.beamImpacts
            for i = 1, #beams do
                beams[i] = nil
            end

            for i = 1, #world.entities do
                local entity = world.entities[i]
                if self.filter(entity) then
                    local weapon = entity.weapon
                    local angle = entity.rotation or 0
                    local forwardX = math.cos(angle - math.pi * 0.5)
                    local forwardY = math.sin(angle - math.pi * 0.5)
                    local startX, startY = compute_muzzle_origin(entity)

                    -- Update weapon cooldown
                    if weapon.cooldown and weapon.cooldown > 0 then
                        weapon.cooldown = weapon.cooldown - dt
                    end

                    local fire = false
                    local targetX, targetY
                    local intent = Intent.get(intentHolder, entity.playerId)
                    local isLocalPlayer = false
                    if entity.player then
                        if localPlayerId then
                            isLocalPlayer = entity.playerId == localPlayerId
                        elseif localPlayerEntity then
                            isLocalPlayer = entity == localPlayerEntity
                        end
                    end

                    if entity.player then
                        if intent then
                            fire = not not intent.firePrimary
                            targetX = intent.aimX
                            targetY = intent.aimY
                        elseif not isLocalPlayer then
                            fire = weapon.firing or weapon.alwaysFire
                            if weapon.fireMode == "hitscan" and weapon.beamTimer and weapon.beamTimer > 0 then
                                fire = true
                            end
                            targetX = weapon.targetX
                            targetY = weapon.targetY
                        end
                    else
                        fire = weapon.firing or weapon.alwaysFire
                        targetX = weapon.targetX
                        targetY = weapon.targetY
                    end

                    if (not targetX or not targetY) and isLocalPlayer and love.mouse then
                        local mx, my = love.mouse.getPosition()
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
                        targetX = targetX or mx
                        targetY = targetY or my
                    end

                    if isLocalPlayer and not fire and love.mouse and love.mouse.isDown then
                        fire = love.mouse.isDown(1)
                    end

                    weapon.targetX = targetX
                    weapon.targetY = targetY

                    -- Determine firing direction
                    local dirX, dirY
                    if targetX and targetY then
                        dirX = targetX - startX
                        dirY = targetY - startY
                    else
                        dirX = forwardX
                        dirY = forwardY
                    end

                    local normDirX, normDirY, dirLen = vector.normalize(dirX, dirY)
                    if dirLen <= vector.EPSILON then
                        dirX = forwardX
                        dirY = forwardY
                    else
                        dirX = normDirX
                        dirY = normDirY
                    end

                    local fireMode = weapon.fireMode or "hitscan"

                    -- PROJECTILE MODE (Cannon, missiles, etc.)
                    if fireMode == "projectile" then
                        -- Only server/offline spawns projectiles; clients receive via snapshots
                        local isClient = context.netRole == 'client'

                        if fire and (not weapon.cooldown or weapon.cooldown <= 0) then
                            if entity and entity.player then
                                local shotCost = weapon.energyPerShot or weapon.energyCost or weapon.energyDrain or weapon.energyPerSecond or 14
                                if not has_energy(entity, shotCost) then
                                    fire = false
                                end
                            end

                            if fire then
                                ProjectileFactory.spawn(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon)

                                -- Reset cooldown
                                local fireRate = weapon.fireRate or 0.5
                                weapon.cooldown = fireRate
                            end
                        end

                        -- Track firing state for visual/audio feedback
                        weapon.firing = fire

                    -- HITSCAN MODE (Laser beams)
                    elseif fireMode == "hitscan" then
                        local usesBurst = weapon.fireRate ~= nil
                        local triggered = false

                        if usesBurst and fire and (not weapon.cooldown or weapon.cooldown <= 0) then
                            weapon.cooldown = weapon.fireRate
                            if weapon.beamDuration and weapon.beamDuration > 0 then
                                weapon.beamTimer = weapon.beamDuration
                            else
                                weapon.beamTimer = nil
                            end
                            triggered = true
                        end

                        local beamActive
                        if usesBurst then
                            if weapon.beamTimer and weapon.beamTimer > 0 then
                                beamActive = true
                            else
                                beamActive = triggered
                            end
                        else
                            beamActive = fire
                        end

                        if beamActive then
                            fire_hitscan(entity, startX, startY, dirX, dirY, weapon, physicsWorld, damageEntity, dt, beams, beamImpacts)
                        end

                        if usesBurst and weapon.beamTimer then
                            weapon.beamTimer = math.max(weapon.beamTimer - dt, 0)
                            if weapon.beamTimer <= 0 then
                                weapon.beamTimer = nil
                            end
                        end

                        weapon.firing = beamActive
                    else
                        weapon.firing = fire
                    end
                end
            end

            for index = #beamImpacts, 1, -1 do
                local spark = beamImpacts[index]
                spark.lifetime = spark.lifetime - dt
                if spark.lifetime <= 0 then
                    table.remove(beamImpacts, index)
                else
                    spark.x = spark.x + spark.vx * dt
                    spark.y = spark.y + spark.vy * dt
                    spark.vx = spark.vx * 0.88
                    spark.vy = spark.vy * 0.88
                    local ratio = spark.maxLifetime > 0 and (spark.lifetime / spark.maxLifetime) or 0
                    if spark.baseSize then
                        spark.size = spark.baseSize * math.max(ratio, 0)
                    end
                    spark.color[4] = math.max(0, ratio)
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
                local length = vector.length(dx, dy)
                local angle = math.atan2(dy, dx)
                
                love.graphics.push()
                love.graphics.translate(beam.x1, beam.y1)
                love.graphics.rotate(angle)

                local baseWidth = beam.width or 3
                local outerWidth = math.max(baseWidth, 1)
                local midWidth = math.max(baseWidth * 0.6, 0.6)
                local innerWidth = math.max(baseWidth * 0.35, 0.35)
                local coreWidth = math.max(baseWidth * 0.18, 0.18)

                local glow = beam.glow or { 1.0, 0.8, 0.6 }
                local color = beam.color or { 0.6, 0.85, 1.0 }

                -- Outer glow
                love.graphics.setColor(glow[1], glow[2], glow[3], 0.1)
                love.graphics.setLineWidth(outerWidth)
                love.graphics.line(0, 0, length, 0)

                -- Middle beam
                love.graphics.setColor(glow[1], glow[2], glow[3], 0.6)
                love.graphics.setLineWidth(midWidth)
                love.graphics.line(0, 0, length, 0)

                -- Inner core
                love.graphics.setColor(color[1], color[2], color[3], 0.9)
                love.graphics.setLineWidth(innerWidth)
                love.graphics.line(0, 0, length, 0)

                -- Bright center
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(coreWidth)
                love.graphics.line(0, 0, length, 0)

                love.graphics.pop()
            end

            local beamImpacts = self.beamImpacts
            if beamImpacts then
                for i = 1, #beamImpacts do
                    local spark = beamImpacts[i]
                    love.graphics.setColor(spark.color)
                    love.graphics.circle("fill", spark.x, spark.y, spark.size)
                end
            end

            love.graphics.pop()
        end,
    }
end
