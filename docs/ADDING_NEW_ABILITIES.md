# Adding New Abilities - Quick Guide

The ability system now uses a **behavior plugin architecture** that makes adding new abilities super easy, just like the weapon system!

## Quick Start

### Step 1: Create Your Ability Blueprint

Create a file in `src/blueprints/modules/ability_your_ability.lua`:

```lua
local BehaviorRegistry = require("src.abilities.behavior_registry")
local your_ability_behavior = require("src.abilities.behaviors.your_ability")

-- Register your ability behavior (REQUIRED!)
BehaviorRegistry.register("your_ability", your_ability_behavior)

return {
    category = "modules",
    id = "ability_your_ability",
    name = "Your Amazing Ability",
    slot = "ability",
    rarity = "rare",
    description = "Your ability description here.",
    components = {
        module = {
            ability = {
                id = "your_ability",  -- MUST match BehaviorRegistry key
                type = "your_ability",
                displayName = "Your Ability",
                cooldown = 5.0,
                energyCost = 25,
                duration = 3.0,
                -- ... your ability parameters
                hotkeyLabel = "SPACE",
                intentIndex = 1,
            },
        },
    },
    icon = {
        -- Your icon configuration
    },
    item = {
        name = "Your Amazing Ability",
        description = "Description shown in inventory.",
        value = 2500,
        volume = 6,
    },
}
```

### Step 2: Create Your Ability Behavior

Create a file in `src/abilities/behaviors/your_ability.lua`:

#### For Simple Abilities (Use Base Behaviors)

```lua
-- Afterburner-type ability (movement boost)
local base_afterburner = require("src.abilities.behaviors.base_afterburner")

return {
    update = base_afterburner.update,
    activate = base_afterburner.activate,
    deactivate = base_afterburner.deactivate,
}
```

```lua
-- Dash-type ability (instant impulse)
local base_dash = require("src.abilities.behaviors.base_dash")

return {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
}
```

```lua
-- Field-type ability (area effect)
local base_temporal_field = require("src.abilities.behaviors.base_temporal_field")

return {
    update = base_temporal_field.update,
    activate = base_temporal_field.activate,
    deactivate = base_temporal_field.deactivate,
}
```

#### For Custom Abilities

```lua
local AudioManager = require("src.audio.manager")

return {
    -- Called every frame while ability is equipped
    update = function(context, entity, ability, state, dt)
        -- Your per-frame logic here
        -- Update timers, effects, etc.
    end,
    
    -- Called when ability is activated
    activate = function(context, entity, body, ability, state)
        if not (body and not body:isDestroyed()) then
            return false
        end
        
        -- YOUR CUSTOM ACTIVATION LOGIC HERE
        -- Apply effects, spawn entities, modify stats, etc.
        
        -- Example: Apply shield boost
        if entity.shield then
            entity.shield.current = math.min(
                entity.shield.max, 
                entity.shield.current + 50
            )
        end
        
        -- Play sound
        AudioManager.play_sfx("sfx:laser_turret_fire", {
            pitch = 0.9,
            volume = 0.7,
        })
        
        -- Set duration
        state.activeTimer = ability.duration or 0
        
        return true
    end,
    
    -- Called when ability ends
    deactivate = function(context, entity, body, ability, state)
        -- Clean up effects
        -- Restore original values
        -- Remove temporary entities
    end,
}
```

### Step 3: Done!

That's it! Your ability is now fully integrated. The system will:
- ✅ Handle input and energy drain
- ✅ Call your behavior plugin
- ✅ Manage cooldowns and timers
- ✅ Track active state
- ✅ Apply upgrades (in future)

## Base Behaviors Available

### `base_afterburner` - Movement boost abilities

**Good for:** Speed boosts, thrust enhancements, afterburners

**Features:**
- Stat multipliers (thrust, speed, acceleration)
- Engine trail effects
- Camera zoom effects
- Hold-to-activate support
- Smooth stat restoration

**Example:** Aurora Afterburner

**Parameters:**
- `thrustMultiplier` - Multiply thrust force
- `maxSpeedMultiplier` - Multiply max speed
- `accelerationMultiplier` - Multiply acceleration
- `trailColors` - Engine trail color gradient
- `zoomTarget` - Target camera zoom level
- `energyPerSecond` - Energy drain per second (hold-to-activate)

### `base_dash` - Instant impulse abilities

**Good for:** Dashes, dodges, quick bursts

