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
local createDestructionSystem = require("src.systems.destruction")

local Systems = {}

function Systems.initialize(state, damageCallback)
    state.world = tiny.world()

    Intent.ensureContainer(state)

    state.uiInput = {
        mouseCaptured = false,
        keyboardCaptured = false,
    }

    local constants = require("src.constants.game")
    local defaultAddress = string.format(
        "%s:%d",
        (state.networkManager and state.networkManager.host) or constants.network.host,
        (state.networkManager and state.networkManager.port) or constants.network.port
    )
    local defaultName = state.localPlayerName or "Player"

    if not state.multiplayerUI then
        state.multiplayerUI = {
            visible = false,
            status = "",
            addressInput = defaultAddress,
            nameInput = defaultName,
            activeInput = nil,
            inputActive = false,
        }
    else
        if not state.multiplayerUI.addressInput or state.multiplayerUI.addressInput == "" then
            state.multiplayerUI.addressInput = defaultAddress
        end
        if not state.multiplayerUI.nameInput or state.multiplayerUI.nameInput == "" then
            state.multiplayerUI.nameInput = defaultName
        end
        state.multiplayerUI.activeInput = state.multiplayerUI.activeInput or nil
        state.multiplayerUI.inputActive = state.multiplayerUI.inputActive or false
    end

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

    state.movementSystem = state.world:addSystem(createMovementSystem())

    state.renderSystem = state.world:addSystem(createRenderSystem(state))
    state.weaponSystem = state.world:addSystem(createWeaponSystem(state))
    state.shipSystem = state.world:addSystem(createShipSystem(state))
    state.projectileSystem = state.world:addSystem(createProjectileSystem(state))
    state.enemyAISystem = state.world:addSystem(createEnemyAISystem(state))
    state.hudSystem = state.world:addSystem(createHudSystem(state))
    state.uiSystem = state.world:addSystem(createUiSystem(state))
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
    state.uiSystem = nil
    state.damageEntity = nil

    state.world = nil
end

return Systems
