# Adding New Weapons - Quick Guide

The weapon system now uses a **behavior plugin architecture** that makes adding new weapons super easy!

## Quick Start

### Step 1: Create Your Weapon Blueprint

Create a file in `src/blueprints/weapons/your_weapon.lua`:

```lua
local table_util = require("src.util.table")
local BehaviorRegistry = require("src.weapons.behavior_registry")
local your_weapon_behavior = require("src.weapons.behaviors.your_weapon")

-- Register your weapon behavior (REQUIRED!)
BehaviorRegistry.register("your_weapon_key", your_weapon_behavior)

return {
    category = "weapons",
    id = "your_weapon",
    name = "Your Amazing Weapon",
    assign = "weapon",
    item = {
        value = 500,  -- Shop price
        volume = 4,   -- Inventory space
    },
    components = {
        weapon = {
            fireMode = "projectile",  -- or "hitscan" or "cloud"
            constantKey = "your_weapon_key",  -- MUST match BehaviorRegistry key
            damageType = "kinetic",
            -- ... your weapon stats
        },
        weaponMount = {
            forward = 32,
            inset = 0,
            lateral = 0,
            vertical = 0,
        },
    },
}
```

### Step 2: Create Your Weapon Behavior

Create a file in `src/weapons/behaviors/your_weapon.lua`:

#### For Simple Weapons (Use Base Behaviors)

```lua
-- Simple laser weapon
local base_hitscan = require("src.weapons.behaviors.base_hitscan")

return {
    update = base_hitscan.update,
    onFireRequested = base_hitscan.onFireRequested,
}
```

```lua
-- Simple cannon
local base_projectile = require("src.weapons.behaviors.base_projectile")

return {
    update = base_projectile.update,
    onFireRequested = base_projectile.onFireRequested,
}
```

```lua
-- Simple flamethrower
local base_cloud = require("src.weapons.behaviors.base_cloud")

return {
    update = base_cloud.update,
    onFireRequested = base_cloud.onFireRequested,
}
```

#### For Custom Weapons (Override What You Need)

```lua
local base_projectile = require("src.weapons.behaviors.base_projectile")
local ProjectileFactory = require("src.entities.projectile_factory")

return {
    -- Use base update
    update = base_projectile.update,
    
    -- Custom firing logic
    onFireRequested = function(entity, weapon, context)
        if not base_projectile.checkEnergy(entity, weapon) then
            return false
        end
        
        -- Check cooldown
        if weapon.cooldown and weapon.cooldown > 0 then
            weapon.firing = true
            return false
        end
        
        -- YOUR CUSTOM LOGIC HERE
        local startX, startY, dirX, dirY = base_projectile.getMuzzleAndDirection(entity, weapon)
        
        -- Example: Fire 3 projectiles in a spread
        for i = -1, 1 do
            local angle = math.atan2(dirY, dirX) + math.rad(i * 15)
            local newDirX = math.cos(angle)
            local newDirY = math.sin(angle)
            
            ProjectileFactory.spawn(
                context.world,
                context.physicsWorld,
                entity,
                startX, startY,
                newDirX, newDirY,
                weapon
            )
        end
        
        weapon_common.play_weapon_sound(weapon, "fire")
        base_projectile.applyCooldown(weapon)
        weapon.firing = true
        
        return true
    end,
}
```

### Step 3: Done!

That's it! Your weapon is now fully integrated. The system will:
- ✅ Handle input and targeting (via weapon_logic)
- ✅ Call your behavior plugin
- ✅ Render beams/projectiles automatically
- ✅ Handle energy/cooldowns
- ✅ Apply damage

## Base Behaviors Available

### `base_hitscan` - Instant raycast weapons

**Good for:** Lasers, beams, lightning

**Features:**
- Instant hit detection
- Beam visual effects
- Chain lightning support
- Continuous or burst firing
- Energy drain

**Example:** Laser Beam, Lightning Arc

### `base_projectile` - Spawned projectiles

**Good for:** Cannons, missiles, rockets

**Features:**
- Projectile spawning
- Energy per shot
- Cooldown management
- Lock-on target support
- Travel-to-cursor support
- Color randomization
- Shotgun pattern support

**Example:** Cannon, Missile Launcher

