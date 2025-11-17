local table_util = require("src.util.table")
local BehaviorRegistry = require("src.weapons.behavior_registry")
local charging_orb_behavior = require("src.weapons.behaviors.charging_orb")

-- Register the behavior
BehaviorRegistry:register("charging_orb", charging_orb_behavior)

local weapon_defaults = {
    fireRate = 1.5,
    damageType = "energy",
    projectileLifetime = 5.0,
    offset = 32,
    color = { 0.3, 0.8, 1.0 },
    glowColor = { 0.6, 0.9, 1.0 },
    weaponMount = {
        forward = 38,
        inset = 0,
        lateral = 0,
        vertical = 0,
        offsetX = 0,
        offsetY = 0,
    },
}

return {
    category = "weapons",
    id = "charging_orb",
    name = "Charging Orb",
    assign = "weapon",
    item = {
        value = 450,
        volume = 6,
    },
    icon = {
        kind = "weapon",
        color = { 0.3, 0.8, 1.0 },
        accent = { 0.6, 0.9, 1.0 },
        detail = { 0.8, 0.95, 1.0 },
        layers = {
            { shape = "circle", radius = 0.48, color = { 0.1, 0.15, 0.25, 0.9 } },
            { shape = "circle", radius = 0.38, color = { 0.2, 0.5, 0.85, 0.7 } },
            { shape = "circle", radius = 0.28, color = { 0.4, 0.75, 0.95, 0.85 } },
            { shape = "circle", radius = 0.18, color = { 0.7, 0.9, 1.0, 0.95 } },
            { shape = "circle", radius = 0.08, color = { 1.0, 1.0, 1.0, 1.0 } },
            { shape = "ring", radius = 0.52, thickness = 0.04, color = { 0.5, 0.85, 1.0, 0.6 } },
        },
    },
    components = {
        weapon = {
            constantKey = "charging_orb",
            fireMode = "charging",  -- Custom fire mode
            fireRate = weapon_defaults.fireRate,
            damageType = weapon_defaults.damageType,
            projectileLifetime = weapon_defaults.projectileLifetime,
            firing = false,
            cooldown = 0,
            offset = weapon_defaults.offset,
            color = table_util.clone_array(weapon_defaults.color),
            glowColor = table_util.clone_array(weapon_defaults.glowColor),
            sfx = {
                fire = "sfx:plasma_ball",  -- Use a suitable sound effect
            },
            energyPerShot = 0,  -- No energy cost for now, can be added later
        },
        weaponMount = {
            forward = weapon_defaults.weaponMount.forward,
            inset = weapon_defaults.weaponMount.inset,
            lateral = weapon_defaults.weaponMount.lateral,
            vertical = weapon_defaults.weaponMount.vertical,
            offsetX = weapon_defaults.weaponMount.offsetX,
            offsetY = weapon_defaults.weaponMount.offsetY,
        },
    },
}
