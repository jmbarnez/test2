local constants = require("src.constants.game")

local weapon_defaults = (constants.weapons and constants.weapons.laser) or {}

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
    id = "laser_basic",
    name = "Basic Laser Cannon",
    assign = "laser",
    components = {
        laser = {
            width = weapon_defaults.width or 3,
            fadeDuration = weapon_defaults.fade_time or 0.08,
            fade = 0,
            firing = false,
            maxRange = weapon_defaults.max_range or 600,
            damagePerSecond = weapon_defaults.damage_per_second or 32,
            offset = weapon_defaults.offset or 30,
            color = with_default(weapon_defaults.color, { 1, 0.3, 0.6 }),
            glowColor = with_default(weapon_defaults.glow_color, { 1, 0.7, 0.9 }),
        },
        weaponMount = {
            forward = weapon_defaults.forward or 36,
            inset = weapon_defaults.inset or 0,
            lateral = weapon_defaults.lateral or 0,
            vertical = weapon_defaults.vertical or 0,
            offsetX = weapon_defaults.offset_x or 0,
            offsetY = weapon_defaults.offset_y or 0,
        },
    },
}
