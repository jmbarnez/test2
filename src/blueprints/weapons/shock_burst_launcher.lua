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
            projectileSpeed = 420,
            fireRate = 1.15,
            damage = 10,
            damageType = "kinetic",
            projectileLifetime = 1.2,
            projectileSize = 2.4,
            energyPerShot = 32,
            offset = 30,
            color = clone_array(BASE_COLOR),
            glowColor = clone_array(GLOW_COLOR),
            projectilePattern = "shotgun",
            shotgunPatternConfig = {
                count = 20,
                spreadDegrees = 26,
                baseJitterDegrees = 18,
                lateralJitter = 24,
                speedMultiplierMin = 0.85,
                speedMultiplierMax = 1.25,
                randomizeSpread = true,
            },
            projectileBlueprint = {
                projectile = {
                    lifetime = 1.2,
                    damage = 10,
                    damageType = "kinetic",
                },
                drawable = {
                    type = "projectile",
                    size = 2.4,
                    shape = "orb",
                    outerScale = 1.3,
                    innerScale = 0.9,
                    coreScale = 0.5,
                    highlightScale = 0.22,
                    color = clone_array(BASE_COLOR),
                    glowColor = clone_array(GLOW_COLOR),
                    coreColor = CORE_COLOR,
                    highlightColor = HIGHLIGHT_COLOR,
                    outerAlpha = 0.38,
                    innerAlpha = 0.62,
                    coreAlpha = 0.92,
                    highlightAlpha = 1.0,
                },
                physics = {
                    density = 0.08,
                    linearDamping = 0.2,
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
