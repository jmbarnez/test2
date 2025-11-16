# Weapon System Refactoring Proposal

## Current State Analysis

### Architecture Overview

Your weapon system is currently structured around **fireMode** types:
- **hitscan** - Instant raycast weapons (lasers, beams)
- **projectile** - Spawned projectile weapons (cannons, missiles)
- **cloud** - Stream/cloud weapons (plasma thrower)

### Current Components

**Systems (src/systems/):**
1. `weapon_logic.lua` - Universal input handling, aiming, fire requests
2. `weapon_hitscan.lua` - Hitscan firing, damage, beam generation
3. `weapon_projectile_spawn.lua` - Projectile spawning
4. `weapon_cloud_stream.lua` - Cloud/stream weapon behavior
5. `weapon_beam_vfx.lua` - Beam visual effects rendering

**Supporting:**
- `weapon_common.lua` - Shared utilities (energy, cooldowns, muzzle calculation)
- `weapon_beam.lua` - Beam damage, chain lightning, impact effects
- `projectile_factory.lua` - Projectile creation with custom behaviors
- `projectile.lua` system - Projectile behaviors (homing, delayed burst, etc.)

**Blueprints (src/blueprints/weapons/):**
- Each weapon is a separate .lua file with configuration data
- Blueprints define components, stats, and behavior parameters

### Problems Identified

1. **Scattered Logic**: Weapon behavior is split across multiple systems based on fireMode
2. **Hard to Extend**: Adding unique weapon behavior requires modifying generic systems
3. **Poor Separation**: Generic systems contain weapon-specific code (e.g., chain lightning in hitscan)
4. **No Plugin Architecture**: Can't add custom weapons without touching core systems
5. **Testing Difficulty**: Hard to test weapons in isolation
6. **Code Duplication**: Similar patterns repeated across systems

## Proposed Refactoring Strategy

### Core Concept: Weapon Behavior Plugins

Move from **fireMode-based systems** to a **behavior plugin architecture**:

```
Weapon Blueprint → Behavior Plugin → Generic Systems
```

### Architecture Design

#### 1. Weapon Behavior Registry

Create a registry that maps weapon IDs to behavior plugins:

```lua
-- src/weapons/behavior_registry.lua
local BehaviorRegistry = {
    behaviors = {}
}

function BehaviorRegistry.register(weaponId, behavior)
    -- Register a behavior plugin for a weapon
end

function BehaviorRegistry.get(weaponId)
    -- Get the behavior plugin for a weapon
end
```

#### 2. Weapon Behavior Interface

Define a standard interface for weapon behaviors:

```lua
-- Behavior Plugin Interface
{
    -- Called once per frame when weapon is active
    update = function(entity, weapon, dt, context)
        -- Update weapon state, cooldowns, etc.
    end,
    
    -- Called when fire is requested
    onFireRequested = function(entity, weapon, context)
        -- Handle firing logic
        -- Return: success (boolean)
    end,
    
    -- Optional: Custom rendering
    draw = function(entity, weapon, context)
        -- Render weapon effects
    end,
    
    -- Optional: Cleanup
    onDestroy = function(entity, weapon)
        -- Clean up resources
    end
}
```

#### 3. Generic Weapon System

Single system that delegates to behavior plugins:

```lua
-- src/systems/weapon_unified.lua
return function(context)
    return tiny.processingSystem {
        filter = tiny.requireAll("weapon", "position"),
        
        process = function(self, entity, dt)
            local weapon = entity.weapon
            local behavior = BehaviorRegistry.get(weapon.constantKey)
            
            if behavior then
                -- Delegate to plugin
                if behavior.update then
                    behavior.update(entity, weapon, dt, context)
                end
                
                if weapon._fireRequested and behavior.onFireRequested then
                    behavior.onFireRequested(entity, weapon, context)
                end
            end
        end
    }
end
```

### Implementation Phases

#### Phase 1: Create Plugin Infrastructure ✓

1. **Behavior Registry** (`src/weapons/behavior_registry.lua`)
   - Central registry for weapon behaviors
   - Plugin registration and lookup
   
2. **Base Behaviors** (`src/weapons/behaviors/`)
   - `base_hitscan.lua` - Reusable hitscan logic
   - `base_projectile.lua` - Reusable projectile logic
   - `base_cloud.lua` - Reusable cloud/stream logic
   
3. **Behavior Utilities** (`src/weapons/behavior_utils.lua`)
   - Shared behavior helpers
   - Common firing patterns

#### Phase 2: Migrate Existing Weapons

Convert existing weapons to use behavior plugins:

**Simple Weapons:**
```lua
-- src/weapons/behaviors/laser_beam.lua
local base_hitscan = require("src.weapons.behaviors.base_hitscan")

return {
    update = base_hitscan.update,
    onFireRequested = base_hitscan.onFireRequested,
    
    -- Optional custom configuration
    config = {
        energyCostMode = "continuous",
        beamStyle = "straight"
    }
}
```

**Complex Weapons:**
```lua
-- src/weapons/behaviors/firework_launcher.lua
local base_projectile = require("src.weapons.behaviors.base_projectile")
local ProjectileFactory = require("src.entities.projectile_factory")

return {
    update = base_projectile.update,
    
    onFireRequested = function(entity, weapon, context)
        -- Custom firing logic
        if not base_projectile.checkEnergy(entity, weapon) then
            return false
        end
        
        -- Spawn projectile with delayed burst
        ProjectileFactory.spawn(
            context.world,
            context.physicsWorld,
            entity,
            weapon._muzzleX,
            weapon._muzzleY,
            weapon._fireDirX,
            weapon._fireDirY,
            weapon
        )
        
        base_projectile.applyCooldown(weapon)
        return true
    end
}
```

