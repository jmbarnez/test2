# Ability Plugin System Architecture

## Overview

The ability system uses a behavior plugin architecture similar to the weapon system, making it easy to add new abilities without modifying core systems.

## Architecture

```
src/abilities/
├── behavior_registry.lua       # Central registry for ability behaviors
└── behaviors/                  # Behavior plugins
    ├── base_afterburner.lua    # Base behavior for movement boosts
    ├── base_dash.lua           # Base behavior for instant impulses
    ├── base_temporal_field.lua # Base behavior for area effects
    ├── afterburner.lua         # Specific afterburner implementation
    ├── dash.lua                # Specific dash implementation
    └── temporal_field.lua      # Specific temporal field implementation

src/systems/
└── ability_modules.lua         # Main ability system (uses registry)

src/util/
└── ability_common.lua          # Shared utilities

src/blueprints/modules/
├── ability_afterburner.lua     # Blueprint + behavior registration
├── ability_dash.lua            # Blueprint + behavior registration
└── ability_temporal_field.lua  # Blueprint + behavior registration
```

## Key Components

### 1. Behavior Registry

Manages ability behavior plugins, similar to weapon behavior registry:

```lua
local BehaviorRegistry = require("src.abilities.behavior_registry")

-- Register a behavior
BehaviorRegistry.register("ability_key", behavior_plugin)

-- Register a fallback for an ability type
BehaviorRegistry.registerFallback("afterburner", base_afterburner)

-- Resolve a behavior (tries ID, then type, then fallback)
local behavior = BehaviorRegistry.resolve(ability)
```

### 2. Behavior Plugin Interface

Each behavior plugin is a table with these functions:

```lua
{
    update = function(context, entity, ability, state, dt)
        -- Called every frame
    end,
    
    activate = function(context, entity, body, ability, state)
        -- Called when ability activates
        -- Return true if successful
    end,
    
    deactivate = function(context, entity, body, ability, state)
        -- Called when ability ends
    end,
    
    draw = function(context, entity, ability, state)
        -- Optional: custom rendering
    end,
}
```

### 3. Base Behaviors

Base behaviors provide reusable implementations:

- **base_afterburner**: Movement stat boosts, camera zoom, trail effects
- **base_dash**: Instant impulse, temporary physics tweaks
- **base_temporal_field**: Area effects, projectile modification

### 4. Ability System Integration

The `ability_modules` system:
1. Resolves behavior plugin via registry
2. Calls `behavior.update()` each frame
3. Calls `behavior.activate()` when triggered
4. Calls `behavior.deactivate()` when ending
5. Falls back to legacy handlers if no behavior found

## Data Flow

```
Player Input
    ↓
ability_modules system
    ↓
BehaviorRegistry.resolve(ability)
    ↓
behavior.activate() / behavior.update() / behavior.deactivate()
    ↓
Modify entity stats / Spawn effects / Apply forces
```

## Ability State

Each ability has a state table managed by the system:

```lua
state = {
    cooldown = 0,           -- Current cooldown remaining
    cooldownDuration = 5.0, -- Full cooldown duration
    activeTimer = 0,        -- Time remaining while active
    wasDown = false,        -- Previous frame key state
    holdActive = false,     -- True if hold-to-activate is active
    
    -- Custom fields (prefixed with _)
    _damageBoostActive = false,
    _originalDamageMult = 1.0,
}
```

## Context Object

Behaviors receive a context object with:

```lua
context = {
    world = ...,           -- ECS world
    physicsWorld = ...,    -- Box2D physics world
    state = ...,           -- Game state
    intentHolder = ...,    -- Input state
    damageEntity = ...,    -- Damage function
    camera = ...,          -- Game camera
    engineTrail = ...,     -- Entity's engine trail
    uiInput = ...,         -- UI input capture
}
```

## Activation Modes

### One-Shot (Triggered)

Activates once when pressed, then goes on cooldown:

```lua
ability = {
    cooldown = 5.0,
    energyCost = 25,
}
```

System behavior:
1. Player presses key
2. Check cooldown (skip if > 0)
3. Drain energy cost
4. Call `behavior.activate()`
5. Start cooldown timer

### Hold-to-Activate (Continuous)

Stays active while key is held, drains energy continuously:

```lua
ability = {
    continuous = true,
    energyPerSecond = 30,
    duration = 0.3,
}
```

System behavior:
1. Player holds key
2. Drain `energyPerSecond * dt` each frame
3. If first frame: call `behavior.activate()`
4. Keep extending `activeTimer` while held
5. On release: call `behavior.deactivate()`

## Energy Management

Energy is drained automatically by the system:

```lua
-- One-shot
ability.energyCost = 25  -- Drained once on activation

-- Continuous
ability.energyPerSecond = 30  -- Drained each frame (× dt)
```

Uses `ability_common.drain_energy(entity, cost)` which:
- Checks if entity has enough energy
- Deducts energy.current
- Updates energy.percent
- Resets recharge timer
- Returns true if successful

## Cooldown Management

Cooldowns are managed automatically:

```lua
-- Set in ability config
ability.cooldown = 5.0

-- Tracked in state
state.cooldown = 5.0      -- Counts down each frame
state.cooldownDuration = 5.0  -- Full duration (for UI)
```

Cooldowns can be accelerated by temporal field:

```lua
if entity._temporalField and entity._temporalField.active then
    local reduction = entity._temporalField.cooldownReduction or 0.15
    state.cooldown = state.cooldown - reduction * dt
end
```

## Visual Effects

Abilities can modify visual effects via context:

