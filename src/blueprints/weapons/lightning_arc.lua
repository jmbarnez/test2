local table_util = require("src.util.table")

local defaults = {
    width = 1.6,
    fade_time = 0.09,
    max_range = 520,
    damage_per_second = 32,
    energy_per_second = 28,
    offset = 30,
    color = { 0.55, 0.9, 1.0 },
    glow_color = { 0.9, 1.0, 1.0 },
    beam_style = "lightning",
    forward = 14,
    inset = 0,
    lateral = 0,
    vertical = 0,
    offsetX = 0,
    offsetY = 0,
}

local function copy_default(key)
    local value = defaults[key]
    if value ~= nil then
        return type(value) == "table" and table_util.clone_array(value) or value
    end
    return nil
end

return {
    category = "weapons",
    id = "lightning_arc",
    name = "Lightning Arc",
    assign = "weapon",
    item = {
        value = 480,
        volume = 4,
    },
    icon = {
        kind = "weapon",
        color = { 0.62, 0.9, 1.0 },
        accent = { 0.32, 0.72, 1.0 },
        detail = { 0.84, 0.96, 1.0 },
        layers = {
            { shape = "rounded_rect", width = 0.68, height = 0.32, color = { 0.08, 0.16, 0.28 }, alpha = 0.85, radius = 0.1 },
            { shape = "rounded_rect", width = 0.58, height = 0.22, color = { 0.2, 0.48, 0.9 }, alpha = 0.95, radius = 0.08 },
            { shape = "zigzag", amplitude = 0.18, frequency = 6, length = 1.0, color = { 0.62, 0.9, 1.0 }, alpha = 0.9 },
            { shape = "zigzag", amplitude = 0.08, frequency = 6, length = 1.0, color = { 1.0, 1.0, 1.0 }, alpha = 0.6 },
        },
    },
    components = {
        weapon = {
            fireMode = "hitscan",
            constantKey = "lightning",
            damageType = "energy",
            width = copy_default("width") or 1.6,
            fadeDuration = copy_default("fade_time") or 0.09,
            fade = 0,
            firing = false,
            maxRange = copy_default("max_range") or 520,
            damagePerSecond = copy_default("damage_per_second") or 32,
            energyPerSecond = copy_default("energy_per_second") or 28,
            offset = copy_default("offset") or 30,
            color = copy_default("color") or { 0.55, 0.9, 1.0 },
            glowColor = copy_default("glow_color") or { 0.9, 1.0, 1.0 },
            beamStyle = copy_default("beam_style") or "lightning",
            chainLightning = {
                maxTargets = 3,
                range = 320,
                falloff = 0.52,
                minFraction = 0.25,
                width = 1.4,
                color = { 0.7, 0.95, 1.0 },
                glowColor = { 0.9, 1.0, 1.0 },
            },
            sfx = {
                fire = "sfx:lightning_arc",
            },
        },
        weaponMount = {
            forward = copy_default("forward") or 14,
            inset = copy_default("inset") or 0,
            lateral = copy_default("lateral") or 0,
            vertical = copy_default("vertical") or 0,
            offsetX = copy_default("offsetX") or 0,
            offsetY = copy_default("offsetY") or 0,
        },
    },
}
