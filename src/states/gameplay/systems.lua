local UIStateManager = require("src.ui.state_manager")
---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local Intent = require("src.input.intent")
local createLocalInputSystem = require("src.systems.input_local")
local createMovementSystem = require("src.systems.movement")
local createRenderSystem = require("src.renderers.render")
local createPlayerControlSystem = require("src.systems.player_control")
local createAsteroidSpawner = require("src.spawners.asteroid")
local createEnemySpawner = require("src.spawners.enemy")
local createStationSpawner = require("src.spawners.station")
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
local PlayerManager = require("src.player.manager")

local Systems = {}

local LOOT_DESTRUCTION_XP = {
    ["resource:hull_scrap"] = {
        category = "industry",
        skill = "salvaging",
        xp = 10,
    },
}

local function resolve_player_id_from_entity(entity)
    if not entity then
        return nil
    end

    if entity.lastDamagePlayerId then
        return entity.lastDamagePlayerId
    end

    local source = entity.lastDamageSource
    if type(source) == "table" then
        return source.playerId
            or source.ownerPlayerId
            or source.lastDamagePlayerId
    end

    return nil
end

local function resolve_loot_player_id(drop, sourceEntity)
    local playerId = resolve_player_id_from_entity(sourceEntity)
    if playerId then
        return playerId
    end

    if drop and type(drop.source) == "table" then
        return resolve_player_id_from_entity(drop.source)
            or drop.source.playerId
            or drop.source.ownerPlayerId
            or drop.source.lastDamagePlayerId
    end

    return nil
end

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
        onLootDropped = function(drop, entity)
            if not drop then
                return
            end

            local spec = LOOT_DESTRUCTION_XP[drop.id]
            if not spec then
                return
            end

            local playerId = resolve_loot_player_id(drop, entity)
            if not playerId then
                return
            end

            PlayerManager.addSkillXP(state, spec.category, spec.skill, spec.xp, playerId)
        end,
    }))
    state.destructionSystem = state.world:addSystem(createDestructionSystem(state))
end

function Systems.initialize(state, damageCallback)
    ensure_world(state)

    state.uiInput = state.uiInput or {}
    state.uiInput.mouseCaptured = false
    state.uiInput.keyboardCaptured = false

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
    state.stationSpawnerSystem = state.world:addSystem(createStationSpawner(state))

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
    if state.uiInput then
        state.uiInput.mouseCaptured = false
        state.uiInput.keyboardCaptured = false
        state.uiInput = nil
    end

    state.controlSystem = nil
    state.spawnerSystem = nil
    state.enemySpawnerSystem = nil
    state.stationSpawnerSystem = nil
    state.movementSystem = nil
    state.pickupSystem = nil
    state.renderSystem = nil
    state.weaponSystem = nil
    if state.projectileSystem and state.projectileSystem.detachPhysicsCallbacks then
        state.projectileSystem:detachPhysicsCallbacks()
    end
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
