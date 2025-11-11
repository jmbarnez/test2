---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local Intent = require("src.input.intent")
local createLocalInputSystem = require("src.systems.input_local")
local createMovementSystem = require("src.systems.movement")
local createRenderSystem = require("src.renderers.render")
local createPlayerControlSystem = require("src.systems.player_control")
local createAsteroidSpawner = require("src.spawners.asteroid")
local createEnemySpawner = require("src.spawners.enemy")
local createEnemyAISystem = require("src.systems.enemy_ai")
local createWeaponSystem = require("src.systems.weapon_fire")
local createProjectileSystem = require("src.systems.projectile")
local createShipSystem = require("src.systems.ship")
local createHudSystem = require("src.systems.hud")
local createUiSystem = require("src.systems.ui")
local createTargetingSystem = require("src.systems.targeting")
local createDestructionSystem = require("src.systems.destruction")
local createLootDropSystem = require("src.systems.loot_drop")
local createPickupSystem = require("src.systems.pickup")
local Entities = require("src.states.gameplay.entities")

local Systems = {}

local function ensure_world(state)
    if not state.world then
        state.world = tiny.world()
    end
    Intent.ensureContainer(state)
end

local function add_common_systems(state)
    state.movementSystem = state.world:addSystem(createMovementSystem())
    state.pickupSystem = state.world:addSystem(createPickupSystem({
        state = state,
    }))
    state.weaponSystem = state.world:addSystem(createWeaponSystem(state))
    state.shipSystem = state.world:addSystem(createShipSystem(state))
    state.projectileSystem = state.world:addSystem(createProjectileSystem(state))
    state.lootDropSystem = state.world:addSystem(createLootDropSystem({
        state = state,
        spawnLootItem = function(drop)
            return Entities.spawnLootPickup(state, drop)
        end,
    }))
    state.destructionSystem = state.world:addSystem(createDestructionSystem(state))
end

function Systems.initialize(state, damageCallback)
    ensure_world(state)

    state.uiInput = {
        mouseCaptured = false,
        keyboardCaptured = false,
    }

    if damageCallback then
        state.damageEntity = damageCallback
    end

    state.inputSystem = state.world:addSystem(createLocalInputSystem({
        state = state,
        camera = state.camera,
        uiInput = state.uiInput,
    }))

    state.controlSystem = state.world:addSystem(createPlayerControlSystem({
        camera = state.camera,
        engineTrail = state.engineTrail,
        uiInput = state.uiInput,
        intentHolder = state,
    }))

    state.spawnerSystem = state.world:addSystem(createAsteroidSpawner(state))
    state.enemySpawnerSystem = state.world:addSystem(createEnemySpawner(state))

    add_common_systems(state)

    state.enemyAISystem = state.world:addSystem(createEnemyAISystem(state))

    state.renderSystem = state.world:addSystem(createRenderSystem(state))
    state.targetingSystem = state.world:addSystem(createTargetingSystem({
        state = state,
        camera = state.camera,
        uiInput = state.uiInput,
    }))
    state.hudSystem = state.world:addSystem(createHudSystem(state))
    state.uiSystem = state.world:addSystem(createUiSystem(state))
end

function Systems.teardown(state)
    state.controlSystem = nil
    state.spawnerSystem = nil
    state.enemySpawnerSystem = nil
    state.movementSystem = nil
    state.pickupSystem = nil
    state.renderSystem = nil
    state.weaponSystem = nil
    state.projectileSystem = nil
    state.lootDropSystem = nil
    state.enemyAISystem = nil
    state.targetingSystem = nil
    state.hudSystem = nil
    state.uiSystem = nil
    state.damageEntity = nil
    state.destructionSystem = nil

    state.world = nil
end

return Systems
