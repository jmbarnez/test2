---Charging orb weapon behavior
---Spawns a growing orb while charging, releases when fire button is released
local weapon_common = require("src.util.weapon_common")

local charging_orb = {}

local MAX_CHARGE_TIME = 3.0  -- Maximum charge time in seconds
local MIN_ORB_SIZE = 8       -- Minimum orb radius
local MAX_ORB_SIZE = 80 / 3  -- Maximum orb radius at full charge
local ORB_SPEED = 250        -- Speed when released
local BASE_DAMAGE = 20       -- Damage at min charge
local MAX_DAMAGE = 180       -- Damage at full charge
local DEFAULT_CHARGE_ENERGY_PER_SECOND = 18

---Initialize charge state
---@param weapon table The weapon component
local function init_charge_state(weapon)
    if not weapon._chargeState then
        weapon._chargeState = {
            charging = false,
            chargeTime = 0,
            orbEntity = nil,
        }
    end
end

---Calculate orb size based on charge time
---@param chargeTime number Current charge time
---@return number size The orb radius
local function calculate_orb_size(chargeTime)
    local chargePercent = math.min(chargeTime / MAX_CHARGE_TIME, 1.0)
    return MIN_ORB_SIZE + (MAX_ORB_SIZE - MIN_ORB_SIZE) * chargePercent
end

---Calculate damage based on charge time
---@param chargeTime number Current charge time
---@return number damage The damage amount
local function calculate_damage(chargeTime)
    local chargePercent = math.min(chargeTime / MAX_CHARGE_TIME, 1.0)
    return BASE_DAMAGE + (MAX_DAMAGE - BASE_DAMAGE) * chargePercent
end

---Spawn or update the charging orb entity
---@param entity table The entity firing
---@param weapon table The weapon component
---@param world table The ECS world
local function update_charging_orb(entity, weapon, world)
    local state = weapon._chargeState
    if not state then
        return
    end
    
    local position = entity.position or { x = 0, y = 0 }
    local orbSize = calculate_orb_size(state.chargeTime)
    
    -- Create orb entity if it doesn't exist
    if not state.orbEntity then
        local angle = (entity.rotation or 0) - math.pi * 0.5
        local spawnDist = 40  -- Distance in front of ship
        
        state.orbEntity = {
            position = {
                x = position.x + math.cos(angle) * spawnDist,
                y = position.y + math.sin(angle) * spawnDist,
            },
            drawable = {
                type = "projectile",
                shape = "charging_orb",
                radius = orbSize,
                color = weapon.color or { 0.3, 0.8, 1.0 },
                glowColor = weapon.glowColor or { 0.6, 0.9, 1.0 },
                chargePercent = math.min(state.chargeTime / MAX_CHARGE_TIME, 1.0),
            },
            _isChargingOrb = true,
            _parentEntity = entity,
        }
        
        if world then
            world:add(state.orbEntity)
        end
    else
        -- Update existing orb
        local angle = (entity.rotation or 0) - math.pi * 0.5
        local spawnDist = 40
        
        state.orbEntity.position.x = position.x + math.cos(angle) * spawnDist
        state.orbEntity.position.y = position.y + math.sin(angle) * spawnDist
        state.orbEntity.drawable.radius = orbSize
        state.orbEntity.drawable.chargePercent = math.min(state.chargeTime / MAX_CHARGE_TIME, 1.0)
    end
end

---Remove the charging orb entity
---@param weapon table The weapon component
---@param world table The ECS world
local function remove_charging_orb(weapon, world)
    local state = weapon._chargeState
    if not state or not state.orbEntity then
        return
    end
    
    if world then
        world:remove(state.orbEntity)
    end
    
    state.orbEntity = nil
end

