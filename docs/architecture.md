# Novus Architecture Overview

This document provides a quick reference to the major architectural systems in **Novus** for both human developers and AI assistants. It outlines how the game boots, how gameplay state is orchestrated, and where to extend key gameplay loops.

---

## Core Runtime Loop

- **Entry Point (`main.lua`)** – Initializes window configuration, physics meters, audio, and switches to the start menu state using `hump.gamestate`. The custom `love.run` implements an optional manual frame limiter when VSYNC is off.
- **States (`src/states/`)** – Game flow is driven by HUMP state objects. Key states are:
  - `start_menu` – Handles the front-end menu.
  - `gameplay` – Owns the active world, ECS, UI, and camera logic.

When `gameplay` is entered it loads the world, initializes the ECS systems, spawns the player, and starts background music. Leaving the state tears everything down cleanly (physics, ECS systems, UI state, audio).

---

## Entity Component System (ECS)

Novus uses [Tiny-ecs](https://github.com/bakpakin/tiny-ecs) to drive gameplay systems.

- **World Management** – `Systems.initialize` in `src/states/gameplay/systems.lua` ensures a `tiny.world`, attaches shared `uiInput`, and registers all active systems. Teardown removes references and resets captured input state.
- **Update Order** – The `gameplay:update` loop steps physics on a fixed timestep, then calls `world:update(dt)` so systems process freshly simulated positions.
- **System Groups**:
  - *Input & Control*: `input_local`, `player_control`
  - *Simulation*: `movement`, `ship`, `projectile`, `weapon_logic`, `weapon_projectile_spawn`, `weapon_hitscan`, `enemy_ai`
  - *Spawning & Progression*: `asteroid`, `enemy`, `station`, `loot_drop`, `pickup`
  - *Destruction & Effects*: `destruction`, `damage_numbers`
  - *Presentation*: `render`, `weapon_beam_vfx`, `hud`, `ui`, `targeting`

Each system resides in `src/systems/` (or `src/spawners/`, `src/renderers/`) and is created via factory functions that accept a gameplay **context** rather than the raw state table.

### Gameplay Context (`GameContext`)

Gameplay systems and spawners take a context table that wraps the `gameplay` state:

- **Creation** – `GameContext.compose(state, overrides?)` builds a context with:
  - `state` – the underlying gameplay state table.
  - `resolveState()` – helper that returns `state` (safe for callers that only see context).
  - `resolveLocalPlayer()` – helper that uses `PlayerManager` to find the local player.
  - Optional `registerPhysicsCallback` – present when the state exposes `registerPhysicsCallback`.
  - `__index` fallback to `state`, so existing code that read `state.world`, `state.camera`, etc. continues to work.
- **Extension** – `GameContext.extend(context, overrides?)` clones an existing context and merges in per-system overrides (e.g. `camera`, `uiInput`, `intentHolder`).

`Systems.initialize` wires systems with shared base contexts:

- `baseContext = GameContext.compose(state, { damageEntity = ... })`
- `sharedContext = context or GameContext.compose(state)`

Systems are then constructed using `baseContext` / `GameContext.extend(baseContext, {...})` so they all see a consistent view of the gameplay state plus their own overrides.

### System Context Types (`*SystemContext`)

Each system defines a local `*SystemContext` type documenting what it reads from the context table, for example:

- `WeaponSystemContext` – `physicsWorld`, `damageEntity`, `camera`, `intentHolder`, `state`, optional `registerPhysicsCallback`.
- `ProjectileSystemContext` – `physicsWorld` (required), optional `damageEntity` and `registerPhysicsCallback`.
- `PlayerControlSystemContext` – `state`, `camera`, optional `engineTrail`, `uiInput`, `intentHolder`.
- `TargetingSystemContext` – `state`, optional `camera` and `uiInput`.

**Guidelines when adding new systems:**

1. Define a local `---@class SomeSystemContext` near the top of the system file.
2. Only document fields the system actually reads from `context`.
3. Prefer taking a context (`GameContext.compose/extend`) over the raw state so helpers like `resolveState` and `resolveLocalPlayer` stay available.

### Entities & Blueprints

- **Blueprint Loader** – `src/blueprints/loader.lua` loads static definitions or factory functions and hands them to a registered category factory. Blueprints live under `src/blueprints/<category>/`.
- **Instantiation** – Gameplay code typically calls `loader.instantiate("ships", shipId, context)` via convenience functions in `src/states/gameplay/entities.lua`. Entities are plain tables with component-like fields consumed by Tiny systems.
- **Player/World Entities** – `Entities.spawnPlayer` spawns the player ship, attaches it to `PlayerManager`, and inserts it into the ECS world. Stations, asteroids, enemies, loot, etc. follow similar patterns via helper functions in the same module.

---

## Player & Input Management

- **Intent System** – `src/input/intent.lua` (referenced by `Systems.initialize`) holds per-frame input buffers consumed by control and weapon systems.
- **Player Manager** – `src/player/manager.lua` tracks player ships, attaches stats/XP, and exposes helper functions used by gameplay and UI states.
- **Camera & View** – `src/states/gameplay/view.lua` (and related modules) compute camera position, parallax backgrounds, and resize hooks to keep the HUD aligned.

---

## User Interface Framework

- **UI State Manager** – `src/ui/state_manager.lua` stores visibility, modal status, and geometry for every window (cargo, map, skills, pause, death, options). It also controls `uiInput` capture so gameplay cannot steal input when a modal is open.
- **Windows** – Individual windows live in `src/ui/windows/` and expose `draw`, `update`, and event handlers. They follow Novak’s flat, hard-edged aesthetic and use shared theme helpers in `src/ui/theme.lua`.
- **UI System** – The ECS `ui` system (`src/systems/ui.lua`) resets `uiInput` capture flags each frame, draws windows and notifications, and re-applies capture if any modal UI is visible. Tooltips are rendered last to sit above everything.
- **Notifications & HUD** – `src/ui/notifications.lua` and `src/hud/` render transient messages plus the in-game HUD (target reticles, health/credits readouts).

---

## Audio System

- **Audio Manager** – `src/audio/manager.lua` auto-imports SFX and music by scanning `assets/sounds` and `assets/music` (configurable prefixes: `sfx:` and `music:`). It maintains a registry of audio sources, supports per-track volume overrides, and exposes `play_sfx`, `play_music`, `stop_music`, etc.
- **Integration** – `main.lua` initializes the audio manager once; gameplay states request tracks like `AudioManager.play_music("music:adrift", { loop = true, restart = true })` and leverage auto-imported IDs for SFX.

---

## Data, Assets, and Constants

- **Constants** – `src/constants/game.lua` centralizes window options, physics tuning, and gameplay defaults (starter ship, XP multipliers, etc.).
- **Assets** – Static art, fonts, sounds, and music live in `assets/`. The audio manager’s auto-scan plus blueprint references ensure new assets become available without manual registration.
- **Libraries** – External libs are vendored under `libs/`, notably `hump` (state machine), `tiny` (ECS), and `json.lua`.

---

## Extending Novus

When implementing new features:

1. **Choose the right state** – Gameplay features belong in the `gameplay` state or its systems. Menu or modal work belongs under `start_menu` or the relevant UI window.
2. **Add or Modify Systems** – To hook into the ECS update loop, create a system in `src/systems/` and register it in `Systems.initialize`. Keep system responsibilities narrow.
3. **Expand Blueprints** – Add new ships, stations, or pickups by creating blueprints and, if necessary, extending the category factory.
4. **Respect UI Capture** – Update `UIStateManager` when introducing new windows so gameplay input is correctly paused.
5. **Leverage AudioManager** – Drop new audio files into assets and reference them via normalized identifiers (e.g., `sfx:weapons:laser_burst`).

---

## Quick Reference Map

| Domain | Key Modules |
| --- | --- |
| Boot & Loop | `main.lua`, `conf.lua`, `src/constants/game.lua` |
| States | `src/states/start_menu.lua`, `src/states/gameplay.lua` |
| ECS Systems | `src/states/gameplay/systems.lua`, `src/systems/*.lua`, `src/spawners/*.lua` |
| Entities & Blueprints | `src/states/gameplay/entities.lua`, `src/blueprints/` |
| Player & Input | `src/player/manager.lua`, `src/input/intent.lua` |
| UI | `src/ui/state_manager.lua`, `src/ui/windows/*.lua`, `src/ui/theme.lua`, `src/systems/ui.lua` |
| Audio | `src/audio/manager.lua`, `assets/sounds/`, `assets/music/` |

Use this outline as a launchpad when exploring the codebase or building tooling/scripts around Novus.
