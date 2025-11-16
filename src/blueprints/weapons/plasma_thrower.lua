local table_util = require("src.util.table")
local BehaviorRegistry = require("src.weapons.behavior_registry")
local plasma_thrower_behavior = require("src.weapons.behaviors.plasma_thrower")

-- Register behavior plugin
BehaviorRegistry.register("violet_cloudstream", plasma_thrower_behavior)

local defaults = {
    damage_per_second = 54,
    energy_per_second = 32,
    puffs_per_second = 28,
    lifetime = 0.9,
    radius_min = 14,
    radius_max = 24,
    radius_growth = 11,
    spread_degrees = 46,
    spawn_distance = 24,
    forward_speed = 120,
    drift_speed = 36,
    lateral_jitter = 18,
    max_puffs = 64,
    offset = 20,
    color = { 0.78, 0.26, 1.0 },
    glow_color = { 1.0, 0.62, 1.0 },
    puff_damage_per_second = 2.2,
    forward = 16,
    inset = 0,
    lateral = 0,
    vertical = 0,
    offsetX = 0,
    offsetY = 0,
}

local function copy_default(key, fallback)
    local value = defaults[key]
    if value ~= nil then
        if type(value) == "table" then
            return table_util.clone_array(value)
        end
        return value
    end
    return fallback
end

return {
    category = "weapons",
    id = "plasma_thrower",
    name = "Violet Cloudstream",
    assign = "weapon",
    item = {
        value = 620,
        volume = 4,
    },
    icon = {
        kind = "weapon",
        color = { 0.7, 0.22, 1.0 },
        accent = { 0.5, 0.12, 0.9 },
        detail = { 0.96, 0.6, 1.0 },
        layers = {
            { shape = "rounded_rect", width = 0.72, height = 0.38, color = { 0.12, 0.05, 0.25 }, alpha = 0.88, radius = 0.12 },
            { shape = "rounded_rect", width = 0.6, height = 0.28, color = { 0.48, 0.12, 0.84 }, alpha = 0.94, radius = 0.1 },
            { shape = "beam", width = 0.34, length = 0.98, color = { 1.0, 0.5, 0.96 }, alpha = 0.88 },
            { shape = "beam", width = 0.16, length = 1.0, color = { 0.92, 0.82, 1.0 }, alpha = 0.74 },
            { shape = "flame", radius = 0.18, color = { 1.0, 0.42, 1.0 }, alpha = 0.7, offsetY = 0.18 },
        },
    },
    components = {
        weapon = {
            fireMode = "cloud",
            constantKey = "violet_cloudstream",
            damageType = "energy",
            damagePerSecond = copy_default("damage_per_second", 48),
            energyPerSecond = copy_default("energy_per_second", 28),
            offset = copy_default("offset", 22),
            color = copy_default("color"),
            glowColor = copy_default("glow_color"),
            randomizeColorOnSpawn = false,
            cloudStream = {
                puffsPerSecond = copy_default("puffs_per_second", 24),
                maxPuffs = copy_default("max_puffs", 64),
                lifetime = copy_default("lifetime", 0.8),
                radius = {
                    min = copy_default("radius_min", 14),
                    max = copy_default("radius_max", 24),
                },
                radiusGrowth = copy_default("radius_growth", 8),
                spreadDegrees = copy_default("spread_degrees", 42),
                spawnDistance = copy_default("spawn_distance", 22),
                lateralJitter = copy_default("lateral_jitter", 14),
                forwardSpeed = copy_default("forward_speed", 110),
                driftSpeed = copy_default("drift_speed", 32),
                damagePerSecond = copy_default("puff_damage_per_second", 2.0),
                color = copy_default("color"),
                glowColor = copy_default("glow_color"),
            },
            sfx = {
                fire = "sfx:plasma_thrower_fire",
            },
        },
        weaponMount = {
            forward = copy_default("forward", 16),
            inset = copy_default("inset", 0),
            lateral = copy_default("lateral", 0),
            vertical = copy_default("vertical", 0),
            offsetX = copy_default("offsetX", 0),
            offsetY = copy_default("offsetY", 0),
        },
    },
}
