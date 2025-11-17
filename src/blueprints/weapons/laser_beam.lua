local table_util = require("src.util.table")
local BehaviorRegistry = require("src.weapons.behavior_registry")
local laser_beam_behavior = require("src.weapons.behaviors.laser_beam")

-- Register behavior plugin
BehaviorRegistry:register("laser", laser_beam_behavior)

local weapon_defaults = {
    width = 1.2,
    fade_time = 0.08,
    max_range = 600,
    damage_per_second = 22,
    energy_per_second = 24,
    offset = 30,
    color = { 0.2, 0.8, 1.0 },
    glow_color = { 0.5, 0.9, 1.0 },
    forward = 12,
    inset = 0,
    lateral = 0,
    vertical = 0,
    offsetX = 0,
    offsetY = 0,
}

local function default(key, fallback)
    local value = weapon_defaults[key]
    if value ~= nil then
        return type(value) == "table" and table_util.clone_array(value) or value
    end
    return fallback
end

return {
    category = "weapons",
    id = "laser_beam",
    name = "Laser Beam",
    assign = "weapon",
    item = {
        value = 260,
        volume = 3,
    },
    icon = {
        kind = "weapon",
        color = { 0.6, 0.8, 1.0 },
        accent = { 0.35, 0.7, 1.0 },
        detail = { 0.85, 0.95, 1.0 },
        layers = {
            { shape = "rounded_rect", width = 0.76, height = 0.36, radius = 0.12, color = { 0.08, 0.12, 0.2, 0.92 } },
            { shape = "rounded_rect", width = 0.62, height = 0.26, radius = 0.1, color = { 0.22, 0.44, 0.86, 0.96 } },
            { shape = "beam", width = 0.22, length = 1.0, color = { 0.64, 0.86, 1.0, 0.9 } },
            { shape = "beam", width = 0.1, length = 1.02, color = { 1.0, 1.0, 1.0, 0.68 } },
            { shape = "ring", radius = 0.52, thickness = 0.05, color = { 0.52, 0.78, 1.0, 0.28 } },
        },
    },
    components = {
        weapon = {
            fireMode = "hitscan",
            constantKey = "laser",
            damageType = "laser",
            width = default("width", 1.2),
            fadeDuration = default("fade_time", 0.08),
            fade = 0,
            firing = false,
            maxRange = default("max_range", 600),
            damagePerSecond = default("damage_per_second", 22),
            energyPerSecond = default("energy_per_second", 24),
            offset = default("offset", 30),
            color = default("color", { 0.2, 0.8, 1.0 }),
            glowColor = default("glow_color", { 0.5, 0.9, 1.0 }),
        },
        weaponMount = {
            forward = default("forward", 12),
            inset = default("inset", 0),
            lateral = default("lateral", 0),
            vertical = default("vertical", 0),
            offsetX = default("offset_x", 0),
            offsetY = default("offset_y", 0),
        },
    },
}
