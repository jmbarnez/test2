local constants = require("src.constants.game")
local table_util = require("src.util.table")

---@diagnostic disable-next-line: undefined-global
local love = love

local DEFAULT_PROJECTILE_COLOR = { 0.2, 0.8, 1.0 }
local DEFAULT_PROJECTILE_GLOW = { 0.5, 0.9, 1.0 }
local PROJECTILE_GROUP_INDEX = -32
local DEFAULT_INDICATOR_OUTLINE = { 0.82, 0.96, 1.0, 0.85 }
local DEFAULT_INDICATOR_INNER = { 0.62, 0.86, 1.0, 0.38 }

local clone_array = table_util.clone_array
local deep_copy = table_util.deep_copy

local function mix_to_one(value, factor)
    value = value or 0
    factor = math.max(0, math.min(factor or 0.35, 1))
    return value + (1 - value) * factor
end

local function lighten_color(color, factor)
    if type(color) ~= "table" then
        return nil
    end
    return {
        mix_to_one(color[1], factor),
        mix_to_one(color[2], factor),
        mix_to_one(color[3], factor),
        color[4] or 1,
    }
end

local function random_color_from_palette(palette)
    if type(palette) ~= "table" then
        return nil
    end

    local count = #palette
    if count <= 0 then
        return nil
    end

    local rng = love and love.math and love.math.random
    local index
    if rng then
        index = rng(1, count)
    else
        index = math.random(1, count)
    end

    local color = palette[index]
    if type(color) == "table" then
        return color
    end

    return nil
end

local ProjectileFactory = {}

local function resolve_damage_type(weapon)
    if weapon and weapon.damageType then
        return weapon.damageType
    end
    local damageConstants = constants.damage or {}
    return damageConstants.defaultDamageType or "default"
end

local function build_secondary_weapon(weapon, burst)
    if not burst then
        return nil
    end

    local secondary = {
        fireMode = "projectile",
        projectileSpeed = burst.projectileSpeed or burst.speed or weapon.projectileSpeed,
        projectileLifetime = burst.projectileLifetime or weapon.projectileLifetime,
        projectileSize = burst.projectileSize or math.max(2, math.floor((weapon.projectileSize or 4) * 0.65 + 0.5)),
        damage = burst.projectileDamage or math.max(1, math.floor((weapon.damage or 20) * 0.55 + 0.5)),
        damageType = burst.damageType or resolve_damage_type(weapon),
        color = clone_array(burst.projectileColor or burst.color) or clone_array(weapon.color),
        glowColor = clone_array(burst.projectileGlow or burst.glowColor) or clone_array(weapon.glowColor),
        projectileBlueprint = deep_copy(burst.projectileBlueprint or weapon.projectileBlueprint),
        projectilePhysics = deep_copy(burst.projectilePhysics or weapon.projectilePhysics),
        energyPerShot = 0,
    }

    if burst.randomizeColorOnSpawn or burst.randomColorOnSpawn then
        secondary.randomizeColorOnSpawn = true
    end

    if burst.colorPalette then
        secondary.colorPalette = deep_copy(burst.colorPalette)
    elseif secondary.randomizeColorOnSpawn and weapon.colorPalette then
        secondary.colorPalette = deep_copy(weapon.colorPalette)
    end

    if burst.glowBoost then
        secondary.glowBoost = burst.glowBoost
    end

    return secondary
end

local function resolve_count(value, default)
    if type(value) ~= "number" then
        return default
    end
    local rounded = math.floor(value + 0.5)
    if rounded < 1 then
        rounded = 1
    end
    return rounded
end

