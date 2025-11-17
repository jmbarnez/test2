local table_util = require("src.util.table")
local BehaviorRegistry = require("src.weapons.behavior_registry")
local gravitron_orb_behavior = require("src.weapons.behaviors.gravitron_orb")

BehaviorRegistry.register("gravitron_orb", gravitron_orb_behavior)

local function clone_color(color)
    return table_util.clone_array(color)
end

local BASE_COLOR = { 0.56, 0.78, 1.0 }
local GLOW_COLOR = { 0.34, 0.56, 1.0 }
local CORE_COLOR = { 0.92, 0.98, 1.0 }
local HIGHLIGHT_COLOR = { 0.72, 0.92, 1.0 }

return {
    category = "weapons",
    id = "gravitron_orb",
    name = "Gravitron Orb",
    assign = "weapon",
    item = {
        value = 620,
        volume = 6,
    },
    icon = {
        kind = "weapon",
        color = clone_color(BASE_COLOR),
        accent = { 0.28, 0.44, 0.96 },
        detail = clone_color(GLOW_COLOR),
        layers = {
            { shape = "rounded_rect", width = 0.82, height = 0.4, radius = 0.14, color = { 0.09, 0.12, 0.18, 0.9 } },
            { shape = "rounded_rect", width = 0.66, height = 0.3, radius = 0.12, color = { 0.26, 0.42, 0.78, 0.94 } },
            { shape = "circle", radius = 0.22, color = clone_color(GLOW_COLOR), offsetY = -0.1 },
            { shape = "circle", radius = 0.12, color = clone_color(CORE_COLOR), offsetY = -0.2 },
            { shape = "ring", radius = 0.54, thickness = 0.06, color = { 0.62, 0.84, 1.0, 0.3 } },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            constantKey = "gravitron_orb",
            damageType = "kinetic",
            fireRate = 5.5,
            charge = {
                maxTime = 2.2,
                minTime = 0.0,
                minScale = 0.8,
                maxScale = 2.4,
                energyPerSecond = 32,
            },
            projectileSpeed = 160,
            projectileLifetime = 3.8,
            projectileSize = 3.2,
            energyPerShot = 48,
            offset = 28,
            color = clone_color(BASE_COLOR),
            glowColor = clone_color(GLOW_COLOR),
            projectileTrail = {
                color = clone_color(GLOW_COLOR),
                useGlow = true,
                pointLifetime = 0.6,
                maxPoints = 30,
                segment = 10,
            },
            projectileBlueprint = {
                projectile = {
                    lifetime = 3.8,
                    damage = 14,
                    damageType = "kinetic",
                },
                drawable = {
                    type = "projectile",
                    shape = "orb",
                    size = 3.6,
                    outerScale = 1.5,
                    innerScale = 1.1,
                    coreScale = 0.6,
                    highlightScale = 0.28,
                    color = clone_color(BASE_COLOR),
                    glowColor = clone_color(GLOW_COLOR),
                    coreColor = clone_color(CORE_COLOR),
                    highlightColor = clone_color(HIGHLIGHT_COLOR),
                    outerAlpha = 0.42,
                    innerAlpha = 0.72,
                    coreAlpha = 0.95,
                    highlightAlpha = 1.0,
                },
                physics = {
                    density = 0.05,
                    linearDamping = 0.12,
                    angularDamping = 0.2,
                    gravityScale = 0,
                    sensor = true,
                    bullet = true,
                },
                gravityWell = {
                    radius = 220,
                    minDistance = 26,
                    force = 8200,
                    falloff = 1.35,
                    drag = 85,
                    excludePlayers = true,
                    excludeOwner = true,
                    includeStatic = false,
                    includeProjectiles = false,
                },
            },
        },
        weaponMount = {
            forward = 34,
            inset = 0,
            lateral = 0,
            vertical = 0,
            offsetX = 0,
            offsetY = 0,
        },
    },
}
