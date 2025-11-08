local constants = require("src.constants.game")

local weapon_defaults = (constants.weapons and constants.weapons.laser_turret) or {}

local function clone_array(values)
    if type(values) ~= "table" then
        return values
    end

    local copy = {}
    for i = 1, #values do
        copy[i] = values[i]
    end
    return copy
end

local function with_default(values, default)
    local copy = clone_array(values)
    if copy then
        return copy
    end
    if type(default) == "table" then
        return clone_array(default)
    end
    return default
end

return {
    category = "weapons",
    id = "laser_turret",
    name = "Pulse Laser Turret",
    assign = "weapon",
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = weapon_defaults.projectile_speed or 840,
            damage = weapon_defaults.damage or 22,
            fireRate = weapon_defaults.fire_rate or 0.32,
            projectileLifetime = weapon_defaults.projectile_lifetime or 1.2,
            projectileSize = 3,
            firing = false,
            cooldown = 0,
            offset = weapon_defaults.offset or 26,
            color = with_default(weapon_defaults.color, { 1, 0.45, 0.3 }),
            glowColor = with_default(weapon_defaults.glow_color, { 1, 0.8, 0.6 }),
            projectileBlueprint = {
                projectile = {
                    lifetime = weapon_defaults.projectile_lifetime or 1.2,
                    damage = weapon_defaults.damage or 22,
                },
                drawable = {
                    type = "projectile",
                    size = 2.4,
                    shape = "beam",
                    width = 3.0,
                    length = 34,
                    color = { 1.0, 0.38, 0.85 },
                    glowColor = { 1.0, 0.7, 0.95 },
                    coreColor = { 1.0, 0.55, 0.95 },
                    highlightColor = { 1.0, 0.9, 1.0 },
                    outerAlpha = 0.35,
                    innerAlpha = 0.7,
                    coreAlpha = 1.0,
                    highlightAlpha = 0.8,
                    outerScale = 1.0,
                    innerScale = 0.7,
                    coreScale = 0.35,
                    highlightScale = 0.18,
                },
            },
        },
        weaponMount = {
            forward = weapon_defaults.forward or 28,
            inset = weapon_defaults.inset or 0,
            lateral = weapon_defaults.lateral or 0,
            vertical = weapon_defaults.vertical or 0,
            offsetX = weapon_defaults.offset_x or 0,
            offsetY = weapon_defaults.offset_y or 0,
        },
    },
}
