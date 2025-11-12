local constants = require("src.constants.game")
local table_util = require("src.util.table")

local weapon_defaults = (constants.weapons and constants.weapons.cannon) or {}

local function with_default(values, default)
    local copy = table_util.clone_array(values)
    if copy then
        return copy
    end
    if type(default) == "table" then
        return table_util.clone_array(default)
    end
    return default
end

return {
    category = "weapons",
    id = "cannon",
    name = "Cannon",
    assign = "weapon",
    icon = {
        kind = "weapon",
        color = { 1.0, 0.92, 0.12 },
        accent = { 1.0, 0.68, 0.2 },
        detail = { 1.0, 0.98, 0.7 },
        layers = {
            { shape = "circle", radius = 0.46, color = { 1.0, 0.72, 0.08 }, alpha = 0.45 },
            { shape = "ring", radius = 0.46, thickness = 0.08, color = { 1.0, 0.82, 0.25 }, alpha = 0.9 },
            { shape = "circle", radius = 0.33, color = { 1.0, 0.92, 0.2 }, alpha = 0.95 },
            { shape = "circle", radius = 0.18, color = { 1.0, 0.98, 0.75 }, alpha = 1.0 },
            { shape = "rectangle", width = 0.18, height = 0.58, color = { 1.0, 0.88, 0.3 }, alpha = 0.85 },
            { shape = "rectangle", width = 0.12, height = 0.68, color = { 1.0, 1.0, 0.75 }, alpha = 0.6, rotation = 0.785 },
            { shape = "rectangle", width = 0.12, height = 0.68, color = { 1.0, 1.0, 0.75 }, alpha = 0.6, rotation = -0.785 }
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = 450,
            damage = 90,
            fireRate = 2.0,
            damageType = "kinetic",
            projectileLifetime = 2.0,
            projectileSize = 6,
            firing = false,
            cooldown = 0,
            offset = 32,
            color = { 1.0, 1.0, 0.2 },
            glowColor = { 1.0, 0.9, 0.5 },
            energyPerShot = 0,
            projectileBlueprint = {
                projectile = {
                    lifetime = 2.0,
                    damage = 90,
                    damageType = "kinetic",
                },
                drawable = {
                    type = "projectile",
                    size = 6,
                    color = { 1.0, 0.92, 0.12 },
                    glowColor = { 1.0, 0.82, 0.18 },
                    coreColor = { 1.0, 0.88, 0.1 },
                    highlightColor = { 1.0, 0.85, 0.05 },
                    outerAlpha = 0.4,
                    innerAlpha = 0.7,
                    coreAlpha = 1.0,
                    highlightAlpha = 0.85,
                    outerScale = 1.75,
                    innerScale = 1.05,
                    coreScale = 0.7,
                    highlightScale = 0.35,
                },
            },
        },
        weaponMount = {
            forward = 38,
            inset = 0,
            lateral = 0,
            vertical = 0,
            offsetX = 0,
            offsetY = 0,
        },
    },
}
