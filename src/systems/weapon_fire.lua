---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local constants = require("src.constants.game")

local DEFAULT_WEAPON_OFFSET = 30

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

local function spawn_projectile(tinyWorld, physicsWorld, shooter, startX, startY, dirX, dirY, weapon)
    local speed = weapon.projectileSpeed or 450
    local lifetime = weapon.projectileLifetime or 2.0
    local size = weapon.projectileSize or 6
    local damage = weapon.damage or 45
    
    local projectile = {
        position = { x = startX, y = startY },
        velocity = { x = dirX * speed, y = dirY * speed },
        rotation = math.atan2(dirY, dirX) + math.pi * 0.5,
        projectile = {
            lifetime = lifetime,
            damage = damage,
            owner = shooter,
        },
        drawable = {
            type = "projectile",
            size = size,
            color = weapon.color or { 0.2, 0.8, 1.0 },
            glowColor = weapon.glowColor or { 0.5, 0.9, 1.0 },
        },
    }
    
    -- Copy faction from shooter for friend/foe identification
    if shooter.faction then
        projectile.faction = shooter.faction
    end
    if shooter.player then
        projectile.playerProjectile = true
    end
    if shooter.enemy then
        projectile.enemyProjectile = true
    end
    
    -- Create physics body for projectile
    if physicsWorld then
        local body = love.physics.newBody(physicsWorld, startX, startY, "dynamic")
        body:setBullet(true) -- Enable continuous collision detection
        body:setLinearVelocity(dirX * speed, dirY * speed)
        body:setAngle(math.atan2(dirY, dirX) + math.pi * 0.5)
        
        local shape = love.physics.newCircleShape(size * 0.5)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true) -- Projectiles don't collide physically, just detect hits
        fixture:setUserData({ 
            entity = projectile, 
            type = "projectile",
            collider = "projectile"
        })
        
        projectile.body = body
        projectile.fixture = fixture
    end
    
    tinyWorld:add(projectile)
    return projectile
end

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity
    local weaponConst = constants.weapons or {}

    return tiny.system {
        filter = tiny.requireAll("weapon", "position"),
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

                    if entity.player then
                        fire = playerFiring
                        targetX = mx
                        targetY = my
                    else
                        fire = weapon.firing or weapon.alwaysFire
                        targetX = weapon.targetX
                        targetY = weapon.targetY
                    end

                    -- Determine firing direction
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

                    local fireMode = weapon.fireMode or "hitscan"

                    -- PROJECTILE MODE (Cannon, missiles, etc.)
                    if fireMode == "projectile" then
                        if fire and (not weapon.cooldown or weapon.cooldown <= 0) then
                            spawn_projectile(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon)
                            
                            -- Reset cooldown
                            local fireRate = weapon.fireRate or 0.5
                            weapon.cooldown = fireRate
                        end

                    -- HITSCAN MODE (Laser beams)
                    elseif fireMode == "hitscan" then
                        if fire then
                            local laserConst = weaponConst.laser or {}
                            local maxRange = weapon.maxRange or laserConst.max_range or 600
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
                                    local dps = weapon.damagePerSecond or laserConst.damage_per_second or 0
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
