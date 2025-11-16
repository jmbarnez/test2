local constants = require("src.constants.game")
local table_util = require("src.util.table")

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
    id = "laser_turret",
    name = "Pulse Laser Turret",
    assign = "weapon",
    item = {
        value = 420,
        volume = 4,
    },
    icon = {
        kind = "weapon",
        color = { 0.2, 0.9, 1.0 },
        accent = { 0.4, 0.95, 1.0 },
        detail = { 0.7, 1.0, 1.0 },
        layers = {
            { shape = "rounded_rect", width = 0.84, height = 0.42, radius = 0.12, color = { 0.08, 0.18, 0.28, 0.92 } },
            { shape = "rounded_rect", width = 0.68, height = 0.3, radius = 0.1, color = { 0.22, 0.58, 0.92, 0.95 } },
            { shape = "rectangle", width = 0.16, height = 0.44, color = { 0.4, 0.95, 1.0, 0.92 }, offsetY = -0.12 },
            { shape = "beam", width = 0.2, length = 0.82, color = { 0.32, 0.9, 1.0, 0.88 }, offsetY = -0.24 },
            { shape = "beam", width = 0.08, length = 0.9, color = { 1.0, 1.0, 1.0, 0.7 }, offsetY = -0.24 },
            { shape = "circle", radius = 0.1, color = { 0.82, 1.0, 1.0, 0.85 }, offsetY = 0.1 },
            { shape = "ring", radius = 0.5, thickness = 0.05, color = { 0.42, 0.88, 1.0, 0.28 } },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = 840,
            damage = 32,
            fireRate = 0.4,
            damageType = "laser",
            energyPerShot = 18,
            projectileLifetime = 5.0,
            projectileSize = 3,
            firing = false,
            cooldown = 0,
            offset = 26,
            color = { 0.3, 1.0, 0.45 },
            glowColor = { 0.6, 1.0, 0.8 },
            sfx = {
                fire = "sfx:laser_turret_fire",
            },
            projectileBlueprint = {
                projectile = {
                    lifetime = 5.0,
                    damage = 32,
                },
                physics = {
                    density = 1e-05,
                    mass = 1e-05,
                    linearDamping = 0.02,
                    gravityScale = 0,
                    sensor = true,
                    bullet = true,
                },
                drawable = {
                    type = "projectile",
                    size = 2.0,
                    shape = "beam",
                    width = 1.5,
                    length = 15,
                    color = { 0.2, 1.0, 0.3 },
                    glowColor = { 0.5, 1.0, 0.7 },
                    coreColor = { 0.4, 1.0, 0.6 },
                    highlightColor = { 0.8, 1.0, 0.9 },
                    outerAlpha = 0.15,
                    innerAlpha = 0.25,
                    coreAlpha = 0.4,
                    highlightAlpha = 0.3,
                    outerScale = 1.0,
                    innerScale = 0.7,
                    coreScale = 0.35,
                    highlightScale = 0.18,
                },
            },
        },
        weaponMount = {
            forward = 28,
            inset = 0,
            lateral = 0,
            vertical = 0,
            offsetX = 0,
            offsetY = 0,
        },
    },
}
