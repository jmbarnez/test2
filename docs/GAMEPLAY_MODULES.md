# Gameplay Module Architecture

The gameplay state has been refactored into clean, focused modules to improve maintainability and separation of concerns.

## Module Structure

### `src/states/gameplay.lua` (Main Orchestrator)
The main gameplay state is now a thin orchestration layer that:
- Wires together all subsystems
- Manages state lifecycle (enter/leave)
- Coordinates update and render loops
- Delegates specific responsibilities to focused modules

**Reduced from 969 lines to ~357 lines** by extracting focused subsystems.

---

## Gameplay Subsystem Modules

### `src/states/gameplay/physics_callbacks.lua`
**Purpose:** Physics callback routing for Box2D collision events

**Key Functions:**
- `PhysicsCallbacks.ensureRouter(state)` - Initialize callback router
- `PhysicsCallbacks.register(state, phase, handler)` - Register collision handlers
- `PhysicsCallbacks.unregister(state, phase, handler)` - Remove handlers
- `PhysicsCallbacks.clear(state)` - Clean up all callbacks

**Phases:** `beginContact`, `endContact`, `preSolve`, `postSolve`

---

### `src/states/gameplay/docking.lua`
**Purpose:** Station proximity detection and docking state management

**Key Functions:**
- `Docking.updateState(state)` - Find nearest dockable station

**State Updates:**
- `state.stationDockTarget` - Closest station within range
- `state.stationDockRadius` - Docking radius threshold
- `state.stationDockDistance` - Current distance to station
- `station.stationInfluenceActive` - Per-station flag when player in range

---

### `src/states/gameplay/targeting.lua`
**Purpose:** Timed target lock system for missiles and weapons

**Key Functions:**
- `Targeting.beginLock(state, target)` - Start locking onto target
- `Targeting.clearLock(state)` - Cancel current lock-in-progress
- `Targeting.clearActive(state)` - Deselect active target
- `Targeting.update(state, dt)` - Progress lock timer and validate target

**State Management:**
- Handles lock progress and duration
- Validates target health and existence
- Updates targeting cache for HUD display
- Uses player's `stats.targetingTime` for lock duration

---

### `src/states/gameplay/player.lua`
**Purpose:** Player lifecycle management (spawn, death, respawn)

**Key Functions:**
- `Player.registerCallbacks(state, player)` - Attach destruction handlers
- `Player.onDestroyed(state, entity)` - Handle player death
- `Player.respawn(state)` - Respawn player after death

**Responsibilities:**
- Enemy target cleanup on death
- Engine trail management
- Death/respawn UI coordination
- Camera updates on lifecycle events

---

### `src/states/gameplay/feedback.lua`
**Purpose:** UI notifications and status toasts

**Key Functions:**
- `Feedback.showToast(state, message, color)` - Display floating text notification

**Features:**
- Smart positioning (follows player or centers in viewport)
- Configurable colors for different message types
- Consistent styling (rise animation, scale)

---

### `src/states/gameplay/input.lua`
**Purpose:** Input handling (keyboard, mouse, wheel)

**Key Functions:**
- `Input.wheelmoved(state, x, y)` - Camera zoom
- `Input.mousepressed(state, ...)` - Target selection with Ctrl+Click
- `Input.mousereleased(state, ...)` - UI interaction
- `Input.textinput(state, text)` - Text field input
- `Input.keypressed(state, key, scancode, isrepeat)` - All keyboard commands

**Handled Inputs:**
- **Debug:** Toggle debug UI, show seed, dump world
- **UI:** Pause, cargo, map, skills, station interaction
- **Combat:** Weapon slot selection, targeting
- **System:** Fullscreen toggle, save/load
- **Intent System:** Uses `InputMapper` for configurable bindings

---

## Existing Modules (Pre-refactor)

### `src/states/gameplay/world.lua`
- Sector loading and world initialization
- Physics world setup

### `src/states/gameplay/entities.lua`
- Entity spawning (player, enemies, asteroids, stations)
- Entity lifecycle management

### `src/states/gameplay/systems.lua`
- ECS system registration
- System lifecycle (initialize, teardown)

### `src/states/gameplay/view.lua`
- Camera management
- Background rendering
- Viewport resizing

### `src/states/gameplay/universe.lua`
- Procedural galaxy and sector generation
- Universe structure management

### `src/states/gameplay/metrics.lua`
- Performance tracking
- Frame timing statistics

### `src/states/gameplay/starfield.lua`
- Parallax starfield rendering

---

## Benefits of Modular Architecture

### 1. **Separation of Concerns**
Each module has a single, well-defined responsibility.

### 2. **Improved Testability**
Modules can be tested in isolation without full game state.

### 3. **Easier Maintenance**
Bug fixes and features are localized to specific modules.

### 4. **Better Code Navigation**
Developers can quickly find relevant code by module name.

### 5. **Reduced Coupling**
Modules communicate through clean interfaces rather than direct state manipulation.

### 6. **Scalability**
New features can be added as new modules without bloating the main file.

---

## Usage Example

```lua
-- In gameplay:update()
Targeting.update(self, dt)
Docking.updateState(self)

-- In gameplay:mousepressed()
Input.mousepressed(self, x, y, button, istouch, presses)

-- In gameplay:respawnPlayer()
PlayerLifecycle.respawn(self)

-- For feedback
Feedback.showToast(self, "Game Saved", { 0.4, 1.0, 0.4, 1.0 })
```

---

## Future Refactoring Opportunities

1. **Combat System Module** - Extract weapon firing logic from systems
2. **AI Behavior Module** - Separate enemy AI from entities
3. **Inventory Module** - Dedicated cargo and item management
4. **Serialization Module** - Centralized save/load coordination (partially done with component registry)
