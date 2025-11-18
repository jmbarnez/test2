local UIStateManager = require("src.ui.state_manager")
---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local GameContext = require("src.states.gameplay.context")
local constants = require("src.constants.game")
local FloatingText = require("src.effects.floating_text")
local ItemLabel = require("src.util.item_label")
local createMovementSystem = require("src.systems.movement")
local createRenderSystem = require("src.renderers.render")
local createPlayerControlSystem = require("src.systems.player_control")
local EngineTrailSystem = require("src.systems.engine_trail")
local createAsteroidSpawner = require("src.spawners.asteroid")
local createEnemySpawner = require("src.spawners.enemy")
local createProceduralShipSpawner = require("src.spawners.procedural_ships")
local createStationSpawner = require("src.spawners.station")
local createWarpgateSpawner = require("src.spawners.warpgate")
local createEnemyBehaviorSystem = require("src.ai.enemy_behaviors.system")
local createWeaponUnifiedSystem = require("src.systems.weapon_unified")
local createWeaponBeamVFXSystem = require("src.systems.weapon_beam_vfx")

-- Initialize weapon behavior system (registers fallback behaviors)
require("src.weapons.init")
local createProjectileSystem = require("src.systems.projectile")
local createCollisionImpactSystem = require("src.systems.collision_impact")
local createShipSystem = require("src.systems.ship")
local createAbilityModuleSystem = require("src.systems.ability_modules")
local createHudSystem = require("src.systems.hud")
local createUiSystem = require("src.systems.ui")
local createTargetingSystem = require("src.systems.targeting")
local createDestructionSystem = require("src.systems.destruction")
local createLootDropSystem = require("src.systems.loot_drop")
local createPickupSystem = require("src.systems.pickup")
local createPickupHoverSystem = require("src.systems.pickup_hover")
local createEffectsRendererSystem = require("src.systems.effects_renderer")
local Entities = require("src.states.gameplay.entities")
local LootRewards = require("src.player.loot_rewards")

local Systems = {}

local function build_pickup_label(item_name, quantity)
    if quantity and quantity > 1 then
        return string.format("+%dx %s", quantity, item_name)
    end
    return string.format("+%s", item_name)
end

local function is_floating_entry_active(entry)
    return entry
        and entry.__alive ~= false
        and entry.duration
        and entry.age
        and entry.age < entry.duration
end

