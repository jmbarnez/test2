# Entity Pooling Implementation Guide

## Overview

Entity pooling is a performance optimization technique that pre-allocates and reuses entity objects instead of creating new ones. This reduces garbage collection pressure and allocation overhead, particularly for frequently created/destroyed entities like projectiles and particles.

## Current Situation

**High-frequency entities that would benefit from pooling:**
- **Projectiles**: Created/destroyed dozens to hundreds of times per second in combat
- **Particles/Effects**: Engine trails, explosions, damage numbers
- **Temporary UI elements**: Floating text, indicators

**Current cost per projectile:**
- Physics body creation
- Physics fixture creation
- Multiple table allocations (position, velocity, drawable, projectile component)
- Nested blueprint deep-copies

## Implementation Strategy

### Phase 1: Projectile Pool (Highest Impact)

Create `src/util/projectile_pool.lua`:

```lua
local ProjectilePool = {}

function ProjectilePool.create(initialSize)
    local pool = {
        available = {},
        active = {},
        stats = { created = 0, reused = 0 }
    }
    
    -- Pre-allocate initial entities
    for i = 1, initialSize do
        pool.available[i] = ProjectilePool._createRaw()
    end
    
    return pool
end

function ProjectilePool.acquire(pool, tinyWorld, physicsWorld, ...)
    local entity
    
    if #pool.available > 0 then
        entity = table.remove(pool.available)
        pool.stats.reused = pool.stats.reused + 1
    else
        entity = ProjectilePool._createRaw()
        pool.stats.created = pool.stats.created + 1
    end
    
    -- Reset and configure entity
    ProjectilePool._reset(entity, ...)
    
    pool.active[entity] = true
    tinyWorld:add(entity)
    
    return entity
end

function ProjectilePool.release(pool, entity, tinyWorld)
    if not pool.active[entity] then
        return
    end
    
    pool.active[entity] = nil
    
    -- Clean up physics
    if entity.body and not entity.body:isDestroyed() then
        entity.body:destroy()
    end
    
    -- Clear references but keep table structure
    ProjectilePool._clear(entity)
    
    pool.available[#pool.available + 1] = entity
end

return ProjectilePool
```

### Phase 2: Integration Points

**Modify `src/entities/projectile_factory.lua`:**
```lua
-- At top of file
local projectile_pool = ProjectilePool.create(200) -- Pre-allocate 200

function ProjectileFactory.spawn(...)
    -- Use pool instead of creating new entity
    return ProjectilePool.acquire(projectile_pool, ...)
end
```

**Modify `src/systems/destruction.lua`:**
```lua
-- Before removing entity, check if it's poolable
if entity.projectile and projectile_pool then
    ProjectilePool.release(projectile_pool, entity, self.world)
    return -- Skip normal destruction
end
```

### Phase 3: Monitoring & Tuning

Add debug overlay to show pool statistics:
- Pool size
- Active entities
- Reuse rate
- Allocation events

Tune pool sizes based on gameplay patterns:
- Combat-heavy: larger projectile pool
- Exploration: smaller pool, more particles

## Benefits

### Performance Impact (Estimated)

**Before pooling:**
- ~15-25ms GC spikes during heavy combat (400+ projectiles/sec)
- Memory allocation: ~2-3KB per projectile × allocation rate
- GC frequency: Every 2-3 seconds in combat

**After pooling:**
- ~5-8ms GC spikes (60-70% reduction)
- Memory allocation: One-time pool allocation
- GC frequency: Every 10-15 seconds in combat

### Memory Benefits

- Reduced heap fragmentation
- Predictable memory footprint
- Better cache locality (reusing warm objects)

## Considerations

### Tradeoffs

**Pros:**
- Major GC pressure reduction
- Consistent frame times
- Scales better with entity count

**Cons:**
- Additional complexity
- Need to carefully reset entity state
- Slightly more memory usage (pre-allocated pool)
- Debugging is harder (entities reused)

### Risks to Manage

1. **Incomplete state reset**: Entities must be fully cleared between uses
2. **Reference leaks**: External references to pooled entities can cause bugs
3. **Pool size tuning**: Too small = frequent allocations, too large = wasted memory

## When to Implement

**Implement pooling when:**
- ✅ Profiling shows GC as a bottleneck
- ✅ Entity creation/destruction rate > 50/second
- ✅ Frame time variance is problematic
- ✅ Team has capacity for the complexity

**Skip pooling if:**
- ❌ Performance is already acceptable
- ❌ Entity creation is infrequent
- ❌ Code complexity outweighs benefits
- ❌ Development time is limited

## Current Status

**Status:** Documented opportunity, not yet implemented

**Next Steps:**
1. Profile actual GC impact in typical gameplay
2. Measure projectile creation/destruction rates
3. If justified, implement Phase 1 (projectile pool)
4. Measure impact and iterate

**Files Ready for Pooling:**
- `src/entities/projectile_factory.lua` (marked with comment)
- `src/systems/destruction.lua` (ready for pool integration)

## References

- Object pooling pattern: https://gameprogrammingpatterns.com/object-pool.html
- Lua GC optimization: http://lua-users.org/wiki/OptimisationTips
- LÖVE performance guide: https://love2d.org/wiki/PO2_Syndrome