**Features:**
- Instant velocity/impulse
- Temporary physics tweaks
- Engine burst effects
- Trail color override
- Auto-restore physics on end

**Example:** Vector Surge Dash

**Parameters:**
- `impulse` - Impulse force magnitude
- `speed` - Override velocity (optional)
- `dashDamping` - Linear damping during dash
- `useMass` - Scale impulse by mass
- `duration` - Dash duration

### `base_temporal_field` - Area effect abilities

**Good for:** Fields, bubbles, zones

**Features:**
- Position tracking
- Area-of-effect logic
- Projectile modification
- Cooldown acceleration
- Duration management

**Example:** Temporal Lag Field

**Parameters:**
- `radius` - Field radius
- `projectileSlowFactor` - Slow projectiles in field
- `cooldownReductionRate` - Accelerate cooldowns
- `duration` - Field duration

## Behavior Interface Reference

Your behavior plugin is a table with these optional functions:

```lua
{
    -- Called every frame for active abilities
    update = function(context, entity, ability, state, dt)
        -- context: System context (world, state, etc.)
        -- entity: The ship/entity with the ability
        -- ability: The ability configuration
        -- state: The ability state (cooldown, timers, etc.)
        -- dt: Delta time
    end,
    
    -- Called when ability is activated
    activate = function(context, entity, body, ability, state)
        -- Return true if successfully activated
        return true
    end,
    
    -- Called when ability ends or is deactivated
    deactivate = function(context, entity, body, ability, state)
        -- Clean up effects, restore values
    end,
    
    -- Optional: Custom rendering
    draw = function(context, entity, ability, state)
        -- Use love.graphics to draw custom effects
    end,
}
```

## Context Object

The `context` object passed to behaviors contains:

- `world` - The ECS world (for spawning entities)
- `physicsWorld` - The Box2D physics world
- `state` - The game state
- `intentHolder` - Input state
- `damageEntity` - Function to damage entities
- `camera` - The game camera
- `engineTrail` - The entity's engine trail effect
- `uiInput` - UI input capture state

## Helper Functions

### From `ability_common`:

```lua
ability_common.drain_energy(entity, cost) -> boolean
ability_common.is_ability_key_down(context, entity, ability) -> boolean
ability_common.resolve_context_state(context) -> state
```

### From base behaviors:

```lua
-- base_afterburner
base_afterburner.activate(context, entity, body, ability, state) -> boolean
base_afterburner.deactivate(context, entity, body, ability, state)
base_afterburner.update(context, entity, ability, state, dt)
base_afterburner.updateZoom(context, ability, state, dt)

-- base_dash
base_dash.activate(context, entity, body, ability, state) -> boolean
base_dash.deactivate(context, entity, body, ability, state)
base_dash.update(context, entity, ability, state, dt)

-- base_temporal_field
base_temporal_field.activate(context, entity, body, ability, state) -> boolean
base_temporal_field.deactivate(context, entity, body, ability, state)
base_temporal_field.update(context, entity, ability, state, dt)
```

## Common Patterns

### Pattern 1: Simple Ability

Just use base behavior directly:

```lua
local base_dash = require("src.abilities.behaviors.base_dash")

return {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
}
```

### Pattern 2: Shield Boost Ability

```lua
local AudioManager = require("src.audio.manager")

return {
    update = function(context, entity, ability, state, dt)
        -- Nothing needed per-frame
    end,
    
    activate = function(context, entity, body, ability, state)
        if not entity.shield then
            return false
        end
        
        -- Restore shield
        local restoreAmount = ability.restoreAmount or 100
        entity.shield.current = math.min(
            entity.shield.max,
            entity.shield.current + restoreAmount
        )
        
        AudioManager.play_sfx("sfx:shield_recharge", {
            pitch = 1.0,
            volume = 0.8,
        })
        
        return true
    end,
    
    deactivate = function(context, entity, body, ability, state)
        -- Nothing needed
    end,
}
```

### Pattern 3: Teleport Ability

```lua
local AudioManager = require("src.audio.manager")

return {
    update = function(context, entity, ability, state, dt)
        -- Nothing needed
    end,
    
    activate = function(context, entity, body, ability, state)
        if not (body and not body:isDestroyed()) then
            return false
        end
        
        -- Get current position and angle
        local x, y = body:getPosition()
        local angle = body:getAngle() - math.pi * 0.5
        
        -- Teleport forward
        local distance = ability.teleportDistance or 200
        local newX = x + math.cos(angle) * distance
        local newY = y + math.sin(angle) * distance
        
        body:setPosition(newX, newY)
        
        -- Visual/audio feedback
        AudioManager.play_sfx("sfx:teleport", {
            pitch = 1.1,
            volume = 0.9,
        })
        
        return true
    end,
    
    deactivate = function(context, entity, body, ability, state)
        -- Nothing needed
    end,
}
```

