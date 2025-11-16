# Content Pipeline

This document explains how data-driven content (blueprints, items, serialization) fits together, and how to safely extend Novus with new ships, weapons, and world objects.

## Blueprint System Fundamentals

Blueprints live under `src/blueprints/<category>/`. Each Lua module returns either:

1. A static table describing the entity, or
2. A factory function `(context) -> table` that can react to spawn parameters.

### Validation & Loading
- `src/blueprints/loader.lua` resolves modules via `require`.
- `src/blueprints/blueprint.lua` uses schemas and validators to ensure shape correctness.
- `loader.instantiate(category, id, context)` performs validation and forwards to the registered factory for the category (e.g., ships, stations, warpgates).

### Factories
Factories convert blueprint data into ECS entities with physics, drawables, and component flags. See `src/blueprints/ships/factory.lua` (if present) for reference patterns.

## Adding New Content

### 1. New Ship or Station
1. Create a blueprint file under `src/blueprints/ships/` or `src/blueprints/stations/`.
2. Ensure required schema fields are set (check `src/blueprints/schemas.lua`).
3. Register the blueprint in any shop or spawn lists if needed.
4. Run the game and spawn the entity via `Entities.spawnShip` or sector configs to verify.

### 2. New Module or Item
1. Define the item in `src/items/registry.lua` (or appropriate module file).
2. Provide metadata such as `item.value` and `item.volume` for shops.
3. Update UI/shops so the item appears as loot or for purchase.

### 3. New Sector Content
1. Update sector definitions in `src/blueprints/sectors/`.
2. Specify asteroids/enemy/station configs; `Entities.spawnStations` and `spawnEnemies` will read these during `World.initialize`.
3. Use offsets/rotations to control placement.

## Serialization & Persistence

### Component Registry (`src/util/component_registry.lua`)
- Lists serializable components and custom handlers.
- When adding a component that must persist, append a definition to `getAllComponents()`.
- Use `serialize`/`deserialize` callbacks for complex types; simple tables can set `copy = true`.

### Entity Serializer (`src/util/entity_serializer.lua`)
- Converts runtime entities into snapshots (position, velocity, stats, etc.).
- Relies on blueprint metadata to tag archetypes.
- Skips transient entities (projectiles, debug visuals).

### Save/Load (`src/util/save_load.lua`)
- `SaveLoad.serialize(state)` captures player ship, currency, quests, and world entity snapshots.
- `SaveLoad.restore(state, saveData)` rebuilds the world, reinstantiating blueprints and applying component data using the registry.
- When new persistent systems are introduced, ensure they integrate with the component registry and quest tracker if applicable.

## Best Practices

- **Keep Blueprints Declarative**: Limit runtime logic; use systems to implement behavior.
- **Validate Early**: Use the validator schemas to catch missing fields before instantiation.
- **Use Context Safely**: Factories receive context (physicsWorld, worldBounds, overrides). Avoid mutating shared state inside factories.
- **Update Docs**: When adding new blueprint categories or serialization behavior, update this guide and `ComponentRegistry` comments.
- **Test Save/Load**: After introducing new components, create entities in-game, save, reload, and confirm state restoration.

## Troubleshooting

- **Blueprint Fails to Load**: Check console output for validation errors. Ensure module returns a table/function.
- **Entity Missing After Load**: Confirm `ComponentRegistry` knows how to serialize its components and that the entity isn’t flagged as transient.
- **New Items Not Showing in Shops**: Verify item metadata includes `item.value` and that shop generators reference the item ID.
- **Save Crashes**: Inspect `savegame.json` and debug output; ensure new components serialize to JSON-safe values (numbers/strings/tables).
