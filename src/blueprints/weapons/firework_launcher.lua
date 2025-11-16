local table_util = require("src.util.table")

local function clone_color(color)
    return table_util.clone_array(color)
end

local function clone_palette(palette)
    if type(palette) ~= "table" then
        return {}
    end

    local copy = {}
    for i = 1, #palette do
        copy[i] = clone_color(palette[i])
    end
    return copy
end

local FIREWORK_COLORS = {
    { 0.99, 0.39, 0.34 },
    { 1.0, 0.78, 0.34 },
    { 0.46, 0.88, 1.0 },
    { 0.64, 0.52, 1.0 },
    { 0.36, 0.98, 0.62 },
}

local BASE_COLOR = clone_color(FIREWORK_COLORS[1])
local GLOW_COLOR = { 0.98, 0.9, 0.52 }
local CORE_COLOR = { 1.0, 0.97, 0.92 }
local HIGHLIGHT_COLOR = { 1.0, 1.0, 1.0 }

return {
    category = "weapons",
    id = "firework_launcher",
    name = "Firework Launcher",
    assign = "weapon",
    item = {
        value = 360,
        volume = 4,
    },
    icon = {
        kind = "weapon",
        color = clone_color(BASE_COLOR),
        accent = { 0.32, 0.5, 0.96 },
        detail = clone_color(GLOW_COLOR),
        layers = {
            { shape = "rounded_rect", width = 0.8, height = 0.38, radius = 0.14, color = { 0.08, 0.12, 0.22, 0.9 } },
            { shape = "rounded_rect", width = 0.64, height = 0.26, radius = 0.12, color = { 0.2, 0.32, 0.68, 0.95 } },
            { shape = "polygon", points = { -0.12, -0.26, 0.12, -0.26, 0.32, 0.12, -0.32, 0.12 }, color = clone_color(BASE_COLOR), },
            { shape = "circle", radius = 0.18, color = clone_color(GLOW_COLOR), offsetY = -0.08 },
            { shape = "circle", radius = 0.08, color = HIGHLIGHT_COLOR, offsetY = -0.16 },
            { shape = "ring", radius = 0.5, thickness = 0.05, color = { 1.0, 0.78, 0.36, 0.25 } },
        },
    },
    components = {
        weapon = {
            fireMode = "projectile",
            projectileSpeed = 540,
            fireRate = 1.25,
            damage = 20,
            damageType = "laser",
            energyPerShot = 28,
            projectileLifetime = 2.4,
            projectileSize = 2.2,
            offset = 30,
            travelToCursor = true,
            randomizeColorOnFire = true,
            colorPalette = clone_palette(FIREWORK_COLORS),
            glowBoost = 0.52,
            color = clone_color(BASE_COLOR),
            glowColor = clone_color(GLOW_COLOR),
            ignoreCollisions = true,
            delayedBurst = {
                delay = 0,
                countMin = 20,
                countMax = 28,
                spreadDegrees = 330,
                randomizeSpread = true,
                projectileSpeed = 520,
                projectileLifetime = 0.9,
                projectileSize = 1.6,
                projectileDamage = 16,
                randomizeColorOnSpawn = true,
                colorPalette = clone_palette(FIREWORK_COLORS),
                glowBoost = 0.58,
                triggerOnImpact = false,
                triggerOnTimer = false,
                triggerOnExpire = true,
                useCurrentVelocity = false,
                speedMultiplierRange = { 0.75, 1.25 },
                projectileBlueprint = {
                    projectile = {
                        lifetime = 0.9,
                        damage = 16,
                        damageType = "laser",
                    },
                    drawable = {
                        type = "projectile",
                        shape = "beam",
                        size = 1.6,
                        width = 2.5,
                        length = 16,
                        outerAlpha = 0.22,
                        innerAlpha = 0.45,
                        coreAlpha = 0.9,
                        highlightAlpha = 0.95,
                        outerScale = 1.0,
                        innerScale = 0.65,
                        coreScale = 0.4,
                        highlightScale = 0.2,
                        coreColor = HIGHLIGHT_COLOR,
                        highlightColor = HIGHLIGHT_COLOR,
                    },
                    physics = {
                        density = 0.005,
                        linearDamping = 0.12,
                        gravityScale = 0,
                        sensor = true,
                        bullet = true,
                    },
                },
            },
            projectileBlueprint = {
                projectile = {
                    lifetime = 2.4,
                    damage = 20,
                    damageType = "laser",
                },
                drawable = {
                    type = "projectile",
                    size = 2.2,
                    shape = "orb",
                    outerScale = 1.4,
                    innerScale = 0.95,
                    coreScale = 0.55,
                    highlightScale = 0.26,
                    color = clone_color(BASE_COLOR),
                    glowColor = clone_color(GLOW_COLOR),
                    coreColor = CORE_COLOR,
                    highlightColor = HIGHLIGHT_COLOR,
                    outerAlpha = 0.35,
                    innerAlpha = 0.65,
                    coreAlpha = 0.92,
                    highlightAlpha = 1.0,
                },
                physics = {
                    density = 0.02,
                    linearDamping = 0,
                    gravityScale = 0,
                    sensor = true,
                    bullet = true,
                },
            },
        },
        weaponMount = {
            forward = 32,
            inset = 0,
            lateral = 0,
            vertical = 0,
            offsetX = 0,
            offsetY = 0,
        },
    },
}
