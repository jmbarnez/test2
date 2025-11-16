local table_util = require("src.util.table")

local weapon_defaults = {
    projectileSpeed = 450,
    damage = 66,
    fireRate = 2.0,
    projectileLifetime = 2.0,
    projectileSize = 6,
    offset = 32,
    color = { 1.0, 1.0, 0.2 },
    glowColor = { 1.0, 0.9, 0.5 },
    projectile = {
        lifetime = 2.0,
        damage = 66,
        damageType = "kinetic",
    },
    projectileDrawable = {
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
    weaponMount = {
        forward = 38,
        inset = 0,
        lateral = 0,
        vertical = 0,
        offsetX = 0,
        offsetY = 0,
    },
}

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
    item = {
        value = 220,
        volume = 4,
    },
    icon = {
        kind = "weapon",
        color = { 1.0, 0.92, 0.12 },
        accent = { 1.0, 0.68, 0.2 },
        detail = { 1.0, 0.98, 0.7 },
        layers = {
            { shape = "rounded_rect", width = 0.82, height = 0.42, radius = 0.14, color = { 0.12, 0.1, 0.05, 0.88 }, offsetY = 0.04 },
            { shape = "rounded_rect", width = 0.68, height = 0.3, radius = 0.1, color = { 0.32, 0.28, 0.18, 0.95 } },
            { shape = "rectangle", width = 0.2, height = 0.58, color = { 0.95, 0.76, 0.24, 0.96 }, offsetY = -0.04 },
            { shape = "circle", radius = 0.16, color = { 1.0, 0.9, 0.52, 0.9 }, offsetY = -0.24 },
            { shape = "rectangle", width = 0.12, height = 0.22, color = { 1.0, 0.98, 0.76, 0.7 }, offsetY = 0.18 },
            { shape = "ring", radius = 0.5, thickness = 0.05, color = { 1.0, 0.82, 0.28, 0.25 } },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = weapon_defaults.projectileSpeed,
            damage = weapon_defaults.damage,
            fireRate = weapon_defaults.fireRate,
            damageType = "kinetic",
            projectileLifetime = weapon_defaults.projectileLifetime,
            projectileSize = weapon_defaults.projectileSize,
            firing = false,
            cooldown = 0,
            offset = weapon_defaults.offset,
            color = table_util.clone_array(weapon_defaults.color),
            glowColor = table_util.clone_array(weapon_defaults.glowColor),
            sfx = {
                fire = "sfx:cannon_shot",
            },
            energyPerShot = 0,
            projectileBlueprint = {
                projectile = table_util.deep_copy(weapon_defaults.projectile),
                drawable = table_util.deep_copy(weapon_defaults.projectileDrawable),
            },
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
