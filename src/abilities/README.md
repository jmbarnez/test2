# Ability System - Plugin Architecture

This directory contains the ability behavior plugin system.

## Structure

```
src/abilities/
├── behavior_registry.lua       # Central registry for ability behaviors
├── init.lua                    # Initialization and exports
└── behaviors/                  # Behavior plugin implementations
    ├── base_afterburner.lua    # Base: movement boost abilities
    ├── base_dash.lua           # Base: instant impulse abilities
    ├── base_temporal_field.lua # Base: area effect abilities
    ├── afterburner.lua         # Afterburner implementation
    ├── dash.lua                # Dash implementation
    ├── temporal_field.lua      # Temporal field implementation
    └── shield_burst.lua        # Example: shield burst ability
```

## Quick Start

### Creating a New Ability

1. **Create behavior file** in `behaviors/your_ability.lua`:

```lua
return {
    update = function(context, entity, ability, state, dt)
        -- Per-frame logic
    end,
    
    activate = function(context, entity, body, ability, state)
        -- Activation logic
        return true
    end,
    
    deactivate = function(context, entity, body, ability, state)
        -- Cleanup logic
    end,
}
```

2. **Create blueprint** in `src/blueprints/modules/ability_your_ability.lua`:

```lua
local BehaviorRegistry = require("src.abilities.behavior_registry")
local your_ability = require("src.abilities.behaviors.your_ability")

BehaviorRegistry.register("your_ability", your_ability)

return {
    category = "modules",
    id = "ability_your_ability",
    components = {
        module = {
            ability = {
                id = "your_ability",  -- Must match registry key
                -- ... config
            },
        },
    },
}
```

3. **Done!** The system automatically uses your behavior.

## Base Behaviors

Use these as building blocks:

### `base_afterburner`
Movement boost abilities with stat multipliers, camera zoom, and trail effects.

**Use for:** Speed boosts, afterburners, thrust enhancements

**Example:**
```lua
local base_afterburner = require("src.abilities.behaviors.base_afterburner")

return {
    update = base_afterburner.update,
    activate = base_afterburner.activate,
    deactivate = base_afterburner.deactivate,
}
```

### `base_dash`
Instant impulse abilities with physics tweaks and engine effects.

**Use for:** Dashes, dodges, quick bursts

**Example:**
```lua
local base_dash = require("src.abilities.behaviors.base_dash")

return {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
}
```

### `base_temporal_field`
Area effect abilities with field tracking and management.

**Use for:** Fields, bubbles, zones, auras

**Example:**
```lua
local base_temporal_field = require("src.abilities.behaviors.base_temporal_field")

return {
    update = base_temporal_field.update,
    activate = base_temporal_field.activate,
    deactivate = base_temporal_field.deactivate,
}
```

## Behavior Interface

Each behavior is a table with these functions:

```lua
{
    -- Called every frame (required)
    update = function(context, entity, ability, state, dt)
        -- Update logic, animations, effects
    end,
    
    -- Called when ability activates (required)
    activate = function(context, entity, body, ability, state)
        -- Activation logic
        -- Return true if successful, false otherwise
        return true
    end,
    
    -- Called when ability ends (required)
    deactivate = function(context, entity, body, ability, state)
        -- Cleanup, restore values
    end,
    
    -- Optional: custom rendering
    draw = function(context, entity, ability, state)
        -- Use love.graphics to draw effects
    end,
}
```

## Context Object

Behaviors receive a context object with:

```lua
context = {
    world = ...,           -- ECS world (for spawning entities)
    physicsWorld = ...,    -- Box2D physics world
    state = ...,           -- Game state
    intentHolder = ...,    -- Input state
    damageEntity = ...,    -- Function to damage entities
    camera = ...,          -- Game camera
    engineTrail = ...,     -- Entity's engine trail effect
    uiInput = ...,         -- UI input capture state
}
```

## State Management

Each ability has a persistent state table:

```lua
state = {
    cooldown = 0,           -- Current cooldown
    cooldownDuration = 5.0, -- Full cooldown duration
    activeTimer = 0,        -- Time remaining active
    wasDown = false,        -- Previous input state
    holdActive = false,     -- Hold-to-activate state
    
    -- Custom fields (prefix with _)
    _yourCustomData = ...,
}
```

## Energy Management

Energy is handled automatically:

```lua
-- One-shot (drained on activation)
ability.energyCost = 25

-- Continuous (drained per second while held)
ability.continuous = true
ability.energyPerSecond = 30
```

Use helper:
```lua
local ability_common = require("src.util.ability_common")
if ability_common.drain_energy(entity, cost) then
    -- Has energy
end
```

## Common Patterns

### Pattern 1: Use Base Behavior
```lua
local base_dash = require("src.abilities.behaviors.base_dash")

return {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
}
```

### Pattern 2: Customize Base Behavior
```lua
local base_dash = require("src.abilities.behaviors.base_dash")

return {
    update = base_dash.update,
    
    activate = function(context, entity, body, ability, state)
        -- Call base
        base_dash.activate(context, entity, body, ability, state)
        
        -- Add custom logic
        entity.invulnerable = true
        state._wasInvulnerable = true
        
        return true
    end,
    
    deactivate = function(context, entity, body, ability, state)
        base_dash.deactivate(context, entity, body, ability, state)
        
        if state._wasInvulnerable then
            entity.invulnerable = false
            state._wasInvulnerable = nil
        end
    end,
}
```

### Pattern 3: Completely Custom
```lua
local AudioManager = require("src.audio.manager")

return {
    update = function(context, entity, ability, state, dt)
        -- Custom per-frame logic
    end,
    
    activate = function(context, entity, body, ability, state)
        -- Completely custom activation
        AudioManager.play_sfx("sfx:custom")
        return true
    end,
    
    deactivate = function(context, entity, body, ability, state)
        -- Custom cleanup
    end,
}
```

## Examples

See `behaviors/shield_burst.lua` for a complete example of a custom ability with:
- Damage calculation
- Shield restoration
- Knockback effects
- Custom rendering
- Area of effect logic

## Documentation

- **Quick Guide**: `docs/ADDING_NEW_ABILITIES.md`
- **Architecture**: `docs/ABILITY_PLUGIN_SYSTEM.md`
- **Comparison**: `docs/ABILITY_PLUGIN_SUMMARY.md`
- **Complete Info**: `docs/ABILITY_PLUGIN_COMPLETE.md`

## Tips

- Store custom state with `_` prefix: `state._myData`
- Always check body validity: `if body and not body:isDestroyed()`
- Return `true` from `activate()` on success
- Restore values in `deactivate()`
- Use base behaviors when possible
- Add custom `draw()` for visual effects

## Related Systems

- **Weapon System**: Uses identical plugin architecture
- **Module System**: Manages ability installation
- **Energy System**: Provides energy for abilities
- **Input System**: Triggers ability activation

## Need Help?

Check existing behaviors for examples:
- Simple: `dash.lua`, `afterburner.lua`
- Complex: `base_afterburner.lua`, `shield_burst.lua`

Or read the comprehensive documentation in `docs/`.
