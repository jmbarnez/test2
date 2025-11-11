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
    id = "laser_beam",
    name = "Laser Beam",
    assign = "weapon",
    icon = {
        kind = "weapon",
        color = { 0.6, 0.8, 1.0 },
        accent = { 0.35, 0.7, 1.0 },
        detail = { 0.85, 0.95, 1.0 },
        layers = {
            { shape = "rounded_rect", width = 0.7, height = 0.32, color = { 0.12, 0.18, 0.3 }, alpha = 0.8, radius = 0.1 },
            { shape = "rounded_rect", width = 0.62, height = 0.22, color = { 0.28, 0.48, 0.9 }, alpha = 0.95, radius = 0.08 },
            { shape = "beam", width = 0.2, length = 0.9, color = { 0.6, 0.85, 1.0 }, alpha = 0.85 },
            { shape = "beam", width = 0.08, length = 1.0, color = { 1.0, 1.0, 1.0 }, alpha = 0.6 },
        },
    },
    components = {
        weapon = {
            fireMode = "hitscan",
            constantKey = "laser",
            damageType = "laser",
            width = weapon_defaults.width or 1.2,
            fadeDuration = weapon_defaults.fade_time or 0.08,
            fade = 0,
            firing = false,
            maxRange = weapon_defaults.max_range or 600,
            damagePerSecond = weapon_defaults.damage_per_second or 32,
            offset = weapon_defaults.offset or 30,
            color = with_default(weapon_defaults.color, { 0.2, 0.8, 1.0 }),
            glowColor = with_default(weapon_defaults.glow_color, { 0.5, 0.9, 1.0 }),
        },
        weaponMount = {
            forward = weapon_defaults.forward or 12,
            inset = weapon_defaults.inset or 0,
            lateral = weapon_defaults.lateral or 0,
            vertical = weapon_defaults.vertical or 0,
            offsetX = weapon_defaults.offset_x or 0,
            offsetY = weapon_defaults.offset_y or 0,
        },
    },
}