```lua
local ctxState = ability_common.resolve_context_state(context)
local engineTrail = ctxState and ctxState.engineTrail

if engineTrail then
    -- Apply color override
    engineTrail:applyColorOverride(colors, drawColor)
    
    -- Emit burst
    engineTrail:emitBurst(particleCount, strength)
    
    -- Force activation
    engineTrail:forceActivate(duration, strength)
    
    -- Clear override
    engineTrail:clearColorOverride()
end
```

## Camera Effects

Abilities can control camera zoom:

```lua
-- In activate()
state._afterburnerZoomData = {
    target = 0.35,      -- Target zoom level
    speed = 8,          -- Lerp speed
    epsilon = 1e-3,     -- When to stop
    minZoom = 0.3,      -- Clamp min
    maxZoom = 2.5,      -- Clamp max
    clearOnReach = true,  -- Clear when done
}

-- In update()
base_afterburner.updateZoom(context, ability, state, dt)
```

## Physics Modification

Abilities can modify physics properties:

```lua
-- Save original
state._prevDamping = body:getLinearDamping()
state._prevBullet = body:isBullet()

-- Modify
body:setLinearDamping(0.2)
body:setBullet(true)

-- Apply forces
body:applyLinearImpulse(dirX * impulse, dirY * impulse)
body:setLinearVelocity(dirX * speed, dirY * speed)

-- Restore in deactivate()
body:setLinearDamping(state._prevDamping)
body:setBullet(state._prevBullet)
```

## Stat Modification

Abilities can modify entity stats:

```lua
-- Save original
state._originalStats = {
    maxSpeed = entity.stats.max_speed,
    thrust = entity.stats.main_thrust,
}

-- Modify
entity.stats.max_speed = entity.stats.max_speed * 1.5
entity.stats.main_thrust = entity.stats.main_thrust * 1.6

-- Restore in deactivate()
entity.stats.max_speed = state._originalStats.maxSpeed
entity.stats.main_thrust = state._originalStats.thrust
```

## Area Effects

Abilities can create area-of-effect fields:

```lua
-- In activate()
entity._temporalField = {
    active = true,
    owner = entity,
    radius = 250,
    slowFactor = 0.35,
    cooldownReduction = 0.18,
    x = x,
    y = y,
}

-- In update()
if entity._temporalField and entity._temporalField.active then
    local fx, fy = body:getPosition()
    entity._temporalField.x = fx
    entity._temporalField.y = fy
end

-- In deactivate()
entity._temporalField.active = false
```

Other systems can query these fields to apply effects.

## Backward Compatibility

The system maintains backward compatibility:

1. Behaviors can be registered in blueprints (new way)
2. Behaviors registered as fallbacks for types (compatibility)
3. Legacy `ability_handlers` still work (deprecated)

This allows incremental migration of abilities.

## Best Practices

### 1. Use Base Behaviors When Possible

```lua
local base_dash = require("src.abilities.behaviors.base_dash")

return {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
}
```

### 2. Store State with `_` Prefix

```lua
state._myCustomField = true  -- Good
state.myCustomField = true   -- Avoid (might conflict)
```

### 3. Check Body Validity

```lua
if not (body and not body:isDestroyed()) then
    return false
end
```

### 4. Always Restore in Deactivate

```lua
activate = function(context, entity, body, ability, state)
    state._original = entity.someValue
    entity.someValue = newValue
end

deactivate = function(context, entity, body, ability, state)
    entity.someValue = state._original
    state._original = nil
end
```

### 5. Return Success from Activate

```lua
activate = function(context, entity, body, ability, state)
    if not canActivate then
        return false  -- System won't start cooldown
    end
    
    -- Do stuff
    
    return true  -- System starts cooldown
end
```

## Adding a New Ability Type

To add a new base ability type:

1. Create `src/abilities/behaviors/base_your_type.lua`
2. Implement `activate`, `deactivate`, `update`
3. Register as fallback: `BehaviorRegistry.registerFallback("your_type", base_your_type)`
4. Create specific implementations that use the base
5. Document in `ADDING_NEW_ABILITIES.md`

## Debugging

Enable debug output:

```lua
-- In behavior plugin
activate = function(context, entity, body, ability, state)
    print("[YourAbility] Activating with params:", ability.someParam)
    -- ...
end
```

Check state:

```lua
-- In console
player._abilityState
player.abilityModules
```

List registered behaviors:

```lua
local BehaviorRegistry = require("src.abilities.behavior_registry")
local behaviors = BehaviorRegistry.list()
for _, key in ipairs(behaviors) do
    print(key)
end
```

## Performance Considerations

- Behaviors are called every frame (update) or on activation
- Keep update() fast - avoid heavy calculations
- Cache calculations in state when possible
- Use flags to skip unnecessary work

## Future Enhancements

### Upgrade System

```lua
ability = {
    level = 2,
    baseParams = { ... },
    upgrades = {
        [1] = { cooldown = -0.5 },
        [2] = { damage = 50 },
    },
}
```

### Combo System

```lua
behavior = {
    onCombo = function(context, entity, ability, state, otherAbility)
        -- Apply bonus when used with other ability
    end,
}
```

### Passive Effects

```lua
ability = {
    passive = true,
}

behavior = {
    update = function(context, entity, ability, state, dt)
        -- Always runs, even when not activated
    end,
}
```

## See Also

- `docs/ADDING_NEW_ABILITIES.md` - Quick guide for adding abilities
- `docs/WEAPON_SYSTEM_REFACTORING.md` - Similar weapon plugin system
- `docs/ADDING_NEW_WEAPONS.md` - Weapon plugin guide
