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
    item = {
        value = 320,
        volume = 4,
    },
    icon = {
        kind = "weapon",
        color = clone_array(BASE_COLOR),
        accent = { 0.24, 0.56, 0.9 },
        detail = clone_array(GLOW_COLOR),
        layers = {
            { shape = "rounded_rect", width = 0.8, height = 0.38, radius = 0.12, color = { 0.1, 0.26, 0.42, 0.92 } },
            { shape = "rounded_rect", width = 0.64, height = 0.28, radius = 0.1, color = { 0.24, 0.52, 0.9, 0.95 } },
            { shape = "polygon", points = { -0.14, -0.24, 0.14, -0.24, 0.32, 0.12, -0.32, 0.12 }, color = BASE_COLOR },
            { shape = "circle", radius = 0.18, color = GLOW_COLOR, offsetY = -0.08 },
            { shape = "circle", radius = 0.08, color = CORE_COLOR, offsetY = -0.16 },
            { shape = "rectangle", width = 0.12, height = 0.2, color = CORE_COLOR, offsetY = 0.16 },
            { shape = "ring", radius = 0.5, thickness = 0.05, color = { 0.52, 0.84, 1.0, 0.28 } },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = 420,
            fireRate = 1.15,
            damage = 8,
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
                    damage = 8,
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
