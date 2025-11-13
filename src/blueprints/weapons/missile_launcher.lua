local table_util = require("src.util.table")

local defaults = {
    fire_rate = 2.2,
    projectile_speed = 140,
    projectile_lifetime = 4.6,
    projectile_size = 6,
    damage = 110,
    energy_per_shot = 36,
    offset = 34,
    color = { 0.95, 0.62, 0.22 },
    glow_color = { 1.0, 0.86, 0.52 },
    forward = 36,
    inset = 0,
    lateral = 0,
    vertical = 0,
    offsetX = 0,
    offsetY = 0,
}

local function with_default(key, fallback)
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
    id = "missile_launcher",
    name = "Missile Launcher",
    assign = "weapon",
    icon = {
        kind = "weapon",
        color = { 0.95, 0.62, 0.22 },
        accent = { 0.24, 0.38, 0.72 },
        detail = { 0.98, 0.86, 0.46 },
        layers = {
            { shape = "rounded_rect", width = 0.74, height = 0.34, radius = 0.12, color = { 0.08, 0.12, 0.2 }, alpha = 0.8 },
            { shape = "rounded_rect", width = 0.6, height = 0.22, radius = 0.09, color = { 0.2, 0.34, 0.68 }, alpha = 0.9 },
            { shape = "triangle", width = 0.38, height = 0.46, color = { 0.95, 0.62, 0.22 }, alpha = 0.95 },
            { shape = "circle", radius = 0.16, color = { 1.0, 0.92, 0.65 }, alpha = 0.9 },
            { shape = "zigzag", amplitude = 0.12, frequency = 5, length = 0.85, color = { 1.0, 0.84, 0.4 }, alpha = 0.75 },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            constantKey = "missile",
            damageType = "explosive",
            fireRate = with_default("fire_rate", 2.2),
            projectileSpeed = with_default("projectile_speed", 140),
            projectileLifetime = with_default("projectile_lifetime", 4.6),
            projectileSize = with_default("projectile_size", 6),
            damage = with_default("damage", 110),
            energyPerShot = with_default("energy_per_shot", 36),
            offset = with_default("offset", 34),
            color = with_default("color", { 0.95, 0.62, 0.22 }),
            glowColor = with_default("glow_color", { 1.0, 0.86, 0.52 }),
            lockOnTarget = true,
            travelIndicatorRadius = 28,
            projectileHoming = {
                turnRateDegrees = 210,
                acceleration = 720,
                minSpeed = 140,
                maxSpeed = 520,
                faceTarget = true,
                hitRadius = 14,
                explosion = {
                    radius = 72,
                    startRadius = 24,
                    duration = 0.6,
                    color = { 1.0, 0.58, 0.24, 0.9 },
                    ringColor = { 1.0, 0.82, 0.45, 0.85 },
                    ringWidth = 6,
                    ringRadiusScale = 0.82,
                    sparkCount = 18,
                    sparkColor = { 1.0, 0.82, 0.45, 1 },
                    sparkSpeedMin = 160,
                    sparkSpeedMax = 280,
                    sparkLifetimeMin = 0.32,
                    sparkLifetimeMax = 0.62,
                    sparkSizeMin = 2.4,
                    sparkSizeMax = 5.4,
                    sparkGlowScale = 1.8,
                },
            },
            sfx = {
                fire = "sfx:cannon_shot",
            },
            projectileBlueprint = {
                projectile = {
                    lifetime = with_default("projectile_lifetime", 4.6),
                    damage = with_default("damage", 110),
                    damageType = "explosive",
                },
                drawable = {
                    type = "projectile",
                    shape = "missile",
                    length = 26,
                    width = 6,
                    finLength = 8,
                    glowThickness = 4.5,
                    bodyColor = { 0.88, 0.42, 0.18, 0.95 },
                    noseColor = { 1.0, 0.86, 0.52, 1.0 },
                    finColor = { 0.72, 0.32, 0.12, 0.95 },
                    glowColor = { 1.0, 0.78, 0.35, 0.65 },
                    exhaustColor = { 1.0, 0.94, 0.86, 0.8 },
                    outlineColor = { 0.12, 0.08, 0.05, 0.85 },
                },
                physics = {
                    density = 0.18,
                    linearDamping = 0.08,
                    angularDamping = 0.12,
                    gravityScale = 0,
                    bullet = true,
                },
                projectileTrail = {
                    width = 3.4,
                    segment = 4,
                    maxPoints = 36,
                    pointLifetime = 0.42,
                    color = { 1.0, 0.82, 0.48, 0.9 },
                    fadeColor = { 0.96, 0.42, 0.18, 0.1 },
                },
            },
        },
        weaponMount = {
            forward = with_default("forward", 36),
            inset = with_default("inset", 0),
            lateral = with_default("lateral", 0),
            vertical = with_default("vertical", 0),
            offsetX = with_default("offsetX", 0),
            offsetY = with_default("offsetY", 0),
        },
    },
}