#### Phase 3: Unify Core Systems

Replace multiple weapon systems with unified system:

1. Keep `weapon_logic.lua` for input handling
2. Replace `weapon_hitscan.lua`, `weapon_projectile_spawn.lua`, `weapon_cloud_stream.lua` with single `weapon_unified.lua`
3. Keep `weapon_beam_vfx.lua` for rendering (or integrate into behaviors)
4. Keep support utilities (`weapon_common.lua`, `weapon_beam.lua`)

#### Phase 4: Registration System

Auto-register weapons when blueprints load:

```lua
-- src/blueprints/weapons/laser_beam.lua
local BehaviorRegistry = require("src.weapons.behavior_registry")
local laser_beam_behavior = require("src.weapons.behaviors.laser_beam")

-- Register behavior
BehaviorRegistry.register("laser", laser_beam_behavior)

return {
    category = "weapons",
    id = "laser_beam",
    -- ... rest of blueprint
}
```

### Benefits of This Approach

#### 1. **Easy to Add Weapons**
```lua
-- Create new behavior plugin
-- Register it
-- Done - no touching core systems
```

#### 2. **Isolated Logic**
- Each weapon's behavior is self-contained
- Easy to understand weapon at a glance
- Easy to test in isolation

#### 3. **Flexible Customization**
- Override specific methods for unique behavior
- Reuse base behaviors for common patterns
- Mix and match behavior components

#### 4. **Backward Compatible**
- Can migrate weapons incrementally
- Old system can run alongside new
- Low risk refactoring

#### 5. **Maintainable**
- Clear separation of concerns
- Single responsibility per plugin
- Easy to locate bugs

### Example: Adding a New Weapon Type

**Before (Current System):**
1. Create blueprint → Define weapon config
2. Modify `weapon_hitscan.lua` or `weapon_projectile_spawn.lua` → Add special cases
3. Modify `weapon_logic.lua` → Handle special input
4. Modify `weapon_beam_vfx.lua` → Add rendering
5. Test → Hope nothing broke

**After (Plugin System):**
1. Create blueprint → Define weapon config
2. Create behavior plugin → Implement weapon logic
3. Register behavior → One line
4. Test → Isolated to this weapon

```lua
-- src/weapons/behaviors/gravity_well_launcher.lua
local base_projectile = require("src.weapons.behaviors.base_projectile")

return {
    update = base_projectile.update,
    
    onFireRequested = function(entity, weapon, context)
        if not base_projectile.checkEnergy(entity, weapon) then
            return false
        end
        
        -- Custom: Spawn gravity well projectile
        local projectile = ProjectileFactory.spawn(...)
        
        -- Add custom gravity well behavior
        projectile.gravityWell = {
            radius = 200,
            strength = 500,
            duration = 5.0
        }
        
        base_projectile.applyCooldown(weapon)
        return true
    end,
    
    draw = function(entity, weapon, context)
        -- Custom: Draw gravity well indicator
        if weapon._pendingGravityIndicator then
            -- Render indicator
        end
    end
}
```

### Migration Strategy

#### Incremental Approach

1. **Week 1**: Build infrastructure
   - Behavior registry
   - Base behaviors
   - Unified weapon system

2. **Week 2**: Migrate simple weapons
   - Laser beam
   - Basic cannon
   - Test alongside old system

3. **Week 3**: Migrate complex weapons
   - Missile launcher (homing)
   - Firework launcher (delayed burst)
   - Plasma thrower (cloud stream)

4. **Week 4**: Remove old systems
   - Delete old weapon systems
   - Clean up legacy code
   - Update documentation

### Alternative: Keep Current System Enhanced

If full refactoring is too much, you could enhance the current system:

#### Option A: Firemode Extensions
```lua
-- Allow weapons to register custom fireMode handlers
WeaponSystem.registerFireMode("gravity_well", customHandler)
```

#### Option B: Callback Hooks
```lua
-- Add hooks to existing systems
weapon.onBeforeFire = function(entity, weapon, context)
    -- Custom pre-fire logic
end

weapon.onAfterFire = function(entity, weapon, context)
    -- Custom post-fire logic
end
```

#### Option C: Behavior Mixins
```lua
-- Attach behavior components to weapons
weapon.behaviors = {
    require("src.weapons.mixins.chain_lightning"),
    require("src.weapons.mixins.shield_penetration")
}
```

## Recommendation

**I recommend the Plugin System approach** because:

1. **Scalability**: Your game seems to need many unique weapons
2. **Maintainability**: Each weapon is self-contained
3. **Flexibility**: Easy to prototype and iterate
4. **Testing**: Can test weapons in isolation
5. **Team-Friendly**: Clear boundaries for adding content

The refactoring can be done incrementally with low risk, and you'll end up with a much more maintainable system.

## Next Steps

If you want to proceed, I can:

1. **Implement the behavior registry and base infrastructure**
2. **Create base behaviors for hitscan/projectile/cloud**
3. **Migrate one weapon as proof of concept**
4. **Show you how to create new weapons with the system**

What do you think? Would you like me to start implementing this, or would you prefer to discuss the approach first?
