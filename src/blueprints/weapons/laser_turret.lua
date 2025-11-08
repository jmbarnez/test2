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
        color = { 0.3, 1.0, 0.45 },
        accent = { 0.5, 1.0, 0.68 },
        detail = { 0.75, 1.0, 0.88 },
        layers = {
            { shape = "rounded_rect", width = 0.75, height = 0.32, color = { 0.05, 0.25, 0.07 }, alpha = 0.8, radius = 0.12 },
            { shape = "rounded_rect", width = 0.68, height = 0.24, color = { 0.3, 1.0, 0.45 }, alpha = 0.95, radius = 0.1 },
            { shape = "rounded_rect", width = 0.6, height = 0.16, color = { 0.6, 1.0, 0.78 }, alpha = 0.85, radius = 0.08 },
            { shape = "triangle", direction = "up", width = 0.22, height = 0.26, offsetY = -0.18, color = { 0.85, 1.0, 0.9 }, alpha = 0.9 },
            { shape = "circle", radius = 0.12, color = { 0.55, 1.0, 0.7 }, alpha = 1.0, offsetY = 0.12 },
            { shape = "beam", width = 0.32, length = 0.8, color = { 0.6, 1.0, 0.58 }, alpha = 0.7, offsetY = -0.36 },
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
                    length = 34,
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
