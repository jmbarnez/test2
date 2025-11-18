local SaveLoad = require("src.util.save_load")
local Universe = require("src.states.gameplay.universe")
local UIStateManager = require("src.ui.state_manager")
local FloatingText = require("src.effects.floating_text")
local EngineTrail = require("src.effects.engine_trail")
local World = require("src.states.gameplay.world")
local PhysicsCallbacks = require("src.states.gameplay.physics_callbacks")
local View = require("src.states.gameplay.view")
local Systems = require("src.states.gameplay.systems")
local Entities = require("src.states.gameplay.entities")
local PlayerLifecycle = require("src.states.gameplay.player")
local AudioManager = require("src.audio.manager")
local PlayerManager = require("src.player.manager")
local OptionsData = require("src.settings.options_data")
local Bindings = require("src.input.bindings")

-- Factories (side-effect registration)
require("src.entities.ship_factory")
require("src.entities.asteroid_factory")
require("src.entities.weapon_factory")
require("src.entities.station_factory")
require("src.entities.warpgate_factory")

local love = love

local Lifecycle = {}

local function resolve_sector_id(config)
    if type(config) == "table" then
        return config.sectorId or config.sector
    elseif type(config) == "string" then
        return config
    end
    return nil
end

local function preload_save_data(state, config)
    if not (config and config.loadGame) then
        state.skipProceduralSpawns = nil
        return nil
    end

    local saveData, err = SaveLoad.loadSaveData()
    if saveData then
        if saveData.universe and saveData.universe.seed then
            state.universeSeed = saveData.universe.seed
        end
        if saveData.sector then
            config.sectorId = saveData.sector
        end
        state.skipProceduralSpawns = true
        return saveData
    end

    print("[SaveLoad] Failed to preload save: " .. tostring(err))
    state.skipProceduralSpawns = nil
    return nil
end

local function ensure_universe_seed(state)
    if state.universeSeed then
        return
    end

    local maxSeed = 0x7fffffff
    state.universeSeed = love.math.random(0, maxSeed)
end

local function generate_universe(state)
    local prevSeed1, prevSeed2 = love.math.getRandomSeed()
    love.math.setRandomSeed(state.universeSeed, state.universeSeed)

    state.universe = Universe.generate({
        galaxy_count = 3,
        sectors_per_galaxy = { min = 10, max = 18 },
    })

    if prevSeed1 then
        love.math.setRandomSeed(prevSeed1, prevSeed2)
    end
end

local function initialize_subsystems(state, sectorId)
    UIStateManager.initialize(state)

    state.optionsUI = state.optionsUI or {}
    local settings = OptionsData.ensure(state.optionsUI, state)
    if settings and settings.keybindings then
        Bindings.applyExternalOverrides(settings.keybindings)
    end

    state.performanceStatsRecords = {}
    state.performanceStats = {}

    FloatingText.setFallback(state)
    FloatingText.clear(state)

    state.engineTrail = EngineTrail.new()

    World.loadSector(state, sectorId)
    World.initialize(state)
    PhysicsCallbacks.ensureRouter(state)
    View.initialize(state)
    state.activeTarget = nil
    Systems.initialize(state, Entities.damage)
end

local function restore_or_spawn_player(state, pendingSaveData)
    local restoredFromSave = false

    if pendingSaveData then
        -- Pass skipClear=true since we just initialized fresh subsystems in initialize_subsystems()
        -- and haven't spawned anything yet
        local ok, err = SaveLoad.loadGame(state, pendingSaveData, true)
        if not ok then
            print("[SaveLoad] Failed to load save data: " .. tostring(err))
            state.skipProceduralSpawns = nil
        else
            restoredFromSave = true
            -- skipProceduralSpawns stays true and will be cleared after first update
        end
    end

    if restoredFromSave then
        return
    end

    -- Clear the flag since we're spawning a new player (not loading)
    state.skipProceduralSpawns = nil
    
    local player = Entities.spawnPlayer(state)
    if player then
        if state.engineTrail then
            state.engineTrail:attachPlayer(player)
        end
        PlayerLifecycle.registerCallbacks(state, player)
    end
end

function Lifecycle.enter(state, config)
    config = config or {}

    local pendingSaveData = preload_save_data(state, config)

    ensure_universe_seed(state)

    local sectorId = resolve_sector_id(config)
    state.currentSectorId = sectorId or state.currentSectorId

    generate_universe(state)

    initialize_subsystems(state, sectorId)

    AudioManager.play_music("music:adrift", { loop = true, restart = true })

    restore_or_spawn_player(state, pendingSaveData)

    View.updateCamera(state)
end

function Lifecycle.leave(state)
    PlayerManager.clearShip(state)
    Entities.destroyWorldEntities(state.world)
    state.activeTarget = nil
    Systems.teardown(state)
    PhysicsCallbacks.clear(state)
    World.teardown(state)
    View.teardown(state)

    AudioManager.stop_music()

    if state.engineTrail then
        state.engineTrail:clear()
        state.engineTrail = nil
    end

    FloatingText.clear(state)
    FloatingText.setFallback(nil)

    UIStateManager.cleanup(state)

    state.performanceStatsRecords = nil
    state.performanceStats = nil
end

return Lifecycle
