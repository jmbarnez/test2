---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local ProjectileFactory = require("src.entities.projectile_factory")
local weapon_common = require("src.util.weapon_common")

---@class WeaponProjectileSpawnContext
---@field physicsWorld love.World|nil

local DEFAULT_PLAYER_ENERGY_DRAIN = weapon_common.DEFAULT_PLAYER_ENERGY_DRAIN

return function(context)
    context = context or {}
    local physicsWorld = context.physicsWorld

    return tiny.processingSystem {
        filter = tiny.requireAll("weapon", "position"),

        process = function(self, entity, _)
            local weapon = entity.weapon
            if not weapon or weapon.fireMode ~= "projectile" then
                return
            end

            local world = self.world
            if not world then
                return
            end

            local fire = not not weapon._fireRequested
            if not fire then
                weapon.firing = false
                return
            end

            if weapon.cooldown and weapon.cooldown > 0 then
                weapon.firing = true
                return
            end

            if entity.player then
                local shotCost = weapon.energyPerShot
                    or weapon.energyCost
                    or weapon.energyDrain
                    or weapon.energyPerSecond
                    or DEFAULT_PLAYER_ENERGY_DRAIN
                if not weapon_common.has_energy(entity, shotCost) then
                    weapon.firing = false
                    return
                end
            end

            local position = entity.position or { x = 0, y = 0 }
            local startX = weapon._muzzleX or position.x or 0
            local startY = weapon._muzzleY or position.y or 0

            local dirX = weapon._fireDirX
            local dirY = weapon._fireDirY
            if not (dirX and dirY) then
                local angle = (entity.rotation or 0) - math.pi * 0.5
                dirX = math.cos(angle)
                dirY = math.sin(angle)
            end
            local targetX = weapon.targetX
            local targetY = weapon.targetY

            if weapon.travelToCursor and targetX and targetY then
                local dx = targetX - startX
                local dy = targetY - startY
                local speed = weapon.projectileSpeed or 0
                if speed > 0 then
                    local distance = math.sqrt(dx * dx + dy * dy)
                    weapon._shotLifetime = math.max(0.1, distance / speed)
                end
            end

            if weapon.randomizeColorOnFire and weapon.colorPalette then
                local shotColor = weapon_common.random_color_from_palette(weapon.colorPalette)
                if shotColor then
                    weapon._shotColor = shotColor
                    weapon._shotGlow = weapon_common.lighten_color(shotColor, weapon.glowBoost or 0.45)
                end
            end

            if weapon.lockOnTarget and weapon._activeTarget then
                weapon._pendingTargetEntity = weapon._activeTarget
            end

            if weapon.projectilePattern == "shotgun" and type(weapon.shotgunPatternConfig) == "table" then
                weapon_common.fire_shotgun_pattern(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon, weapon.shotgunPatternConfig)
            else
                ProjectileFactory.spawn(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon)
            end

            weapon._pendingTargetEntity = nil

            weapon_common.play_weapon_sound(weapon, "fire")

            local fireRate = weapon.fireRate or 0.5
            weapon.cooldown = fireRate
            weapon.firing = true
        end,
    }
end