### Pattern 4: Damage Boost Ability

```lua
local AudioManager = require("src.audio.manager")

return {
    update = function(context, entity, ability, state, dt)
        -- Track duration
        if state._damageBoostActive and state.activeTimer > 0 then
            -- Could add visual effects here
        end
    end,
    
    activate = function(context, entity, body, ability, state)
        if state._damageBoostActive then
            return false
        end
        
        -- Store original damage multiplier
        local originalMult = entity.damageMultiplier or 1.0
        state._originalDamageMult = originalMult
        
        -- Apply boost
        local boostMult = ability.damageMultiplier or 2.0
        entity.damageMultiplier = originalMult * boostMult
        
        state._damageBoostActive = true
        state.activeTimer = ability.duration or 5.0
        
        AudioManager.play_sfx("sfx:damage_boost", {
            pitch = 0.95,
            volume = 0.8,
        })
        
        return true
    end,
    
    deactivate = function(context, entity, body, ability, state)
        if not state._damageBoostActive then
            return
        end
        
        -- Restore original multiplier
        entity.damageMultiplier = state._originalDamageMult or 1.0
        
        state._damageBoostActive = nil
        state._originalDamageMult = nil
    end,
}
```

## Activation Modes

### One-Shot (Triggered)

Default behavior. Ability activates once when pressed, cooldown starts:

```lua
ability = {
    cooldown = 5.0,
    energyCost = 25,
    -- ... other params
}
```

### Hold-to-Activate (Continuous)

Ability stays active while key is held, drains energy continuously:

```lua
ability = {
    continuous = true,  -- or holdToActivate = true
    energyPerSecond = 30,
    duration = 0.3,  -- Re-applied each frame
    -- ... other params
}
```

## Ability State

Each ability gets a state table that persists:

- `state.cooldown` - Current cooldown remaining
- `state.cooldownDuration` - Full cooldown duration
- `state.activeTimer` - Time remaining while active
- `state.wasDown` - Previous frame key state
- `state.holdActive` - True if hold-to-activate is active
- Custom fields: Store any custom data in `state._yourField`

## Backward Compatibility

Abilities without a registered behavior automatically fallback to their `type`:
- `type = "afterburner"` → uses `base_afterburner`
- `type = "dash"` → uses `base_dash`
- `type = "temporal_field"` → uses `base_temporal_field`

This means **all existing abilities work without changes**!

## Migration Checklist

Migrating an existing ability to use a behavior plugin:

1. ✅ Create behavior file in `src/abilities/behaviors/`
2. ✅ Import and register in ability blueprint
3. ✅ Set `id` in ability component (used for registry lookup)
4. ✅ Test in-game
5. ✅ Done!

## Future: Upgrades

The plugin system is designed to support upgrades:

```lua
-- In your ability blueprint
ability = {
    id = "your_ability",
    -- Base parameters
    damage = 50,
    
    -- Upgrades (future)
    upgrades = {
        {
            level = 1,
            damage = 75,
            cooldown = -0.5,  -- Reduce cooldown
        },
        {
            level = 2,
            damage = 100,
            radius = 50,  -- Add new parameter
        },
    },
}
```

Your behavior plugin will automatically receive the upgraded parameters!

## FAQ

**Q: Do I need to modify core systems?**  
A: No! Just create your behavior plugin and register it.

**Q: Can I mix base behaviors?**  
A: Yes! Call functions from any base behavior in your custom behavior.

**Q: What if I want a completely unique ability?**  
A: Write a fully custom behavior with `update`, `activate`, and `deactivate` functions.

**Q: How do I debug my ability?**  
A: Add print statements in your behavior functions. They're isolated and easy to debug.

**Q: Can I add custom rendering?**  
A: Yes! Add a `draw` function to your behavior plugin.

**Q: How do I make hold-to-activate abilities?**  
A: Set `continuous = true` or `holdToActivate = true` and use `energyPerSecond` instead of `energyCost`.

## Support

See existing ability behaviors in `src/abilities/behaviors/` for examples.

Check the weapon system docs for similar patterns - abilities work the same way!