### `base_cloud` - Stream/cloud weapons

**Good for:** Flamethrowers, plasma throwers, gas weapons

**Features:**
- Spawns cloud puffs over time
- Puff physics (growth, movement)
- Damage-over-time
- Energy drain
- Configurable spread and patterns

**Example:** Plasma Thrower

## Common Patterns

### Pattern 1: Simple Weapon

Just use base behavior directly:

```lua
local base_projectile = require("src.weapons.behaviors.base_projectile")

return {
    update = base_projectile.update,
    onFireRequested = base_projectile.onFireRequested,
}
```

### Pattern 2: Custom Projectile Spawn

```lua
local base_projectile = require("src.weapons.behaviors.base_projectile")

return {
    update = base_projectile.update,
    
    onFireRequested = function(entity, weapon, context)
        -- Pre-fire checks
        if not base_projectile.checkEnergy(entity, weapon) then
            return false
        end
        
        if weapon.cooldown and weapon.cooldown > 0 then
            weapon.firing = true
            return false
        end
        
        -- Custom spawn logic
        local startX, startY, dirX, dirY = base_projectile.getMuzzleAndDirection(entity, weapon)
        
        -- ... your custom projectile spawning
        
        weapon_common.play_weapon_sound(weapon, "fire")
        base_projectile.applyCooldown(weapon)
        weapon.firing = true
        
        return true
    end,
}
```

### Pattern 3: Custom Update Logic

```lua
local base_hitscan = require("src.weapons.behaviors.base_hitscan")

return {
    update = function(entity, weapon, dt, context)
        -- Call base update
        base_hitscan.update(entity, weapon, dt, context)
        
        -- Add custom per-frame logic
        if weapon.firing then
            -- ... custom effects, state tracking, etc.
        end
    end,
    
    onFireRequested = base_hitscan.onFireRequested,
}
```

### Pattern 4: Completely Custom Weapon

```lua
return {
    update = function(entity, weapon, dt, context)
        -- 100% custom logic
        -- Handle cooldowns, state, effects, etc.
    end,
    
    onFireRequested = function(entity, weapon, context)
        -- 100% custom firing logic
        return true
    end,
    
    -- Optional: custom rendering
    draw = function(entity, weapon, context)
        -- Custom visual effects
    end,
    
    -- Optional: cleanup
    onDestroy = function(entity, weapon)
        -- Clean up resources
    end,
}
```

## Behavior Interface Reference

Your behavior plugin is a table with these optional functions:

```lua
{
    -- Called every frame for active weapons
    update = function(entity, weapon, dt, context)
        -- entity: The ship/entity firing the weapon
        -- weapon: The weapon component
        -- dt: Delta time
        -- context: { world, physicsWorld, damageEntity, camera, ... }
    end,
    
    -- Called when fire is requested
    onFireRequested = function(entity, weapon, context)
        -- Return true if successfully fired
        return true
    end,
    
    -- Optional: Custom rendering
    draw = function(entity, weapon, context)
        -- Use love.graphics to draw custom effects
    end,
    
    -- Optional: Cleanup
    onDestroy = function(entity, weapon)
        -- Release resources
    end,
}
```

## Context Object

The `context` object passed to behaviors contains:

- `world` - The ECS world (for spawning entities)
- `physicsWorld` - The Box2D physics world
- `damageEntity` - Function to damage entities
- `camera` - The game camera
- `intentHolder` - Input state
- `state` - The game state
- `uiInput` - UI input capture state

## Helper Functions

### From `base_projectile`:

```lua
base_projectile.checkEnergy(entity, weapon) -> boolean
base_projectile.applyCooldown(weapon)
base_projectile.getMuzzleAndDirection(entity, weapon) -> startX, startY, dirX, dirY
base_projectile.handleTravelToCursor(weapon, startX, startY)
base_projectile.handleColorRandomization(weapon)
base_projectile.handleLockOnTarget(weapon)
base_projectile.spawn(world, physicsWorld, entity, weapon, startX, startY, dirX, dirY)
```

### From `base_hitscan`:

```lua
base_hitscan.checkEnergy(entity, weapon, dt) -> boolean
base_hitscan.fire(world, entity, startX, startY, dirX, dirY, weapon, context, dt)
```