local function attach_delayed_burst(projectile, shooter, dirX, dirY, weapon)
    local burst = weapon and weapon.delayedBurst
    if not burst then
        return
    end

    local defaultCount = resolve_count(burst.count, 3)
    if not defaultCount or defaultCount <= 0 then
        return
    end

    local countMin
    local countMax
    if type(burst.countRange) == "table" then
        countMin = resolve_count(burst.countRange.min or burst.countRange[1], defaultCount)
        countMax = resolve_count(burst.countRange.max or burst.countRange[2], countMin or defaultCount)
    end

    countMin = resolve_count(burst.countMin, countMin)
    countMax = resolve_count(burst.countMax, countMax)

    if not countMin then
        countMin = defaultCount
    end
    if not countMax then
        countMax = countMin
    end

    if countMax < countMin then
        countMin, countMax = countMax, countMin
    end

    local count = countMax
    
    local spread
    if burst.spreadRadians then
        spread = burst.spreadRadians
    elseif burst.spread then
        spread = burst.spread
    elseif burst.spreadDegrees then
        spread = math.rad(burst.spreadDegrees)
    else
        spread = math.rad(24)
    end

    local angleOffset
    if burst.angleOffsetRadians then
        angleOffset = burst.angleOffsetRadians
    elseif burst.angleOffset then
        angleOffset = math.rad(burst.angleOffset)
    else
        angleOffset = 0
    end

    local baseJitter = 0
    if burst.baseJitterRadians then
        baseJitter = burst.baseJitterRadians
    elseif burst.baseJitterDegrees then
        baseJitter = math.rad(burst.baseJitterDegrees)
    elseif burst.baseJitter then
        baseJitter = math.rad(burst.baseJitter)
    end

    local lateralJitter = 0
    if burst.lateralJitter then
        lateralJitter = math.max(0, burst.lateralJitter)
    elseif burst.spawnJitter then
        lateralJitter = math.max(0, burst.spawnJitter)
    end

    local speedMultiplierMin
    local speedMultiplierMax
    if type(burst.speedMultiplierRange) == "table" then
        speedMultiplierMin = burst.speedMultiplierRange.min or burst.speedMultiplierRange[1]
        speedMultiplierMax = burst.speedMultiplierRange.max or burst.speedMultiplierRange[2]
    end

    if burst.speedMultiplierMin then
        speedMultiplierMin = burst.speedMultiplierMin
    end
    if burst.speedMultiplierMax then
        speedMultiplierMax = burst.speedMultiplierMax
    end

    if burst.speedMultiplier then
        speedMultiplierMin = burst.speedMultiplier
        speedMultiplierMax = burst.speedMultiplier
    end

    if speedMultiplierMin and speedMultiplierMax and speedMultiplierMax < speedMultiplierMin then
        speedMultiplierMin, speedMultiplierMax = speedMultiplierMax, speedMultiplierMin
    end

    local delay = burst.delay or 0
    local secondaryWeapon = build_secondary_weapon(weapon, burst)
    if not secondaryWeapon then
        return
    end

    local delayed = {
        timer = delay > 0 and delay or nil,
        count = count,
        countMin = countMin,
        countMax = countMax,
        spread = spread,
        owner = shooter,
        weaponConfig = secondaryWeapon,
        baseDirection = { x = dirX, y = dirY },
        triggerOnImpact = burst.triggerOnImpact ~= false,
        triggerOnExpire = burst.triggerOnExpire ~= false,
        triggerOnTimer = delay > 0 and burst.triggerOnTimer ~= false,
        spawnOffset = burst.spawnOffset or 0,
        angleOffset = angleOffset,
        useCurrentVelocity = burst.useCurrentVelocity ~= false,
        randomizeSpread = burst.randomizeSpread or burst.randomSpread or burst.randomCone or false,
        baseJitter = baseJitter,
        lateralJitter = lateralJitter,
        speedMultiplierMin = speedMultiplierMin,
        speedMultiplierMax = speedMultiplierMax,
    }

    if delay <= 0 and delayed.triggerOnTimer then
        delayed.pendingTrigger = true
    end

    projectile.delayedSpawn = delayed
end

