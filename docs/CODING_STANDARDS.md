# Novus Coding Standards & Conventions

**Last Updated:** November 2025  
**Purpose:** Ensure consistency and maintainability for developers without full codebase context.

This document outlines the architectural decisions, naming conventions, code structure patterns, and best practices that must be followed when contributing to Novus.

---

## Table of Contents

1. [Project Architecture](#project-architecture)
2. [Module System & Requires](#module-system--requires)
3. [File Organization](#file-organization)
4. [Naming Conventions](#naming-conventions)
5. [Code Structure Patterns](#code-structure-patterns)
6. [Documentation Standards](#documentation-standards)
7. [UI & Theme Consistency](#ui--theme-consistency)
8. [ECS & Entity Management](#ecs--entity-management)
9. [Error Handling & Validation](#error-handling--validation)
10. [Performance Guidelines](#performance-guidelines)
11. [Testing & Debugging](#testing--debugging)

---

## Project Architecture

### Core Principles

1. **Separation of Concerns**: Split large modules into specialized components. Never exceed ~600 lines in a single file.
2. **Coordinator Pattern**: Use thin facade/coordinator modules that delegate to specialized subsystems.
3. **Backward Compatibility**: When refactoring, maintain all existing public APIs to avoid breaking dependent code.
4. **ECS-Driven Gameplay**: Game logic lives in Tiny-ecs systems, not in scattered helper functions.

### Key Architectural Layers

```
main.lua                    → Bootstrap, custom love.run loop
conf.lua                    → Window & game configuration
src/constants/game.lua      → Central configuration constants
src/states/                 → HUMP gamestate implementations
src/systems/                → ECS systems (update logic)
src/renderers/              → ECS rendering systems
src/spawners/               → ECS spawning systems
src/blueprints/             → Entity definitions
src/ui/                     → User interface framework
src/player/                 → Player management (modular)
src/audio/                  → Audio system
src/util/                   → Reusable utility functions
libs/                       → Third-party libraries (vendored)
assets/                     → Art, fonts, audio, data files
```

**Rule:** New features belong in the appropriate layer. Don't create cross-layer dependencies without careful consideration.

---

## Module System & Requires

### Path Convention

Always use **dot notation** with the `src` prefix:

```lua
-- ✅ CORRECT
local PlayerManager = require("src.player.manager")
local theme = require("src.ui.theme")
local constants = require("src.constants.game")

-- ❌ WRONG - Never use slash notation
local PlayerManager = require("src/player/manager")
```

### Import Order

Group requires in this order:

1. **External libraries** (`libs/`)
2. **Constants & configuration** (`src/constants/`, `src/settings/`)
3. **Utilities** (`src/util/`)
4. **Domain modules** (managers, systems, etc.)
5. **UI components** (`src/ui/`)

```lua
-- Example from src/ui/windows/options.lua
local window = require("src.ui.components.window")
local UIStateManager = require("src.ui.state_manager")
local theme = require("src.ui.theme")
local dropdown = require("src.ui.components.dropdown")

local OptionsData = require("src.settings.options_data")
local AudioSettings = require("src.ui.windows.options.audio")
local DisplaySettings = require("src.ui.windows.options.display")
local Keybindings = require("src.ui.windows.options.keybindings")
```

### Love2D Global Suppression

Every file that uses LÖVE2D APIs must include this diagnostic suppression at the top:

```lua
---@diagnostic disable-next-line: undefined-global
local love = love
```

**Reason:** Prevents Lua language server warnings about undefined `love` global.

---

## File Organization

### Module Structure Template

Every Lua module should follow this structure:

```lua
-- [Module Name]: [One-line description]
-- [Additional context about responsibilities]

-- External dependencies
local SomeDependency = require("src.some.dependency")

-- Love2D global suppression (if needed)
---@diagnostic disable-next-line: undefined-global
local love = love

-- Module table
local ModuleName = {}

-- Private helper functions (local scope)
local function helper_function()
    -- implementation
end

-- Public API functions
function ModuleName.publicFunction(param1, param2)
    -- implementation
end

-- Module return
return ModuleName
```

### Subdirectory Organization

When a module grows too large, split it into a subdirectory:

```
src/player/
    manager.lua          ← Coordinator facade
    registry.lua         ← Player entity tracking
    currency.lua         ← Wallet management  
    skills.lua           ← XP and leveling
    weapons.lua          ← Weapon management

src/ui/windows/
    options.lua          ← Coordinator facade
    options/
        audio.lua        ← Audio settings UI
        display.lua      ← Display settings UI
        keybindings.lua  ← Keybinding configuration
```

**Rule:** Create subdirectories when you have 3+ related specialized modules under a single coordinator.

---

## Naming Conventions

### Files & Directories

- **Lowercase with underscores**: `player_manager.lua`, `engine_trail.lua`
- **Exception:** Uppercase for acronyms if they start the name: `HUD.lua` (avoided in practice—use `hud/init.lua` instead)

### Variables & Functions

```lua
-- Local variables: snake_case
local player_position = {x = 0, y = 0}
local max_health = 100

-- Module names: PascalCase
local PlayerManager = require("src.player.manager")
local AudioManager = require("src.audio.manager")

-- Public functions: camelCase
function PlayerManager.getCurrentShip(context)
end

-- Private functions: snake_case
local function calculate_distance(x1, y1, x2, y2)
end

-- Constants: SCREAMING_SNAKE_CASE
local MAX_SPEED = 500
local DEFAULT_VOLUME = 1.0
```

### UI Component Naming

```lua
-- State variables: camelCase with descriptive suffixes
state.resolutionDropdown = dropdown.create_state()
state.awaitingBindAction = false
state.draggingThumb = false

-- Rectangle tracking: snake_case with _rect suffix
state._sliderRects = {}
state._fullscreenRect = nil
state._restoreRect = nil

-- Temporary/internal state: Prefix with underscore
state._viewportRect = viewportRect
state._maxScroll = maxScroll
state._was_mouse_down = isMouseDown
```

---

## Code Structure Patterns

### The Coordinator Pattern

When refactoring large modules, follow this pattern:

#### Before (Monolithic)
```lua
-- player_manager.lua (600+ lines)
local PlayerManager = {}

function PlayerManager.addXP(entity, amount)
    -- 100 lines of XP logic
end

function PlayerManager.adjustCredits(entity, amount)
    -- 80 lines of currency logic
end

-- ... hundreds more lines
```

#### After (Coordinator + Modules)
```lua
-- player/manager.lua (coordinator, ~240 lines)
local PlayerRegistry = require("src.player.registry")
local PlayerCurrency = require("src.player.currency")
local PlayerSkills = require("src.player.skills")

local PlayerManager = {}

-- Thin delegation wrappers
function PlayerManager.addXP(entity, amount)
    return PlayerSkills.addXP(entity, amount)
end

function PlayerManager.adjustCredits(entity, amount)
    return PlayerCurrency.adjust(entity, amount)
end

return PlayerManager
```

```lua
-- player/skills.lua (specialized module, ~336 lines)
local PlayerSkills = {}

function PlayerSkills.addXP(entity, amount)
    -- Focused XP implementation
end

return PlayerSkills
```

**Benefits:**
- Maintains backward compatibility (all `PlayerManager.*` calls still work)
- Clear separation of concerns
- Each module can be tested/understood independently
- Easy to locate specific functionality

### State Management Pattern

For UI windows and interactive components:

```lua
function window.draw(context)
    local state = context and context.windowUI
    if not (state and state.visible) then
        return false
    end

    -- Initialize transient state (cleared each frame)
    state._sliderRects = {}
    state._bindingButtons = {}
    
    -- Persistent state (survives across frames)
    state.scroll = tonumber(state.scroll) or 0
    state.draggingThumb = state.draggingThumb or false
    
    -- Interaction handling
    local mouseX, mouseY = love.mouse.getPosition()
    local isMouseDown = love.mouse.isDown(1)
    local justPressed = isMouseDown and not state._was_mouse_down
    state._was_mouse_down = isMouseDown
    
    -- ... render and interaction logic
end
```

**Key Rules:**
1. **Transient state** (prefixed with `_`): Rebuilt every frame, used for collision rects
2. **Persistent state**: Survives across frames, stores scroll position, drag state, etc.
3. **Just-pressed detection**: Track previous mouse state to detect button clicks vs. holds

### Module Delegation Pattern

When creating specialized modules for a coordinator:

```lua
-- audio.lua (specialized module)
local AudioSettings = {}

-- Each module exposes:
-- 1. render() - Draws the UI section
function AudioSettings.render(params)
    local cursorY = params.cursorY
    -- Draw UI elements
    return cursorY -- Return updated Y position for layout
end

-- 2. handleInteraction() - Processes input
function AudioSettings.handleInteraction(state, settings, mouseX, mouseY, isMouseDown, justPressed)
    -- Handle clicks, drags, etc.
    return handled -- Return true if input was consumed
end

-- 3. apply() - Applies settings to the engine
function AudioSettings.apply(settings)
    AudioManager.set_master_volume(settings.masterVolume)
end

return AudioSettings
```

**Coordinator Integration:**
```lua
-- options.lua (coordinator)
local AudioSettings = require("src.ui.windows.options.audio")

function options_window.draw(context)
    -- Render phase
    cursorY = AudioSettings.render({
        fonts = fonts,
        settings = settings,
        viewportX = viewportX,
        viewportY = viewportY,
        cursorY = cursorY,
        -- ... other params
    })
    
    -- Interaction phase
    if isMouseDown then
        AudioSettings.handleInteraction(state, settings, mouseX, mouseY, isMouseDown, justPressed)
    end
end
```

---

## Documentation Standards

### File Headers

Every file must start with a descriptive header:

```lua
-- [ModuleName]: [One-line summary]
-- [Detailed description of responsibilities]
-- [Optional: Dependencies, usage notes, or constraints]
```

**Examples:**

```lua
-- Audio Settings: Volume controls and audio configuration UI
-- Handles volume sliders (master, music, SFX) and audio engine integration

-- PlayerManager: Coordinating facade for player management subsystems
-- Delegates to specialized modules for registry, currency, and skills
-- Maintains backward compatibility while providing a cleaner internal structure
```

### Function Documentation (LuaLS Annotations)

Use LuaLS-style annotations for all public functions:

```lua
--- Applies volume settings to the audio engine
---@param settings table The settings table
function AudioSettings.apply(settings)
    -- implementation
end

--- Resolves state reference from various context types
---@param context table The context object
---@return table|nil The state reference
local function resolve_state_reference(context)
    -- implementation
end

--- Handles keypresses in the options window
---@param context table The gameplay context
---@param key string The key that was pressed
---@return boolean Whether the key was handled
function options_window.keypressed(context, key)
    -- implementation
end
```

**Annotation Rules:**
1. Use `---` (three dashes) for doc comments
2. Include `@param` for every parameter with type and description
3. Include `@return` for return values with type and description
4. Use `|nil` for optional returns: `@return table|nil`
5. Use descriptive types: `table`, `string`, `number`, `boolean`, `function`

### Inline Comments

```lua
-- ✅ GOOD - Explains WHY, not WHAT
-- Prevent division by zero in edge case where contentHeight equals viewportHeight
if contentHeight > 0 then
    local ratio = viewportHeight / contentHeight
end

-- ❌ BAD - Just repeats the code
-- Calculate ratio
local ratio = viewportHeight / contentHeight
```

---

## UI & Theme Consistency

### Theme Usage

**Always** use `theme.lua` for colors, fonts, and spacing:

```lua
local theme = require("src.ui.theme")

function draw_ui()
    local fonts = theme.get_fonts()
    local windowColors = theme.colors.window or {}
    
    -- Use theme colors, never hardcoded RGB
    love.graphics.setColor(windowColors.text or { 0.85, 0.85, 0.9, 1 })
    love.graphics.setFont(fonts.body)
    love.graphics.print("Hello", x, y)
end
```

### Color Palette Hierarchy

From `theme.lua`:

```lua
-- Core palette
palette.surface_deep       → Deep backgrounds (0.04, 0.05, 0.07)
palette.surface_subtle     → Subtle backgrounds (0.08, 0.09, 0.12)
palette.surface_top        → Top bars (0.12, 0.14, 0.18)
palette.border             → Borders (0.22, 0.28, 0.36)
palette.accent             → Primary accent (0.46, 0.64, 0.72)
palette.accent_player      → Player-related (0.3, 0.78, 0.46)
palette.accent_station     → Station-related (0.32, 0.52, 0.92)
palette.accent_warning     → Warnings/errors (0.85, 0.42, 0.38)
palette.text_heading       → Headings (0.85, 0.89, 0.93)
palette.text_body          → Body text (0.7, 0.76, 0.8)
palette.text_muted         → Muted text (0.46, 0.52, 0.58)
```

### Font Sizes

```lua
fonts.title    → 16pt (section headings)
fonts.body     → 13pt (main content)
fonts.small    → 11pt (hints, secondary info)
fonts.tiny     → 9pt (micro text)
```

**Rule:** Never create custom fonts—use theme functions exclusively.

### UI Layout Patterns

#### Scissor Clipping for Scrollable Content

```lua
-- Setup viewport
local viewportRect = {
    x = contentX,
    y = contentY,
    w = contentWidth,
    h = contentHeight,
}

-- Enable scissor
love.graphics.setScissor(viewportRect.x, viewportRect.y, viewportRect.w, viewportRect.h)

-- Draw content with scroll offset
draw_content(viewportY - state.scroll)

-- Disable scissor
love.graphics.setScissor()
```

#### Scrollbar Rendering

```lua
local thumbHeight = math.max(18, scrollAreaHeight * (viewportHeight / contentHeight))
local thumbTravel = scrollAreaHeight - thumbHeight
local thumbY = scrollAreaY + (thumbTravel > 0 and (state.scroll / maxScroll) * thumbTravel or 0)

-- Track rect
love.graphics.setColor(windowColors.border)
love.graphics.rectangle("fill", scrollbarX, scrollAreaY, SCROLLBAR_WIDTH, scrollAreaHeight, 4, 4)

-- Thumb rect
love.graphics.setColor(hoveredThumb and windowColors.title_text or windowColors.button)
love.graphics.rectangle("fill", thumbRect.x, thumbRect.y, thumbRect.w, thumbRect.h, 3, 3)
```

#### Button Hover States

```lua
local buttonRect = {x = x, y = y, w = width, h = height}
local hovered = point_in_rect(mouseX, mouseY, buttonRect)

love.graphics.setColor(hovered and windowColors.button_hover or windowColors.button)
love.graphics.rectangle("fill", buttonRect.x, buttonRect.y, buttonRect.w, buttonRect.h, 6, 6)
```

---

## ECS & Entity Management

### System Creation Pattern

Systems live in `src/systems/`, `src/spawners/`, or `src/renderers/`:

```lua
-- src/systems/example_system.lua
return function(context)
    local world = context.world
    
    local system = {
        filter = tiny.requireAll("someComponent"),
        
        process = function(self, entity, dt)
            -- Process entity each frame
        end,
        
        onAdd = function(self, entity)
            -- Called when entity enters system
        end,
        
        onRemove = function(self, entity)
            -- Called when entity leaves system
        end,
    }
    
    return system
end
```

### System Registration

In `src/states/gameplay/systems.lua`:

```lua
function Systems.initialize(context)
    local world = tiny.world()
    
    -- Register systems in dependency order
    world:addSystem(require("src.systems.input_local")(context))
    world:addSystem(require("src.systems.player_control")(context))
    world:addSystem(require("src.systems.movement")(context))
    -- ... more systems
    
    context.world = world
end
```

### Entity Creation via Blueprints

```lua
-- Load blueprint
local loader = require("src.blueprints.loader")
local ship = loader.instantiate("ships", "light_fighter", context)

-- Add to world
context.world:addEntity(ship)

-- Register with PlayerManager (if player ship)
PlayerManager.register(context, ship)
```

**Rule:** Never create entities manually—always use blueprints and factory functions.

---

## Error Handling & Validation

### Error Handling Strategy

1. **Define the audience of the error.**
   - Use `assert` (or `error`) only for *developer contract violations*—bad blueprint data, missing required fields, or states that should be impossible if the code is correct. Always include a descriptive message that pinpoints the failure.
   - Prefer graceful returns (`return false, "reason"` or `return nil`) for runtime issues that can happen in normal play, such as optional modules not being initialized yet or input coming from user-configurable data.
2. **Never fail silently without context.** If a function cannot complete its work, it must either:
   - Return a status boolean plus an explanatory message, or
   - Log a warning when `context.debugMode`/`_G.DEBUG` is true so the issue surfaces during testing.
3. **Degrade when possible.** For optional systems (audio, analytics, network), attempt a fallback path before giving up. Only surface a hard error when no safe alternative exists.
4. **Document expectations.** Public APIs must state whether they `assert`, throw, or return status codes so callers can handle the outcome consistently.

### Nil-Safety Pattern

Always validate inputs that could be nil:

```lua
function PlayerManager.adjustCredits(context, entity, amount)
    -- Validate context
    if not context then
        return nil
    end
    
    -- Validate entity
    if not entity then
        local player = PlayerRegistry.getCurrentShip(context)
        if not player then
            return nil
        end
        entity = player
    end
    
    -- Validate amount
    amount = tonumber(amount)
    if not amount then
        return nil
    end
    
    -- Safe to proceed
    return PlayerCurrency.adjust(entity, amount)
end
```

### Type Coercion Pattern

When accepting numeric inputs (especially from UI):

```lua
-- ❌ WRONG - Assumes parameter is already a number
state.scroll = state.scroll + y

-- ✅ CORRECT - Coerce and validate
local yAmount = tonumber(y)
if not yAmount or yAmount == 0 then
    return false
end
state.scroll = state.scroll + yAmount
```

### Graceful Degradation

```lua
function AudioSettings.apply(settings)
    -- Try full-featured audio manager
    if AudioManager and AudioManager.ensure_initialized then
        AudioManager.ensure_initialized()
        AudioManager.set_master_volume(settings.masterVolume or 1)
        AudioManager.set_music_volume(settings.musicVolume or 1)
    -- Fall back to basic LÖVE2D audio
    elseif love.audio and love.audio.setVolume then
        love.audio.setVolume(settings.masterVolume or 1)
    end
    -- Silently skip if no audio available (headless mode, tests, etc.)
end
```

---

## Performance Guidelines

### Avoid Allocations in Hot Paths

```lua
-- ❌ BAD - Creates table every frame
function system:process(entity, dt)
    local position = {x = entity.x, y = entity.y}
    update_position(position)
end

-- ✅ GOOD - Reuse entity fields
function system:process(entity, dt)
    update_position(entity, dt)
end
```

### Reuse State Tables

```lua
-- ✅ GOOD - Initialize once, reuse across frames
function options_window.draw(context)
    local state = context.optionsUI
    
    -- Initialize transient tables (cleared each frame)
    state._sliderRects = state._sliderRects or {}
    state._bindingButtons = state._bindingButtons or {}
    
    -- Clear contents but reuse table
    for k in pairs(state._sliderRects) do
        state._sliderRects[k] = nil
    end
end
```

### Cache Expensive Calculations

```lua
-- Cache content height measurement
local contentHeight = state._cachedContentHeight
if not contentHeight or state._contentDirty then
    contentHeight = measure_content_height()
    state._cachedContentHeight = contentHeight
    state._contentDirty = false
end
```

### Limit Search Scope

```lua
-- ❌ BAD - Iterates entire world
for _, entity in ipairs(world:getEntities()) do
    if entity.ship and entity.isPlayer then
        -- ...
    end
end

-- ✅ GOOD - Use filters/caching
local player = PlayerManager.getCurrentShip(context) -- Cached lookup
```

---

## Testing & Debugging

### Debug Output Pattern

Use consistent debug logging:

```lua
-- Check if debugging is enabled
if context.debugMode or _G.DEBUG then
    print(string.format("[ModuleName] %s: %s", functionName, debugInfo))
end
```

### Diagnostic Overlays

For in-game debugging, use the diagnostics HUD:

```lua
local Diagnostics = require("src.hud.diagnostics")

Diagnostics.update(context, {
    entities = world:getEntityCount(),
    systems = world:getSystemCount(),
    fps = love.timer.getFPS(),
    -- ... custom metrics
})
```

### Error Messages

```lua
-- ❌ BAD - Generic error
error("Invalid input")

-- ✅ GOOD - Descriptive error with context
error(string.format(
    "[PlayerManager.adjustCredits] Invalid amount: expected number, got %s",
    type(amount)
))
```

### Logging to Files

For persistent logs (see `logs/` directory):

```lua
local log_file = io.open("logs/debug_output_" .. os.date("%Y%m%d_%H%M%S") .. ".txt", "w")
if log_file then
    log_file:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), message))
    log_file:close()
end
```

---

## Common Patterns Reference

### Point-in-Rectangle Test

```lua
local function point_in_rect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and
           y >= rect.y and y <= rect.y + rect.h
end
```

### Clamping

```lua
local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
end
```

### Just-Pressed Detection

```lua
local isMouseDown = love.mouse.isDown(1)
local justPressed = isMouseDown and not state._was_mouse_down
state._was_mouse_down = isMouseDown

if justPressed then
    -- Handle click
end
```

### Layout Accumulator

```lua
local cursorY = 0

-- Heading
cursorY = cursorY + drawHeading("Section Title", cursorY)
cursorY = cursorY + 12 -- Spacing

-- Content
cursorY = cursorY + drawContent(cursorY)
cursorY = cursorY + 8 -- Spacing

return cursorY -- Return total height
```

---

## Anti-Patterns to Avoid

### ❌ God Objects

Don't create 600+ line files that do everything:

```lua
-- BAD: player_manager.lua (1000 lines)
-- - Player registration
-- - Currency management
-- - XP and leveling
-- - Inventory
-- - Weapon management
-- - Input handling
-- - UI rendering
```

**Solution:** Split into specialized modules with a coordinator facade.

### ❌ Hardcoded Values

```lua
-- BAD
love.graphics.setColor(0.2, 0.5, 0.9, 1)
local fontSize = 14

-- GOOD
love.graphics.setColor(theme.colors.window.accent)
local fontSize = theme.get_fonts().body:getHeight()
```

### ❌ String Path Requires

```lua
-- BAD
local manager = require("src/player/manager")

-- GOOD
local manager = require("src.player.manager")
```

### ❌ Global State Mutation

```lua
-- BAD
_G.PLAYER_SHIP = ship

-- GOOD
PlayerManager.register(context, ship)
```

### ❌ Mixed Concerns

```lua
-- BAD: Rendering system that also handles input
function render_system:process(entity, dt)
    draw_entity(entity)
    if love.mouse.isDown(1) then
        handle_click(entity)
    end
end

-- GOOD: Separate rendering and input systems
```

---

## Quick Reference Checklist

When creating a new module:

- [ ] File header with description
- [ ] Love2D diagnostic suppression if needed
- [ ] Requires organized in standard order
- [ ] Using dot notation for all requires
- [ ] LuaLS annotations on public functions
- [ ] snake_case for local functions/variables
- [ ] PascalCase for module names
- [ ] camelCase for public functions
- [ ] Theme colors/fonts (no hardcoded values)
- [ ] Nil-safety checks on inputs
- [ ] Return module table at end
- [ ] Under 600 lines (split if larger)
- [ ] Clear separation of concerns

---

## When to Refactor

Watch for these warning signs:

1. **File exceeds 600 lines** → Split into coordinator + specialized modules
2. **Function exceeds 100 lines** → Break into smaller functions
3. **Copying code between files** → Extract to shared utility
4. **More than 3 nested conditionals** → Simplify logic or split function
5. **Hardcoded values repeated** → Move to constants or theme
6. **Module imports from 5+ different domains** → Too many responsibilities, split it up

---

## Additional Resources

- **Architecture Overview:** `docs/architecture.md`
- **Theme Reference:** `src/ui/theme.lua`
- **ECS Examples:** `src/systems/*.lua`
- **Blueprint Examples:** `src/blueprints/ships/`
- **Recent Refactorings:**
  - `src/player/` - PlayerManager split (Nov 2025)
  - `src/ui/windows/options/` - Options window split (Nov 2025)

---

**Remember:** Consistency beats perfection. When in doubt, follow existing patterns in the codebase.
