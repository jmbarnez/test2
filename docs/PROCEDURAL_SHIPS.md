# Procedural Ship Generation System

This system generates random ship designs on-the-fly to populate sectors with varied enemy ships.

## Overview

The procedural ship generator creates unique ships with:
- **Random hull shapes** (triangle, pentagon, diamond, arrow, wedge, spearhead, boomerang, manta, hammerhead, kite)
- **Varied visual appearance** (6 different color palettes)
- **Scaled stats** based on size class (small, medium, large)
- **Difficulty scaling** (easy, normal, hard, extreme)
- **Pulse Laser Turret** weapons

## Components

### 1. `src/util/procedural_ship_generator.lua`
Core generator that creates ship blueprints programmatically.

**API:**
```lua
local ProceduralShipGenerator = require("src.util.procedural_ship_generator")

-- Generate a single ship
local ship = ProceduralShipGenerator.generate({
    size_class = "medium",  -- "small", "medium", "large"
    difficulty = "normal",  -- "easy", "normal", "hard", "extreme"
    seed = 12345,          -- Optional: for reproducibility
    use_seed = true,       -- Optional: use provided seed
})

-- Generate multiple ships
local ships = ProceduralShipGenerator.generate_batch(10, {
    size_class = "small",
    difficulty = "hard",
})
```

### 2. `src/spawners/procedural_ships.lua`
Spawner system that generates and places procedural ships in sectors.

### 3. Sector Configuration
Add procedural ship config to sector blueprints:

```lua
proceduralShips = {
    count = { min = 8, max = 15 },
    difficulty = "normal",
    spawn_safe_radius = 900,
    separation_radius = 700,
    wander_radius = 1500,
    size_distribution = {
        small = 0.5,   -- 50% small ships
        medium = 0.35, -- 35% medium ships
        large = 0.15,  -- 15% large ships
    },
}
```

## Ship Size Classes

### Small Ships
- **Mass:** 2-4
- **Speed:** 140-200
- **Health:** 60-100
- **Hull:** 80-120
- **Engagement Range:** 500-800

### Medium Ships
- **Mass:** 4-7
- **Speed:** 100-150
- **Health:** 100-160
- **Hull:** 120-200
- **Engagement Range:** 600-900

### Large Ships
- **Mass:** 7-11
- **Speed:** 70-110
- **Health:** 160-260
- **Hull:** 200-320
- **Engagement Range:** 700-1000

## Difficulty Scaling

### Easy
- **Stat Multiplier:** 0.8x
- **Health Multiplier:** 0.7x

### Normal
- **Stat Multiplier:** 1.0x
- **Health Multiplier:** 1.0x

### Hard
- **Stat Multiplier:** 1.3x
- **Health Multiplier:** 1.4x

### Extreme
- **Stat Multiplier:** 1.6x
- **Health Multiplier:** 2.0x

## Visual Variety

The system includes 6 color palettes:
1. **Aggressive Red** - Red and orange tones
2. **Cool Blue** - Blue and cyan tones
3. **Toxic Green** - Green and lime tones
4. **Purple/Magenta** - Purple and pink tones
5. **Orange/Amber** - Orange and yellow tones
6. **Dark Gray/Steel** - Gray and metallic tones

## Hull Templates

Ship shapes come from these base templates (with subtle per-ship parameter tweaks):
- **Triangle** - Sleek interceptor delta
- **Pentagon** - Balanced multi-role frame
- **Diamond** - Slimline recon hull
- **Arrow** - Aggressive forward-swept wings
- **Wedge** - Compact heavy fighter
- **Spearhead** - Long nose jammer / breacher
- **Boomerang** - Swept-wing harrier
- **Manta** - Broad-wing gunship
- **Hammerhead** - Heavy brawler with wide prow
- **Kite** - Balanced cruiser silhouette

Each template is procedurally scaled and layered with:
- **Hull layer** (outer shell)
- **Core layer** (inner polygon, 60-80% of hull size)
- **Engine layer** (rear thrusters)

## AI Behavior

All procedural ships use the "hunter" AI behavior with:
- Target player by default
- Engagement range based on size class
- Fire arc constraints
- Preferred combat distance
- Wander behavior when no target

## Weapons

Currently, all procedural ships are equipped with:
- **Pulse Laser Turret** (`laser_turret`)
- Mounted at the front of the ship
- Random inset and forward offset for variety

## Loot Drops

Procedural ships drop credits and XP based on size:
- **Small:** 50 credits, 15 XP
- **Medium:** 100 credits, 30 XP
- **Large:** 200 credits, 60 XP

## Usage Examples

### Spawn Only Small Ships
```lua
proceduralShips = {
    count = 20,
    difficulty = "easy",
    size_distribution = {
        small = 1.0,
        medium = 0,
        large = 0,
    },
}
```

### Boss Rush (All Large Ships)
```lua
proceduralShips = {
    count = { min = 3, max = 5 },
    difficulty = "extreme",
    size_distribution = {
        small = 0,
        medium = 0,
        large = 1.0,
    },
}
```

### Mixed Fleet
```lua
proceduralShips = {
    count = { min = 15, max = 25 },
    difficulty = "hard",
    size_distribution = {
        small = 0.6,
        medium = 0.3,
        large = 0.1,
    },
}
```

## Future Enhancements

Potential improvements:
1. **More weapon variety** - Add different weapon types (missiles, beams, etc.)
2. **Shield systems** - Give some procedural ships shields
3. **Special abilities** - Add random abilities to ships
4. **Faction colors** - Different palettes for different factions
5. **More hull templates** - Expand visual variety
6. **Symmetry variations** - Some ships could be asymmetric
7. **Module slots** - Procedural ships could have random modules
8. **Name generation** - Generate unique names for ships

## Integration

The system is automatically integrated when a sector blueprint includes a `proceduralShips` configuration. The spawner runs once at sector load and places all ships according to the configuration.

To disable procedural ship spawning in a sector, simply omit the `proceduralShips` field or set `count` to 0.
