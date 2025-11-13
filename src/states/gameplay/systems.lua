local UIStateManager = require("src.ui.state_manager")
---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local Intent = require("src.input.intent")
local GameContext = require("src.states.gameplay.context")
local createLocalInputSystem = require("src.systems.input_local")
local createMovementSystem = require("src.systems.movement")
local createRenderSystem = require("src.renderers.render")
local createPlayerControlSystem = require("src.systems.player_control")
local EngineTrailSystem = require("src.systems.engine_trail")
local createAsteroidSpawner = require("src.spawners.asteroid")
local createEnemySpawner = require("src.spawners.enemy")
local createStationSpawner = require("src.spawners.station")
local createEnemyAISystem = require("src.systems.enemy_ai")
local createWeaponSystem = require("src.systems.weapon_fire")
local createProjectileSystem = require("src.systems.projectile")
local createShipSystem = require("src.systems.ship")
local createAbilityModuleSystem = require("src.systems.ability_modules")
local createHudSystem = require("src.systems.hud")
local createUiSystem = require("src.systems.ui")
local createTargetingSystem = require("src.systems.targeting")
local createDestructionSystem = require("src.systems.destruction")
local createLootDropSystem = require("src.systems.loot_drop")
local FloatingText = require("src.effects.floating_text")
local createPickupSystem = require("src.systems.pickup")
local createParticleEffectsSystem = require("src.systems.particle_effects")
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

local function add_common_systems(state, context)
    state.movementSystem = state.world:addSystem(createMovementSystem())
    local sharedContext = context or GameContext.compose(state)
    state.pickupSystem = state.world:addSystem(createPickupSystem(GameContext.extend(sharedContext)))
    state.weaponSystem = state.world:addSystem(createWeaponSystem(GameContext.extend(sharedContext)))
    state.shipSystem = state.world:addSystem(createShipSystem(GameContext.extend(sharedContext)))
    state.abilitySystem = state.world:addSystem(createAbilityModuleSystem(GameContext.extend(sharedContext)))
    state.projectileSystem = state.world:addSystem(createProjectileSystem(GameContext.extend(sharedContext)))
    state.lootDropSystem = state.world:addSystem(createLootDropSystem(GameContext.extend(sharedContext, {
        spawnLootItem = function(drop)
            return Entities.spawnLootPickup(state, drop)
        end,
        onLootDropped = function(drop, entity)
            if not drop then
                return
            end

            local spec = LOOT_DESTRUCTION_XP[drop.id]
            if spec then
                local playerId = resolve_loot_player_id(drop, entity)
                if playerId then
                    PlayerManager.addSkillXP(state, spec.category, spec.skill, spec.xp, playerId)
                end
            end

            local credits = drop.credit_reward or (drop.raw and drop.raw.credit_reward)
            if type(credits) ~= "number" or credits <= 0 then
                return
            end

            local localPlayer = PlayerManager.getLocalPlayer(state)
            if not localPlayer then
                return
            end

            PlayerManager.adjustCurrency(state, credits)

            local position
            if drop.position then
                position = drop.position
            elseif entity and entity.position then
                position = entity.position
            else
                position = localPlayer.position
            end

            if not (position and FloatingText and FloatingText.add) then
                return
            end

            FloatingText.add(state, position, nil, {
                amount = credits,
                offsetY = (localPlayer and localPlayer.mountRadius or 36) + 18,
                color = { 0.8, 0.95, 0.3, 1 },
                rise = 40,
                scale = 1.1,
            })
        end,
    })))
    state.destructionSystem = state.world:addSystem(createDestructionSystem(GameContext.extend(sharedContext)))
end

function Systems.initialize(state, damageCallback)
    ensure_world(state)

    state.uiInput = state.uiInput or {}
    state.uiInput.mouseCaptured = false
    state.uiInput.keyboardCaptured = false

    local baseContext = GameContext.compose(state, {
        damageEntity = damageCallback or state.damageEntity,
    })

    state.damageEntity = baseContext.damageEntity

    state.inputSystem = state.world:addSystem(createLocalInputSystem(GameContext.extend(baseContext, {
        camera = state.camera,
        uiInput = state.uiInput,
    })))

    state.controlSystem = state.world:addSystem(createPlayerControlSystem(GameContext.extend(baseContext, {
        camera = state.camera,
        engineTrail = state.engineTrail,
        uiInput = state.uiInput,
        intentHolder = state,
    })))

    state.spawnerSystem = state.world:addSystem(createAsteroidSpawner(baseContext))
    state.enemySpawnerSystem = state.world:addSystem(createEnemySpawner(baseContext))
    state.stationSpawnerSystem = state.world:addSystem(createStationSpawner(baseContext))

    add_common_systems(state, baseContext)

    state.enemyAISystem = state.world:addSystem(createEnemyAISystem(baseContext))

    state.engineTrailSystem = state.world:addSystem(EngineTrailSystem)
    state.renderSystem = state.world:addSystem(createRenderSystem(baseContext))
    state.particleEffectsSystem = state.world:addSystem(createParticleEffectsSystem(GameContext.extend(baseContext, {
        projectileSystem = state.projectileSystem,
        weaponFireSystem = state.weaponSystem,
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
