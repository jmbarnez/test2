# Universe Seeding + World Persistence Plan

## Goals
1. Deterministically recreate the same galaxies / sectors by persisting the RNG seed.
2. Persist the entire simulation state (entities, quests, etc.) over multiple play sessions.
3. Maintain backward compatibility with existing saves.

---

## Milestones

### 1. Seed Tracking (✔ done)
- `SaveLoad` writes `saveData.universe.seed` and restores it when loading.
- `SaveLoad.loadGame(state, saveData)` accepts optional preloaded saves to avoid duplicate disk reads.

**Next:** gameplay lifecycle must set/restore `state.universeSeed` before generating the universe.

### 2. Gameplay Integration (Next Up)
- On fresh games, generate `love.math.random(2^31-1)` and store it on `state.universeSeed`.
- Call `love.math.setRandomSeed(state.universeSeed)` right before `Universe.generate(...)`.
- When loading, `state.universeSeed` already exists, so reseed and rebuild the same universe layout.

### 3. Entity Persistence
- Use `EntitySerializer.serialize_world(state)` to snapshot all ECS entities.
- Extend `SaveLoad.serialize` / `restoreGameState` to save and respawn these entities via their factories.
- Ensure each factory (ships, stations, asteroids, pickups, etc.) supports a `from_snapshot` path.

### 4. Quest & Progress State
- Add explicit serialization to `src/quests/tracker.lua` (active quests, progress, timers, references).
- Persist quest data alongside entities; re-link entity references using stable IDs from the serializer.

### 5. Validation & Tooling
- Hotkeys: F5 quicksave, F9 quickload (already mapped).
- Add debug commands to print current seed and dump serialized world for sanity checking.
- Create automated smoke test: start new game, save, reload, and compare galaxy/sector coordinates.

---

## Open Questions
- Which transient entities should be skipped? (projectiles already excluded; confirm for FX, temporary UI helpers.)
- Do we need multi-slot save support or a single rolling save file?
- Should universe seed also drive loot tables to keep drops deterministic?

---

## Next Steps
1. Gameplay seeding hookup (seed generation + `love.math.setRandomSeed`).
2. Wire `EntitySerializer` into `SaveLoad` and implement spawn-from-snapshot helpers.
3. Add quest tracker serialization and regression tests.
