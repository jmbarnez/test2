local constants = require("src.constants.game")
local table_util = require("src.util.table")

---@diagnostic disable-next-line: undefined-global
local love = love

local DEFAULT_PROJECTILE_COLOR = { 0.2, 0.8, 1.0 }
local DEFAULT_PROJECTILE_GLOW = { 0.5, 0.9, 1.0 }
local PROJECTILE_GROUP_INDEX = -32

local clone_array = table_util.clone_array
local deep_copy = table_util.deep_copy

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

    return secondary
end

local function attach_delayed_burst(projectile, shooter, dirX, dirY, weapon)
    local burst = weapon and weapon.delayedBurst
    if not burst then
        return
    end

    local count = math.max(1, math.floor((burst.count or 3) + 0.5))
    if count <= 0 then
        return
    end

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

    local secondaryWeapon = build_secondary_weapon(weapon, burst)
    if not secondaryWeapon then
        return
    end

    local angleOffset
    if burst.angleOffsetRadians then
        angleOffset = burst.angleOffsetRadians
    elseif burst.angleOffset then
        angleOffset = math.rad(burst.angleOffset)
    end

    local delay = burst.delay or 0
    local delayed = {
        timer = delay > 0 and delay or nil,
        count = count,
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

    projectile.position = projectile.position or {}
    projectile.position.x = startX
    projectile.position.y = startY

    projectile.velocity = projectile.velocity or {}
    projectile.velocity.x = dirX * speed
    projectile.velocity.y = dirY * speed

    projectile.rotation = math.atan2(dirY, dirX) + math.pi * 0.5

    local projectileComponent = projectile.projectile or {}
    projectileComponent.lifetime = projectileComponent.lifetime or lifetime
    projectileComponent.damage = (projectileComponent.damage or damage) * damageMultiplier
    projectileComponent.owner = shooter
    projectileComponent.ownerPlayerId = shooter and shooter.playerId or nil
    projectileComponent.groupIndex = projectileComponent.groupIndex or PROJECTILE_GROUP_INDEX
    projectileComponent.damageType = projectileComponent.damageType or resolve_damage_type(weapon)
    projectile.projectile = projectileComponent

    local drawable = projectile.drawable or {}
    drawable.type = drawable.type or "projectile"
    drawable.size = drawable.size or size
    drawable.color = drawable.color or clone_array(weapon.color) or clone_array(DEFAULT_PROJECTILE_COLOR)
    drawable.glowColor = drawable.glowColor or clone_array(weapon.glowColor) or clone_array(DEFAULT_PROJECTILE_GLOW)
    projectile.drawable = drawable

    local projectileSize = drawable.size or size
    local physicsConfig = projectile.physics or weapon.projectilePhysics

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

    tinyWorld:add(projectile)
    return projectile
end

return ProjectileFactory