---Fire the charged orb as a projectile
---@param entity table The entity firing
---@param weapon table The weapon component
---@param context table System context
local function fire_charged_orb(entity, weapon, context)
    local state = weapon._chargeState
    if not state or state.chargeTime <= 0 then
        return
    end
    
    local world = context.world
    local physicsWorld = context.physicsWorld
    
    if not world then
        return
    end
    
    -- Calculate fire direction
    local angle = (entity.rotation or 0) - math.pi * 0.5
    local dirX = math.cos(angle)
    local dirY = math.sin(angle)
    
    -- Calculate start position
    local position = entity.position or { x = 0, y = 0 }
    local spawnDist = 40
    local startX = position.x + dirX * spawnDist
    local startY = position.y + dirY * spawnDist
    
    -- Calculate orb stats based on charge
    local orbSize = calculate_orb_size(state.chargeTime)
    local damage = calculate_damage(state.chargeTime)
    local chargePercent = math.min(state.chargeTime / MAX_CHARGE_TIME, 1.0)
    
    -- Create projectile entity
    local projectile = {
        position = { x = startX, y = startY },
        velocity = { x = dirX * ORB_SPEED, y = dirY * ORB_SPEED },
        rotation = angle,
        projectile = {
            damage = damage,
            damageType = weapon.damageType or "energy",
            lifetime = weapon.projectileLifetime or 5.0,
            owner = entity,
            piercing = false,
        },
        drawable = {
            type = "projectile",
            shape = "charged_orb",
            radius = orbSize,
            color = weapon.color or { 0.3, 0.8, 1.0 },
            glowColor = weapon.glowColor or { 0.6, 0.9, 1.0 },
            chargePercent = chargePercent,
        },
        collidable = {
            type = "projectile",
            radius = orbSize,
            groupIndex = -32,  -- Projectile collision group
        },
        _isOrbProjectile = true,
    }
    
    -- Add physics body if physics world exists
    if physicsWorld then
        local body = love.physics.newBody(physicsWorld, startX, startY, "dynamic")
        body:setLinearVelocity(dirX * ORB_SPEED, dirY * ORB_SPEED)
        body:setBullet(true)
        
        local shape = love.physics.newCircleShape(orbSize)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setSensor(true)
        fixture:setGroupIndex(-32)
        fixture:setUserData(projectile)
        
        projectile.body = body
        projectile.fixture = fixture
    end
    
    world:add(projectile)
    
    -- Play sound effect
    weapon_common.play_weapon_sound(weapon, "fire")
end

---Update function called every frame
---@param entity table The entity
---@param weapon table The weapon component
---@param dt number Delta time
---@param context table System context
function charging_orb.update(entity, weapon, dt, context)
    init_charge_state(weapon)
    
    local state = weapon._chargeState
    local world = context.world
    
    -- Check if fire is requested
    local fireRequested = not not weapon._fireRequested
    local energyChargePerSecond = weapon.energyChargePerSecond or DEFAULT_CHARGE_ENERGY_PER_SECOND

    if fireRequested and energyChargePerSecond > 0 and entity.player then
        local energyCost = energyChargePerSecond * dt
        if energyCost > 0 and not weapon_common.has_energy(entity, energyCost) then
            fireRequested = false
        end
    end
    
    if fireRequested then
        -- Charging
        if not state.charging then
            -- Just started charging
            state.charging = true
            state.chargeTime = 0
        end
        
        -- Increase charge time
        state.chargeTime = math.min(state.chargeTime + dt, MAX_CHARGE_TIME)
        
        -- Update the visual orb
        update_charging_orb(entity, weapon, world)
        
        weapon.firing = true
    else
        -- Not firing
        if state.charging then
            -- Just released - fire the orb!
            fire_charged_orb(entity, weapon, context)
            
            -- Remove the charging orb
            remove_charging_orb(weapon, world)
            
            -- Reset charge state
            state.charging = false
            state.chargeTime = 0
            
            -- Apply cooldown
            local fireRate = weapon.fireRate or 1.0
            weapon.cooldown = fireRate
        end
        
        weapon.firing = false
    end
end

---Fire request handler (not used for charging weapons, logic in update)
---@param entity table The entity
---@param weapon table The weapon component
---@param context table System context
---@return boolean Success
function charging_orb.onFireRequested(entity, weapon, context)
    -- Charging logic is handled in update()
    -- This function exists for compatibility but doesn't do anything
    return true
end

return charging_orb
