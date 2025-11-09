local constants = require("src.constants.game")

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
    icon = {
        kind = "weapon",
        color = { 0.2, 0.9, 1.0 },
        accent = { 0.4, 0.95, 1.0 },
        detail = { 0.7, 1.0, 1.0 },
        layers = {
            { shape = "circle", radius = 0.48, color = { 0.1, 0.4, 0.5 }, alpha = 0.6 },
            { shape = "ring", radius = 0.42, thickness = 0.08, color = { 0.2, 0.7, 0.9 }, alpha = 0.9 },
            { shape = "circle", radius = 0.34, color = { 0.3, 0.85, 1.0 }, alpha = 0.95 },
            { shape = "circle", radius = 0.26, color = { 0.5, 0.9, 1.0 }, alpha = 1.0 },
            { shape = "triangle", width = 0.18, height = 0.22, offsetY = -0.12, color = { 0.8, 1.0, 1.0 }, alpha = 0.9 },
            { shape = "beam", width = 0.24, length = 0.7, color = { 0.4, 0.9, 1.0 }, alpha = 0.8, offsetY = -0.28 },
            { shape = "circle", radius = 0.08, color = { 1.0, 1.0, 1.0 }, alpha = 1.0, offsetY = 0.08 },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = 840,
            damage = 22,
            fireRate = 0.32,
            projectileLifetime = 5.0,
            projectileSize = 3,
            firing = false,
            cooldown = 0,
            offset = 26,
            color = { 0.3, 1.0, 0.45 },
            glowColor = { 0.6, 1.0, 0.8 },
            projectileBlueprint = {
                projectile = {
                    lifetime = 5.0,
                    damage = 22,
                },
                drawable = {
                    type = "projectile",
                    size = 2.4,
                    shape = "beam",
                    width = 3.0,
                    length = 18,
                    color = { 0.2, 1.0, 0.3 },
                    glowColor = { 0.5, 1.0, 0.7 },
                    coreColor = { 0.4, 1.0, 0.6 },
                    highlightColor = { 0.8, 1.0, 0.9 },
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
            forward = 28,
            inset = 0,
            lateral = 0,
            vertical = 0,
            offsetX = 0,
            offsetY = 0,
        },
    },
}
