local table_util = require("src.util.table")

local function clone_array(values)
    return table_util.clone_array(values)
end

local BASE_COLOR = { 0.36, 0.78, 1.0 }
local GLOW_COLOR = { 0.5, 0.9, 1.0 }
local CORE_COLOR = { 0.82, 0.96, 1.0 }
local HIGHLIGHT_COLOR = { 0.96, 1.0, 1.0 }

return {
    category = "weapons",
    id = "shock_burst_launcher",
    name = "Shock Burst Launcher",
    assign = "weapon",
    icon = {
        kind = "weapon",
        color = clone_array(BASE_COLOR),
        accent = { 0.24, 0.56, 0.9 },
        detail = clone_array(GLOW_COLOR),
        layers = {
            { shape = "circle", radius = 0.46, color = { 0.18, 0.38, 0.58 }, alpha = 0.85 },
            { shape = "circle", radius = 0.34, color = BASE_COLOR, alpha = 0.95 },
            { shape = "ring", radius = 0.34, thickness = 0.08, color = GLOW_COLOR, alpha = 1.0 },
            { shape = "triangle", width = 0.22, height = 0.42, color = CORE_COLOR, alpha = 0.95, rotation = 0.0 },
            { shape = "triangle", width = 0.22, height = 0.42, color = CORE_COLOR, alpha = 0.95, rotation = math.pi * 2 / 3 },
            { shape = "triangle", width = 0.22, height = 0.42, color = CORE_COLOR, alpha = 0.95, rotation = -math.pi * 2 / 3 },
            { shape = "circle", radius = 0.12, color = HIGHLIGHT_COLOR, alpha = 1.0 },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = 260,
            fireRate = 1.8,
            damage = 120,
            damageType = "kinetic",
            projectileLifetime = 3.4,
            projectileSize = 11,
            energyPerShot = 32,
            offset = 30,
            color = clone_array(BASE_COLOR),
            glowColor = clone_array(GLOW_COLOR),
            delayedBurst = {
                delay = 1.1,
                count = 3,
                spreadDegrees = 28,
                projectileSpeed = 420,
                projectileLifetime = 1.6,
                projectileSize = 6,
                projectileDamage = 42,
                projectileColor = { 0.48, 0.86, 1.0 },
                projectileGlow = { 0.7, 0.96, 1.0 },
                spawnOffset = 10,
                triggerOnImpact = true,
                triggerOnTimer = true,
                triggerOnExpire = true,
            },
            projectileBlueprint = {
                projectile = {
                    lifetime = 3.4,
                    damage = 120,
                    damageType = "kinetic",
                },
                drawable = {
                    type = "projectile",
                    size = 11,
                    shape = "orb",
                    outerScale = 1.9,
                    innerScale = 1.2,
                    coreScale = 0.68,
                    highlightScale = 0.32,
                    color = clone_array(BASE_COLOR),
                    glowColor = clone_array(GLOW_COLOR),
                    coreColor = CORE_COLOR,
                    highlightColor = HIGHLIGHT_COLOR,
                    outerAlpha = 0.35,
                    innerAlpha = 0.6,
                    coreAlpha = 0.9,
                    highlightAlpha = 1.0,
                },
                physics = {
                    density = 0.08,
                    linearDamping = 0.25,
                    gravityScale = 0,
                    sensor = true,
                    bullet = true,
                },
            },
        },
        weaponMount = {
            forward = 36,
            inset = 0,
            lateral = 0,
            vertical = 0,
            offsetX = 0,
            offsetY = 0,
        },
    },
}
