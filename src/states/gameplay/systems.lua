local UIStateManager = require("src.ui.state_manager")
---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local GameContext = require("src.states.gameplay.context")
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
local createEffectsRendererSystem = require("src.systems.effects_renderer")
local Entities = require("src.states.gameplay.entities")
local LootRewards = require("src.player.loot_rewards")

local Systems = {}

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
    state.pickupSystem = state.world:addSystem(createPickupSystem(GameContext.extend(sharedContext)))

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
