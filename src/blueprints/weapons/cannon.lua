local constants = require("src.constants.game")

local weapon_defaults = (constants.weapons and constants.weapons.cannon) or {}

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
    id = "cannon",
    name = "Plasma Cannon",
    assign = "weapon",
    icon = {
        kind = "weapon",
        shape = "projectile",
        color = { 1.0, 0.92, 0.12 },
        accent = { 1.0, 0.7, 0.2 },
        detail = { 1.0, 0.98, 0.65 },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = 450,
            damage = 45,
            fireRate = 0.5,
            projectileLifetime = 2.0,
            projectileSize = 6,
            firing = false,
            cooldown = 0,
            offset = 32,
            color = { 1.0, 1.0, 0.2 },
            glowColor = { 1.0, 0.9, 0.5 },
            projectileBlueprint = {
                projectile = {
                    lifetime = 2.0,
                    damage = 45,
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