local function update_entry_lines(entry, label)
    local lines = {}
    for line in string.gmatch(label, "[^\n]+") do
        lines[#lines + 1] = line
    end
    if #lines == 0 then
        lines[1] = label
    end
    entry.lines = lines
end

local function handle_pickup_collected(pickup, ship, entity, state)
    if not (state and pickup and type(pickup) == "table" and pickup.item) then
        return
    end

    local floating_text_module = FloatingText
    if not (floating_text_module and floating_text_module.add) then
        return
    end

    local position = (entity and entity.position)
        or (pickup.position)
        or (ship and ship.position)

    if not (position and position.x and position.y) then
        return
    end

    local item = pickup.item
    local quantity = pickup.quantity or item.quantity or 1
    local item_name = ItemLabel.resolve(item)
    local ui_constants = constants.ui
    local floating_constants = ui_constants and ui_constants.floating_text or {}
    local pickup_style = floating_constants.pickup or {}

    local offsetY = pickup_style.offsetY or pickup_style.offset_y or 26
    local cache_key = item.id or item_name
    local accumulator_map = state._pickupFloatingAccum or {}
    state._pickupFloatingAccum = accumulator_map

    local accumulator = cache_key and accumulator_map[cache_key] or nil
    if accumulator then
        local entry = accumulator.entry
        if not is_floating_entry_active(entry) then
            accumulator_map[cache_key] = nil
            accumulator = nil
        end
    end

    local total_quantity = quantity
    local entry

    if accumulator then
        total_quantity = (accumulator.quantity or 0) + quantity
        entry = accumulator.entry
    end

    local label = build_pickup_label(item_name, total_quantity)

    if entry and is_floating_entry_active(entry) then
        entry.text = label
        update_entry_lines(entry, label)
        entry.age = 0
        entry.__alive = true
        entry.x = (position.x or 0)
        entry.y = (position.y or 0) - offsetY
        accumulator.quantity = total_quantity
    else
        entry = floating_text_module.add(state, position, label, {
            color = pickup_style.color,
            rise = pickup_style.rise,
            scale = pickup_style.scale,
            font = pickup_style.font,
            offsetY = offsetY,
        })

        if cache_key and entry then
            accumulator_map[cache_key] = {
                entry = entry,
                quantity = total_quantity,
            }
        elseif cache_key then
            accumulator_map[cache_key] = nil
        end
    end

    if state.targetingCache then
        if state.targetingCache.pickupHoveredEntity == entity then
            state.targetingCache.pickupHoveredEntity = nil
            state.targetingCache.pickupHoverRadius = nil
        end
    end

    if state.pickupHoverEntity == entity then
        state.pickupHoverEntity = nil
        state.pickupHoverRadius = nil
    end
end

-- System wiring overview:
--   baseContext = GameContext.compose(state, { damageEntity = ... })
--     * Provides: state, resolveState, resolveLocalPlayer, registerPhysicsCallback (if available)
--   sharedContext = context or GameContext.compose(state)
--
-- Systems and their primary context fields:
--   createLocalInputSystem(GameContext.extend(baseContext, {
--       camera = state.camera,
--       uiInput = state.uiInput,
--   }))
--   createPlayerControlSystem(GameContext.extend(baseContext, {
--       camera = state.camera,
--       engineTrail = state.engineTrail,
--       uiInput = state.uiInput,
--       intentHolder = state,
--   }))
--   createPickupSystem(GameContext.extend(sharedContext))
--   createWeaponLogicSystem(GameContext.extend(sharedContext))    -- handles input/aiming
--   createWeaponUnifiedSystem(GameContext.extend(sharedContext))  -- behavior plugin architecture
--   createWeaponBeamVFXSystem(baseContext)                        -- renders beam effects
--   createShipSystem(GameContext.extend(sharedContext))
--   createAbilityModuleSystem(GameContext.extend(sharedContext))  -- uses state/intentHolder via GameContext
--   createProjectileSystem(GameContext.extend(sharedContext))     -- uses physicsWorld, damageEntity, registerPhysicsCallback
--   createCollisionImpactSystem(GameContext.extend(sharedContext)) -- uses registerPhysicsCallback for shield collision effects
--   createLootDropSystem(GameContext.extend(sharedContext, {
--       spawnLootItem = Entities.spawnLootPickup,
--       onLootDropped = ...
--   }))
--   createDestructionSystem(GameContext.extend(sharedContext))
--   createEnemyBehaviorSystem(baseContext)
--   createRenderSystem(baseContext)
--   createEffectsRendererSystem(GameContext.extend(baseContext, {
--       projectileSystem = state.projectileSystem,
--       weaponBeamSystem = state.weaponBeamVFXSystem,
--   }))
--   createTargetingSystem(GameContext.extend(baseContext, {
--       camera = state.camera,
--       uiInput = state.uiInput,
--   }))
--   createHudSystem(baseContext)
--   createUiSystem(baseContext)

local function ensure_world(state)
    if not state.world then
        state.world = tiny.world()
    end
end

local function reset_ui_input(state)
    if not state then
        return
    end

    state.uiInput = state.uiInput or {}
    state.uiInput.mouseCaptured = false
    state.uiInput.keyboardCaptured = false
end

local function add_common_systems(state, context)
    state.movementSystem = state.world:addSystem(createMovementSystem())
    local sharedContext = context or GameContext.compose(state)
    local pickupContext = GameContext.extend(sharedContext, {
        onCollected = function(pickup, ship, entity, game_state)
            handle_pickup_collected(pickup, ship, entity, game_state)
        end,
    })
    state.pickupSystem = state.world:addSystem(createPickupSystem(pickupContext))

    -- Unified weapon system (behavior plugin architecture)
    state.weaponUnifiedSystem = state.world:addSystem(createWeaponUnifiedSystem(GameContext.extend(sharedContext)))
    state.shipSystem = state.world:addSystem(createShipSystem(GameContext.extend(sharedContext)))
    state.abilitySystem = state.world:addSystem(createAbilityModuleSystem(GameContext.extend(sharedContext)))
    state.projectileSystem = state.world:addSystem(createProjectileSystem(GameContext.extend(sharedContext)))
    state.collisionImpactSystem = state.world:addSystem(createCollisionImpactSystem(GameContext.extend(sharedContext)))
    state.lootDropSystem = state.world:addSystem(createLootDropSystem(GameContext.extend(sharedContext, {
        spawnLootItem = function(drop)
            return Entities.spawnLootPickup(state, drop)
        end,
        onLootDropped = function(drop, entity)
            LootRewards.apply(state, drop, entity)
        end,
    })))
    state.destructionSystem = state.world:addSystem(createDestructionSystem(GameContext.extend(sharedContext)))
    state.pickupHoverSystem = state.world:addSystem(createPickupHoverSystem(GameContext.extend(sharedContext)))
end

function Systems.initialize(state, damageCallback)
    ensure_world(state)

    reset_ui_input(state)

    local baseContext = GameContext.compose(state, {
        damageEntity = damageCallback or state.damageEntity,
    })

    state.damageEntity = baseContext.damageEntity

    state.controlSystem = state.world:addSystem(createPlayerControlSystem(GameContext.extend(baseContext, {
        camera = state.camera,
        engineTrail = state.engineTrail,
        uiInput = state.uiInput,
        intentHolder = state,
    })))

    state.spawnerSystem = state.world:addSystem(createAsteroidSpawner(baseContext))
    state.enemySpawnerSystem = state.world:addSystem(createEnemySpawner(baseContext))
    state.proceduralShipSpawnerSystem = state.world:addSystem(createProceduralShipSpawner(baseContext))
    state.stationSpawnerSystem = state.world:addSystem(createStationSpawner(baseContext))
    state.warpgateSpawnerSystem = state.world:addSystem(createWarpgateSpawner(baseContext))

    add_common_systems(state, baseContext)

    local enemyAIContext = GameContext.extend(baseContext, {
        getLocalPlayer = function(self)
            return GameContext.resolveLocalPlayer(self or state)
        end,
    })

    state.enemyBehaviorSystem = state.world:addSystem(createEnemyBehaviorSystem(enemyAIContext))

    state.engineTrailSystem = state.world:addSystem(EngineTrailSystem)
    state.renderSystem = state.world:addSystem(createRenderSystem(baseContext))
    state.weaponBeamVFXSystem = state.world:addSystem(createWeaponBeamVFXSystem(baseContext))
    state.effectsRendererSystem = state.world:addSystem(createEffectsRendererSystem(GameContext.extend(baseContext, {
        projectileSystem = state.projectileSystem,
        weaponBeamSystem = state.weaponBeamVFXSystem,
    })))
    state.targetingSystem = state.world:addSystem(createTargetingSystem(GameContext.extend(baseContext, {
        camera = state.camera,
        uiInput = state.uiInput,
    })))
    state.hudSystem = state.world:addSystem(createHudSystem(baseContext))
    state.uiSystem = state.world:addSystem(createUiSystem(baseContext))
end

function Systems.teardown(state)
    if state.uiInput then
        reset_ui_input(state)
        state.uiInput = nil
    end

    state.spawnerSystem = nil
    state.enemySpawnerSystem = nil
    state.proceduralShipSpawnerSystem = nil
    state.stationSpawnerSystem = nil
    state.warpgateSpawnerSystem = nil
    state.movementSystem = nil
    state.pickupSystem = nil
    state.renderSystem = nil
    state.weaponUnifiedSystem = nil
    state.weaponBeamVFXSystem = nil
    if state.projectileSystem and state.projectileSystem.detachPhysicsCallbacks then
        state.projectileSystem:detachPhysicsCallbacks()
    end
    state.projectileSystem = nil
    if state.collisionImpactSystem and state.collisionImpactSystem.detachPhysicsCallbacks then
        state.collisionImpactSystem:detachPhysicsCallbacks()
    end
    state.collisionImpactSystem = nil
    state.lootDropSystem = nil
    state.enemyBehaviorSystem = nil
    state.targetingSystem = nil
    state.hudSystem = nil
    state.uiSystem = nil
    state.damageEntity = nil
    state.destructionSystem = nil

    state.world = nil
end

return Systems
