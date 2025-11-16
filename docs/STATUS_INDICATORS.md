# Status Indicators System

The Status Indicators system provides visual warnings for critical player states, displayed below the Status Panel in the top-left corner of the HUD.

## Overview

Status indicators automatically detect and display warnings when the player's vital resources fall below configurable thresholds. Indicators are prioritized and styled to grab attention for critical conditions.

## Location

- **Position**: Below the Status Panel (top-left corner)
- **Layout**: Vertical stack of indicator badges
- **Styling**: Matches HUD theme with color-coded warnings

## Indicators

### Critical Health
- **Threshold**: 15% hull or below
- **Icon**: ⚠
- **Color**: Red (#FF2626)
- **Behavior**: Flashing animation
- **Priority**: 1 (highest)
- **Label**: "CRITICAL"

### Low Health
- **Threshold**: 35% hull or below
- **Icon**: ♥
- **Color**: Orange (#FF8033)
- **Behavior**: Steady display
- **Priority**: 2
- **Label**: "Low Hull"

### Low Shield
- **Threshold**: 25% shield or below
- **Icon**: ⬡
- **Color**: Cyan (#33CCFF)
- **Behavior**: Steady display
- **Priority**: 3
- **Label**: "Low Shield"

### Low Energy
- **Threshold**: 20% energy or below
- **Icon**: ⚡
- **Color**: Yellow (#E6E64D)
- **Behavior**: Steady display
- **Priority**: 4
- **Label**: "Low Energy"

## Configuration

### Modifying Thresholds

You can adjust thresholds at runtime using the API:

```lua
local StatusIndicators = require("src.hud.status_indicators")

-- Set critical health threshold to 10%
StatusIndicators.setThreshold("critical_health", 0.10)

-- Set low energy threshold to 30%
StatusIndicators.setThreshold("low_energy", 0.30)

-- Get all current thresholds
local thresholds = StatusIndicators.getThresholds()
```

### Available Threshold Keys
- `"critical_health"` (default: 0.15)
- `"low_health"` (default: 0.35)
- `"low_shield"` (default: 0.25)
- `"low_energy"` (default: 0.20)

## Adding New Indicators

To add a new status indicator, edit `src/hud/status_indicators.lua`:

### 1. Add Threshold (if needed)

```lua
local THRESHOLDS = {
    -- ... existing thresholds
    NEW_CONDITION = 0.30,  -- 30% or below
}
```

### 2. Add Indicator Definition

```lua
local INDICATORS = {
    -- ... existing indicators
    new_condition = {
        label = "Warning Label",
        icon = "●",  -- Unicode icon
        color = { 1.0, 0.5, 0.0, 1.0 },  -- RGBA color
        priority = 5,  -- Lower number = higher priority
        flash = false,  -- Set true for flashing effect
        flashSpeed = 3.0,  -- Optional: flash animation speed
    },
}
```

### 3. Add Detection Logic

In the `detect_status_conditions` function:

```lua
-- Check your new condition
local value_current, value_max = Util.resolve_resource(player.yourResource)
if value_current and value_max and value_max > 0 then
    local pct = value_current / value_max
    if pct <= THRESHOLDS.NEW_CONDITION then
        conditions.new_condition = true
    end
end
```

## Technical Details

### File Structure

- **Main Module**: `src/hud/status_indicators.lua`
- **Integration**: `src/hud/init.lua`
- **Dependencies**: 
  - `src.ui.theme` (styling)
  - `src.hud.util` (resource resolution)

### Drawing Pipeline

1. `detect_status_conditions()` analyzes player resources
2. Active indicators are collected and sorted by priority
3. Container background is drawn with proper sizing
4. Each indicator badge is rendered with:
   - Background panel
   - Colored border (flashing if configured)
   - Icon with optional animation
   - Text label

### Performance

- Lightweight conditional checks per frame
- No allocations during normal operation
- Automatic batching of draw calls
- Returns early if no conditions are active

## Visual Design

### Badge Layout
```
┌─────────────────────────────┐
│ ⚠  CRITICAL                 │  ← Flashing red border
├─────────────────────────────┤
│ ♥  Low Hull                 │  ← Orange border
├─────────────────────────────┤
│ ⬡  Low Shield               │  ← Cyan border
└─────────────────────────────┘
```

### Colors

All colors are defined with RGBA values and support alpha blending:
- Red warnings use high saturation for urgency
- Cyan for shields matches shield bar color
- Yellow for energy matches energy indicator color

### Animations

Critical indicators use a sine wave animation:
```lua
local phase = math.sin(time * flashSpeed) * 0.5 + 0.5
borderAlpha = 0.5 + phase * 0.5  -- Pulses between 0.5 and 1.0
```

## Integration with Game Systems

### Player Data Sources

The system automatically detects resources from multiple player component structures:
- Hull: `player.hull` or `player.health`
- Shield: `player.shield`, `player.shields`, or `player.health.shield`
- Energy: `player.energy`, `player.capacitor`, or `player.currentThrust`

### HUD Integration

Status indicators are drawn in the HUD pipeline:
```lua
function Hud.draw(context, player)
    local statusPanelHeight = StatusPanel.draw(player)
    local statusY = 15 + (statusPanelHeight or 0)
    StatusIndicators.draw(player, statusY)  -- ← Positioned below status panel
    -- ... other HUD elements
end
```

## Future Enhancements

Potential additions to the system:
- Overheating warning
- Weapon malfunction indicator
- Hull breach warning
- Life support critical
- Navigation system failure
- Target lock warning (enemy locked on player)
- Buff/debuff status effects
- Environmental hazards (radiation, etc.)

## Example Use Cases

### Combat Awareness
Players can quickly see critical health status and prioritize shield regeneration or retreat.

### Resource Management
Low energy warnings help players manage power distribution between weapons, shields, and engines.

### Visual Feedback
Flashing critical warnings provide clear, immediate feedback during intense combat situations.
