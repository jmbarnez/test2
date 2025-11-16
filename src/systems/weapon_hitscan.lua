---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local weapon_common = require("src.util.weapon_common")
local weapon_beam = require("src.util.weapon_beam")
local Entities = require("src.states.gameplay.entities")

local DEFAULT_PLAYER_ENERGY_DRAIN = weapon_common.DEFAULT_PLAYER_ENERGY_DRAIN

local function ensure_table(root, key)
    local tbl = root[key]
    if not tbl then
        tbl = {}
        root[key] = tbl
    end
    return tbl
end

local function queue_segment(weapon, segment)
    local segments = ensure_table(weapon, "_beamSegments")
    segments[#segments + 1] = segment
end

local function queue_impact(weapon, impact)
    local impacts = ensure_table(weapon, "_beamImpactEvents")
    impacts[#impacts + 1] = impact
end

local function fire_hitscan(world, entity, startX, startY, dirX, dirY, weapon, physicsWorld, damageEntity, dt)
    local maxRange = weapon.maxRange or 600
    local endX = startX + dirX * maxRange
    local endY = startY + dirY * maxRange

    if entity and entity.player then
        local drainPerSecond = weapon.energyPerSecond or weapon.energyDrain or DEFAULT_PLAYER_ENERGY_DRAIN
        local energyCost = math.max(0, drainPerSecond * dt)
        if not weapon_common.has_energy(entity, energyCost) then
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
            if type(user) == "table" then
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

    local beamColor = weapon.color or { 0.6, 0.85, 1.0 }
    local beamGlow = weapon.glowColor or { 1.0, 0.8, 0.6 }
    local beamWidth = weapon.width or 3

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
            local dps = weapon.damagePerSecond or 0
            dps = dps * weapon_common.resolve_damage_multiplier(entity)
            local baseDamage = dps * dt
            if baseDamage > 0 then
                local hitX = hitInfo.x
                local hitY = hitInfo.y
                local applied = weapon_beam.apply_hitscan_damage(damageEntity, target, baseDamage, entity, weapon, hitX, hitY)

                if applied > 0 and weapon.chainLightning then
                    local originX, originY = weapon_beam.resolve_entity_position(target)
                    if not (originX and originY) then
                        originX, originY = hitX, hitY
                    end
                    weapon_beam.perform_chain_lightning(world, entity, weapon, damageEntity, baseDamage, target, originX, originY, function(segment)
                        queue_segment(weapon, segment)
                    end, weapon.chainLightning)
                end
            end
        end

        local targetHasShield = Entities.hasActiveShield and Entities.hasActiveShield(target)

        if not targetHasShield then
            queue_impact(weapon, {
                x = endX,
                y = endY,
                dirX = dirX,
                dirY = dirY,
                color = beamColor,
                glow = beamGlow,
            })
        end
    end

    queue_segment(weapon, {
        x1 = startX,
        y1 = startY,
        x2 = endX,
        y2 = endY,
        width = beamWidth,
        color = beamColor,
        glow = beamGlow,
        style = weapon.beamStyle or "straight",
    })
end

---@class WeaponHitscanContext
---@field physicsWorld love.World|nil
---@field damageEntity fun(target:table, amount:number, source:table, context:table)|nil

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld
    local damageEntity = context.damageEntity

    return tiny.processingSystem {
        filter = tiny.requireAll("weapon", "position"),

        process = function(self, entity, dt)
            local weapon = entity.weapon
            if not weapon or weapon.fireMode ~= "hitscan" then
                return
            end

            local world = self.world
            if not world then
                return
            end

            local fire = not not weapon._fireRequested
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

            if usesBurst then
                if triggered then
                    weapon_common.play_weapon_sound(weapon, "fire")
                end
                if not beamActive then
                    weapon._fireSoundPlaying = false
                end
            else
                if beamActive then
                    if not weapon._fireSoundPlaying then
                        weapon_common.play_weapon_sound(weapon, "fire")
                        weapon._fireSoundPlaying = true
                    end
                else
                    weapon._fireSoundPlaying = false
                end
            end

            if beamActive then
                local startX = weapon._muzzleX or (entity.position and entity.position.x) or 0
                local startY = weapon._muzzleY or (entity.position and entity.position.y) or 0
                local dirX = weapon._fireDirX or 0
                local dirY = weapon._fireDirY or -1
                fire_hitscan(world, entity, startX, startY, dirX, dirY, weapon, physicsWorld, damageEntity, dt)
            end

            if usesBurst and weapon.beamTimer then
                weapon.beamTimer = math.max(weapon.beamTimer - dt, 0)
                if weapon.beamTimer <= 0 then
                    weapon.beamTimer = nil
                end
            end

            weapon.firing = beamActive
        end,
    }
end
