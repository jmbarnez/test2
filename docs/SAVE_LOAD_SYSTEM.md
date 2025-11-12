# Save/Load System Documentation

## Overview
The save/load system allows players to persist their game progress and restore it later. It serializes the current game state to a JSON file and can restore that state on demand.

## Architecture

### Core Module: `src/util/save_load.lua`
The `SaveLoad` module handles all serialization, deserialization, file I/O, and state restoration logic.

**Key Functions:**
- `SaveLoad.serialize(state)` - Converts game state to a serializable table
- `SaveLoad.saveGame(state)` - Saves game state to `savegame.json`
- `SaveLoad.loadSaveData()` - Reads and parses save file
- `SaveLoad.restoreGameState(state, saveData)` - Restores game state from save data
- `SaveLoad.loadGame(state)` - Complete load operation (read + restore)
- `SaveLoad.saveExists()` - Checks if a save file exists

### Save Data Schema
```lua
{
    version = 1,                    -- Save format version
    timestamp = 1699876543,         -- Unix timestamp
    sector = "default_sector",      -- Current sector ID
    player = {
        ship = {                    -- Player ship snapshot
            entityId = ...,
            playerId = 1,
            faction = "player",
            blueprint = {
                category = "ships",
                id = "starter"
            },
            position = { x = 0, y = 0 },
            rotation = 0,
            velocity = { x = 0, y = 0 },
            angularVelocity = 0,
            health = { current = 100, max = 100 },
            energy = { current = 100, max = 100 },
            shield = { current = 50, max = 50 },
            modules = { slots = {...} },
            cargo = {
                used = 10,
                capacity = 100,
                items = [
                    {
                        id = "item_id",
                        name = "Item Name",
                        quantity = 1,
                        volume = 5,
                        installed = false,
                        moduleSlotId = nil
                    }
                ]
            },
            stats = {...},
            level = {...}
        },
        currency = 10000,           -- Player credits
        pilot = {
            name = "Pilot",
            level = {...},
            skills = {...}
        }
    }
}
```

## Serialization Details

### Player Ship
Uses `ShipRuntime.serialize()` as the foundation, then extends it with:
- **Cargo Items**: Full item inventory with IDs, quantities, and installation status
- **Module Slots**: Equipped modules via `Modules.serialize()`
- **Physics State**: Position, velocity, rotation, angular velocity

### Cargo Items
Each item in `cargo.items` is serialized with:
- `id` - Item registry ID for re-instantiation
- `name`, `quantity`, `volume`, `icon` - Display properties
- `installed`, `moduleSlotId` - Module installation state

### Player Data
- **Currency**: Direct value from `state.playerCurrency`
- **Pilot**: Name, level data, skill tree (deep copied)

## Deserialization & Restoration

### Load Flow
1. **Read Save File** - Parse JSON from `savegame.json`
2. **Validate Version** - Ensure save format compatibility
3. **Clear World** - Destroy existing entities
4. **Restore Ship** - Re-instantiate from blueprint, then apply snapshot
5. **Restore Cargo** - Re-instantiate items from IDs, restore to cargo
6. **Restore Modules** - Apply module slots (requires cargo items to exist first)
7. **Restore Pilot** - Apply level, skills, currency
8. **Register Player** - Add to ECS world and PlayerManager
9. **Update View** - Reattach camera and engine trail

### Critical Order
1. **Cargo items MUST be restored before modules** - `Modules.apply_snapshot()` looks up items in `cargo.items`
2. **Ship MUST be instantiated from blueprint first** - Provides base structure for `applySnapshot()`
3. **Physics body MUST be updated after snapshot** - Position/velocity need to be applied to physics body

## Integration

### Gameplay State (`src/states/gameplay.lua`)
- **F5** - Quick Save
- **F9** - Quick Load
- Visual feedback via `FloatingText` (green for success, red for errors)
- Console logging for detailed error messages

### File Location
Save files are stored in LÖVE's save directory:
- **Windows**: `%APPDATA%\LOVE\Novus\savegame.json`
- **macOS**: `~/Library/Application Support/LOVE/Novus/savegame.json`
- **Linux**: `~/.local/share/love/Novus/savegame.json`

Use `love.filesystem.getSaveDirectory()` to get the exact path.

## Usage

### In-Game
1. Start a new game and play for a bit
2. Press **F5** to save
3. Continue playing or quit
4. Press **F9** to load the saved state

### Programmatic
```lua
local SaveLoad = require("src.util.save_load")

-- Save
local success, err = SaveLoad.saveGame(gameplayState)
if not success then
    print("Save failed:", err)
end

-- Load
local success, err = SaveLoad.loadGame(gameplayState)
if not success then
    print("Load failed:", err)
end

-- Check if save exists
if SaveLoad.saveExists() then
    print("Save file found")
end
```

## Limitations & Future Enhancements

### Current Limitations
- **Single Save Slot**: Only one save file (`savegame.json`)
- **Player Ship Only**: NPCs, asteroids, and stations are not saved
- **No Autosave**: Manual save only (F5)
- **Sector State**: Dynamic sector changes (destroyed asteroids, etc.) are not persisted

### Potential Enhancements
- Multiple save slots with UI for selection
- Autosave on sector transition or periodic intervals
- Save world entities (stations, NPCs, loot)
- Save sector state (destroyed objects, spawned entities)
- Save metadata (playtime, screenshot thumbnail)
- Cloud save support
- Save compression for smaller file sizes

## Error Handling

The system includes comprehensive error handling:
- **Serialization Errors**: Caught and logged with details
- **File I/O Errors**: Wrapped in `pcall` with error messages
- **JSON Errors**: Decode failures are caught and reported
- **Version Mismatch**: Incompatible saves are rejected
- **Missing Data**: Nil checks prevent crashes during restoration

All errors are:
1. Returned to the caller as `(false, errorMessage)`
2. Logged to console with `[SaveLoad]` prefix
3. Displayed to player via FloatingText (red)

## Testing Checklist

- [ ] Save during gameplay (F5)
- [ ] Load saved game (F9)
- [ ] Verify ship position/rotation restored
- [ ] Verify health/energy/shield values restored
- [ ] Verify cargo items restored (including quantities)
- [ ] Verify equipped modules restored
- [ ] Verify player currency restored
- [ ] Verify pilot level/skills restored
- [ ] Save and quit, then load on next launch
- [ ] Attempt load with no save file (should show error)
- [ ] Verify physics state (velocity) restored correctly

## Technical Notes

### Why Cargo Items Aren't in `runtime.serialize()`
The `ShipRuntime.serialize()` function only stores `cargo.used` and `cargo.capacity`, not the actual items. This is likely because:
1. Items are complex objects with methods and references
2. The runtime serializer focuses on ship state, not inventory
3. Cargo items need special handling for re-instantiation via `Items.instantiate()`

The save/load system extends this by explicitly serializing and restoring cargo items.

### Module Restoration Dependencies
`Modules.apply_snapshot()` builds a lookup table from `entity.cargo.items` to find items by ID. This means cargo items MUST be restored before calling `Modules.apply_snapshot()`, otherwise equipped modules won't be properly linked to their item instances.

### Physics Body Updates
After applying the snapshot, we manually update the physics body's position, velocity, and rotation. This is necessary because:
1. The entity is created with initial spawn position from context
2. `applySnapshot()` updates entity properties but not the physics body
3. Physics bodies must be explicitly synchronized after state changes