function ProjectileFactory.spawn(tinyWorld, physicsWorld, shooter, startX, startY, dirX, dirY, weapon)
    local speed = weapon.projectileSpeed or 450
    local lifetime = weapon.projectileLifetime or 2.0
    local size = weapon.projectileSize or 6
    local damage = weapon.damage or 45
    local damageMultiplier = 1

    if shooter and shooter.enemy then
        damageMultiplier = 0.5
    end

    local blueprint = weapon.projectileBlueprint
    local projectile = blueprint and deep_copy(blueprint) or {}

    local lifetimeOverride = weapon._shotLifetime
    local colorOverride = weapon._shotColor
    local glowOverride = weapon._shotGlow

    projectile.position = projectile.position or {}
    projectile.position.x = startX
    projectile.position.y = startY

    projectile.velocity = projectile.velocity or {}
    projectile.velocity.x = dirX * speed
    projectile.velocity.y = dirY * speed

    projectile.rotation = math.atan2(dirY, dirX) + math.pi * 0.5

    local projectileComponent = projectile.projectile or {}
    projectileComponent.lifetime = lifetimeOverride or projectileComponent.lifetime or lifetime
    projectileComponent.damage = (projectileComponent.damage or damage) * damageMultiplier
    projectileComponent.owner = shooter
    projectileComponent.ownerPlayerId = shooter and shooter.playerId or nil
    projectileComponent.groupIndex = projectileComponent.groupIndex or PROJECTILE_GROUP_INDEX
    projectileComponent.damageType = projectileComponent.damageType or resolve_damage_type(weapon)
    projectile.projectile = projectileComponent

    local drawable = projectile.drawable or {}
    drawable.type = drawable.type or "projectile"
    drawable.size = drawable.size or size

    local chosenColor = colorOverride
        or (weapon.randomizeColorOnSpawn and random_color_from_palette(weapon.colorPalette))
        or nil
    if not chosenColor and not drawable.color then
        chosenColor = weapon.color or DEFAULT_PROJECTILE_COLOR
    end

    if chosenColor then
        drawable.color = clone_array(chosenColor)
    else
        drawable.color = drawable.color or clone_array(DEFAULT_PROJECTILE_COLOR)
    end

    local chosenGlow = glowOverride
    if not chosenGlow and weapon.randomizeColorOnSpawn then
        local base = chosenColor or drawable.color
        if base then
            chosenGlow = lighten_color(base, weapon.glowBoost or 0.4)
        end
    end

    if not chosenGlow and not drawable.glowColor then
        local base = drawable.color or DEFAULT_PROJECTILE_COLOR
        chosenGlow = lighten_color(base, 0.4)
    end

    if chosenGlow then
        drawable.glowColor = clone_array(chosenGlow)
    else
        drawable.glowColor = drawable.glowColor or clone_array(DEFAULT_PROJECTILE_GLOW)
    end

    projectile.drawable = drawable

    local projectileSize = drawable.size or size
    local physicsConfig = projectile.physics or weapon.projectilePhysics

    local pendingIndicator = weapon._pendingTravelIndicator
    if pendingIndicator then
        local outline = pendingIndicator.outlineColor
        if type(outline) ~= "table" then
            outline = drawable.glowColor or drawable.color or clone_array(DEFAULT_PROJECTILE_GLOW)
            outline = lighten_color(outline, 0.55) or DEFAULT_INDICATOR_OUTLINE
        end

        local inner = pendingIndicator.innerColor
        if type(inner) ~= "table" then
            local baseForInner = drawable.color or outline or DEFAULT_PROJECTILE_COLOR
            inner = lighten_color(baseForInner, 0.2) or DEFAULT_INDICATOR_INNER
        end

        projectile.travelIndicator = {
            x = pendingIndicator.x,
            y = pendingIndicator.y,
            radius = pendingIndicator.radius,
            outlineColor = clone_array(outline) or clone_array(DEFAULT_INDICATOR_OUTLINE),
            innerColor = clone_array(inner) or clone_array(DEFAULT_INDICATOR_INNER),
            timer = 0,
        }

        weapon._pendingTravelIndicator = nil
    end

    if shooter then
        if shooter.faction then
            projectile.faction = shooter.faction
        end
        if shooter.player then
            projectile.playerProjectile = true
        end
        if shooter.enemy then
            projectile.enemyProjectile = true
        end
    end

    if weapon.ignoreCollisions then
        projectile.ignoreCollisions = true
    end

    if physicsWorld then
        local bodyType = (physicsConfig and physicsConfig.type) or "dynamic"
        local body = love.physics.newBody(physicsWorld, startX, startY, bodyType)
        local bulletEnabled = true
        if physicsConfig and physicsConfig.bullet ~= nil then
            bulletEnabled = physicsConfig.bullet
        end
        body:setBullet(bulletEnabled)
        body:setLinearVelocity(dirX * speed, dirY * speed)
        body:setAngle(math.atan2(dirY, dirX) + math.pi * 0.5)

        if physicsConfig then
            if physicsConfig.linearDamping or physicsConfig.damping then
                body:setLinearDamping(physicsConfig.linearDamping or physicsConfig.damping)
            end
            if physicsConfig.angularDamping then
                body:setAngularDamping(physicsConfig.angularDamping)
            end
            if physicsConfig.gravityScale then
                body:setGravityScale(physicsConfig.gravityScale)
            end
            if physicsConfig.fixedRotation ~= nil then
                body:setFixedRotation(physicsConfig.fixedRotation)
            end
        end

        local shape = love.physics.newCircleShape(projectileSize * 0.5)
        local defaultDensity = weapon.projectileDensity or 1
        local density = defaultDensity
        if physicsConfig and physicsConfig.density then
            density = physicsConfig.density
        end

        local fixture = love.physics.newFixture(body, shape, density)
        if physicsConfig and physicsConfig.friction then
            fixture:setFriction(physicsConfig.friction)
        end
        if physicsConfig and physicsConfig.restitution then
            fixture:setRestitution(physicsConfig.restitution)
        end

        local sensor = true
        if physicsConfig and physicsConfig.sensor ~= nil then
            sensor = physicsConfig.sensor
        end
        fixture:setSensor(sensor)
        fixture:setUserData({
            entity = projectile,
            type = "projectile",
            collider = "projectile",
        })

        if projectileComponent.groupIndex then
            fixture:setGroupIndex(projectileComponent.groupIndex)
        end

        if physicsConfig and physicsConfig.mass then
            body:setMassData(
                physicsConfig.mass,
                physicsConfig.massCenterX or 0,
                physicsConfig.massCenterY or 0,
                physicsConfig.inertia or body:getInertia()
            )
        else
            body:resetMassData()
        end

        projectile.body = body
        projectile.fixture = fixture
    end

    attach_delayed_burst(projectile, shooter, dirX, dirY, weapon)

    if weapon._shotLifetime then
        weapon._shotLifetime = nil
    end
    if weapon._shotColor then
        weapon._shotColor = nil
    end
    if weapon._shotGlow then
        weapon._shotGlow = nil
    end

    tinyWorld:add(projectile)
    return projectile
end

return ProjectileFactory
