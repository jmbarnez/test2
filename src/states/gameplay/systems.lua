---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local createMovementSystem = require("src.systems.movement")
local createRenderSystem = require("src.systems.render")
local createPlayerControlSystem = require("src.systems.player_control")
local createAsteroidSpawner = require("src.systems.asteroid_spawner")
local createEnemySpawner = require("src.systems.enemy_spawner")
local createEnemyAISystem = require("src.systems.enemy_ai")
local createWeaponSystem = require("src.systems.weapon_fire")
local createProjectileSystem = require("src.systems.projectile")
local createHudSystem = require("src.systems.hud")
local createDestructionSystem = require("src.systems.destruction")

local Systems = {}

function Systems.initialize(state, damageCallback)
    state.world = tiny.world()

    if damageCallback then
        state.damageEntity = damageCallback
    end

    state.controlSystem = state.world:addSystem(createPlayerControlSystem(state))
    state.spawnerSystem = state.world:addSystem(createAsteroidSpawner(state))
    state.enemySpawnerSystem = state.world:addSystem(createEnemySpawner(state))

    state.movementSystem = state.world:addSystem(createMovementSystem())
    tiny.deactivate(state.movementSystem)

    state.renderSystem = state.world:addSystem(createRenderSystem(state))
    state.weaponSystem = state.world:addSystem(createWeaponSystem(state))
    state.projectileSystem = state.world:addSystem(createProjectileSystem(state))
    state.enemyAISystem = state.world:addSystem(createEnemyAISystem(state))
    state.hudSystem = state.world:addSystem(createHudSystem(state))
    state.destructionSystem = state.world:addSystem(createDestructionSystem(state))
end

function Systems.teardown(state)
    state.controlSystem = nil
    state.spawnerSystem = nil
    state.enemySpawnerSystem = nil
    state.movementSystem = nil
    state.renderSystem = nil
    state.weaponSystem = nil
    state.projectileSystem = nil
    state.enemyAISystem = nil
    state.hudSystem = nil
    state.damageEntity = nil

    state.world = nil
end

return Systems