### From `base_cloud`:

```lua
base_cloud.checkEnergy(entity, weapon, config, dt) -> boolean
base_cloud.spawnPuff(entity, weapon, config, puffs)
base_cloud.shouldDamage(owner, target) -> boolean
```

### From `weapon_common`:

```lua
weapon_common.has_energy(entity, amount) -> boolean
weapon_common.compute_muzzle_origin(entity) -> startX, startY
weapon_common.play_weapon_sound(weapon, key)
weapon_common.resolve_damage_multiplier(entity) -> multiplier
weapon_common.fire_shotgun_pattern(world, physicsWorld, entity, startX, startY, dirX, dirY, weapon, config)
weapon_common.random_color_from_palette(palette) -> color
weapon_common.lighten_color(color, boost) -> color
```

## Examples

### Gravity Bomb Launcher

```lua
local base_projectile = require("src.weapons.behaviors.base_projectile")
local ProjectileFactory = require("src.entities.projectile_factory")

return {
    update = base_projectile.update,
    
    onFireRequested = function(entity, weapon, context)
        if not base_projectile.checkEnergy(entity, weapon) then
            return false
        end
        
        if weapon.cooldown and weapon.cooldown > 0 then
            weapon.firing = true
            return false
        end
        
        local startX, startY, dirX, dirY = base_projectile.getMuzzleAndDirection(entity, weapon)
        
        -- Spawn slow-moving gravity bomb
        local projectile = ProjectileFactory.spawn(
            context.world,
            context.physicsWorld,
            entity,
            startX, startY,
            dirX, dirY,
            weapon
        )
        
        -- Add custom gravity well behavior
        if projectile then
            projectile.gravityWell = {
                radius = 300,
                strength = 800,
                pullDuration = 3.0,
                detonateAfter = 5.0,
            }
        end
        
        weapon_common.play_weapon_sound(weapon, "fire")
        base_projectile.applyCooldown(weapon)
        weapon.firing = true
        
        return true
    end,
}
```

### Charge Beam

```lua
local base_hitscan = require("src.weapons.behaviors.base_hitscan")

return {
    update = function(entity, weapon, dt, context)
        -- Track charge level
        if weapon._fireRequested then
            weapon._chargeLevel = (weapon._chargeLevel or 0) + dt * 2
            if weapon._chargeLevel > 1.0 then
                weapon._chargeLevel = 1.0
            end
        else
            -- Discharge on release
            if (weapon._chargeLevel or 0) > 0.2 then
                -- Fire charged shot
                local multiplier = weapon._chargeLevel or 1.0
                weapon._damageMultiplier = multiplier
                base_hitscan.update(entity, weapon, dt, context)
            end
            weapon._chargeLevel = 0
        end
    end,
    
    onFireRequested = base_hitscan.onFireRequested,
}
```

## Backward Compatibility

Weapons without a registered behavior automatically fallback to their `fireMode`:
- `fireMode = "hitscan"` → uses `base_hitscan`
- `fireMode = "projectile"` → uses `base_projectile`
- `fireMode = "cloud"` → uses `base_cloud`

This means **all existing weapons work without changes**!

## Migration Checklist

Migrating an existing weapon to use a behavior plugin:

1. ✅ Create behavior file in `src/weapons/behaviors/`
2. ✅ Import and register in weapon blueprint
3. ✅ Set `constantKey` in weapon component
4. ✅ Test in-game
5. ✅ Done!

## FAQ

**Q: Do I need to modify core systems?**  
A: No! Just create your behavior plugin and register it.

**Q: Can I mix and match base behaviors?**  
A: Yes! Use functions from any base behavior in your custom behavior.

**Q: What if I want a completely unique weapon?**  
A: Write a fully custom behavior with `update` and `onFireRequested` functions.

**Q: How do I debug my weapon?**  
A: Add print statements in your behavior functions. They're isolated and easy to debug.

**Q: Can I add custom rendering?**  
A: Yes! Add a `draw` function to your behavior plugin.

## Support

See `docs/WEAPON_SYSTEM_REFACTORING.md` for full architecture details.

Check `src/weapons/behaviors/` for example behaviors you can copy and modify.
