local table_util = require("src.util.table")

local defaults = {
    fire_rate = 0.085,
    projectile_speed = 500,
    projectile_lifetime = 3,
    pellet_damage = 5,
    pellet_count = 100,
    energy_per_shot = 9,
    offset = 20,
    color = { 0.78, 0.26, 1.0 },
    glow_color = { 1.0, 0.62, 1.0 },
    trail_points = 18,
    trail_point_lifetime = 0.6,
    trail_width = 14,
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
    name = "Violet Flamethrower",
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
            fireMode = "projectile",
            constantKey = "violet_flamethrower",
            damageType = "explosive",
            fireRate = copy_default("fire_rate", 0.085),
            projectileSpeed = copy_default("projectile_speed", 160),
            projectileLifetime = copy_default("projectile_lifetime", 0.32),
            projectileSize = 6,
            damage = copy_default("pellet_damage", 0.7),
            energyPerShot = copy_default("energy_per_shot", 6),
            projectilePattern = "shotgun",
            shotgunPatternConfig = {
                count = copy_default("pellet_count", 12),
                spreadDegrees = 52,
                baseJitterDegrees = 22,
                lateralJitter = 14,
                speedMultiplierMin = 0.55,
                speedMultiplierMax = 0.95,
                randomizeSpread = true,
            },
            offset = copy_default("offset", 22),
            color = copy_default("color", { 0.78, 0.26, 1.0 }),
            glowColor = copy_default("glow_color", { 1.0, 0.62, 1.0 }),
            randomizeColorOnSpawn = false,
            glowBoost = 0.5,
            projectilePhysics = {
                density = 0.003,
                linearDamping = 3.4,
                angularDamping = 0,
                gravityScale = 0,
                sensor = true,
                bullet = true,
            },
            projectileBlueprint = {
                projectile = {
                    lifetime = copy_default("projectile_lifetime", 0.32),
                    damage = copy_default("pellet_damage", 0.7),
                    damageType = "explosive",
                },
                drawable = {
                    type = "projectile",
                    shape = "flame_cloud",
                    size = 1,
                    length = 32,
                    width = 16,
                    lobes = 6,
                    radius = 14,
                    tipScale = 0.28,
                    flickerSpeed = 11.5,
                    flickerAmount = 0.2,
                    wobbleScale = 0.4,
                    color = copy_default("color", { 0.78, 0.26, 1.0 }),
                    glowColor = copy_default("glow_color", { 1.0, 0.62, 1.0 }),
                    coreColor = { 1.0, 0.82, 1.0 },
                    highlightColor = { 1.0, 0.95, 1.0 },
                    outerAlpha = 0.36,
                    innerAlpha = 0.78,
                    coreAlpha = 0.88,
                    highlightAlpha = 0.82,
                },
                physics = {
                    density = 0.003,
                    linearDamping = 3.6,
                    gravityScale = 0,
                    sensor = true,
                    bullet = true,
                },
                projectileTrail = {
                    width = copy_default("trail_width", 14),
                    maxPoints = copy_default("trail_points", 18),
                    pointLifetime = copy_default("trail_point_lifetime", 0.6),
                    color = { 0.9, 0.42, 1.0, 0.4 },
                    fadeColor = { 0.7, 0.22, 0.95, 0.02 },
                },
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
