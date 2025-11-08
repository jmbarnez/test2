local constants = require("src.constants.game")

local weapon_defaults = (constants.weapons and constants.weapons.cannon) or {}

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
    id = "cannon",
    name = "Plasma Cannon",
    assign = "weapon",
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = weapon_defaults.projectile_speed or 450,
            damage = weapon_defaults.damage or 45,
            fireRate = weapon_defaults.fire_rate or 0.5,
            projectileLifetime = weapon_defaults.projectile_lifetime or 2.0,
            projectileSize = weapon_defaults.projectile_size or 6,
            firing = false,
            cooldown = 0,
            offset = weapon_defaults.offset or 32,
            color = with_default(weapon_defaults.color, { 0.2, 0.8, 1.0 }),
            glowColor = with_default(weapon_defaults.glow_color, { 0.5, 0.9, 1.0 }),
        },
        weaponMount = {
            forward = weapon_defaults.forward or 38,
            inset = weapon_defaults.inset or 0,
            lateral = weapon_defaults.lateral or 0,
            vertical = weapon_defaults.vertical or 0,
            offsetX = weapon_defaults.offset_x or 0,
            offsetY = weapon_defaults.offset_y or 0,
        },
    },
}
