--- Main game state for Novus
-- Manages the game world, entities, and systems
-- Handles entity creation, world initialization, and system updates
-- Uses tiny-ecs for entity-component-system architecture

---@diagnostic disable: undefined-global

-- ============================================================================
-- Dependencies
-- ============================================================================

local constants = require("src.constants.game")
local AudioManager = require("src.audio.manager")
local PlayerManager = require("src.player.manager")
local PlayerWeapons = require("src.player.weapons")
local UIStateManager = require("src.ui.state_manager")
local SaveLoad = require("src.util.save_load")

-- Input system
local InputMapper = require("src.input.mapper")
local Intent = require("src.input.intent")

-- UI Windows

-- Core gameplay modules
local World = require("src.states.gameplay.world")
local Entities = require("src.states.gameplay.entities")
local Systems = require("src.states.gameplay.systems")
local View = require("src.states.gameplay.view")
local Universe = require("src.states.gameplay.universe")
local Metrics = require("src.states.gameplay.metrics")
local PhysicsCallbacks = require("src.states.gameplay.physics_callbacks")
local Docking = require("src.states.gameplay.docking")
local Targeting = require("src.states.gameplay.targeting")
local PlayerLifecycle = require("src.states.gameplay.player")
local Feedback = require("src.states.gameplay.feedback")
local Input = require("src.states.gameplay.input")

-- Effects
local EngineTrail = require("src.effects.engine_trail")
local FloatingText = require("src.effects.floating_text")

-- Factories
local ShipRuntime = require("src.ships.runtime")
require("src.entities.ship_factory")
require("src.entities.asteroid_factory")
require("src.entities.weapon_factory")
require("src.entities.station_factory")
require("src.entities.warpgate_factory")

local love = love

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function resolveSectorId(config)
    if type(config) == "table" then
        return config.sectorId or config.sector
    elseif type(config) == "string" then
        return config
    end
    return nil
end

-- ============================================================================
-- Main Gameplay State
-- ============================================================================

local gameplay = {}

-- ============================================================================
-- Physics Callback System (Delegated)
-- ============================================================================

function gameplay:registerPhysicsCallback(phase, handler)
    return PhysicsCallbacks.register(self, phase, handler)
end

function gameplay:unregisterPhysicsCallback(phase, handler)
    PhysicsCallbacks.unregister(self, phase, handler)
end

function gameplay:getLocalPlayer()
    return PlayerManager.getLocalPlayer(self)
end

-- ============================================================================
-- State Lifecycle
-- ============================================================================

--[[
    Entering gameplay now has two distinct flows:
      1. Fresh games generate a brand-new deterministic universe seed.
      2. Load requests prefetch save data so we can restore the saved seed and
         sector before Universe.generate runs.  This guarantees the exact same
         layout and procedural spawns, and lets spawner systems know they must
         skip their runtime generation pass.
]]
function gameplay:enter(_, config)
    config = config or {}

    local pendingSaveData
    if config.loadGame then
        local saveData, err = SaveLoad.loadSaveData()
        if saveData then
            pendingSaveData = saveData
            if saveData.universe and saveData.universe.seed then
                self.universeSeed = saveData.universe.seed
            end
            if saveData.sector then
                config.sectorId = saveData.sector
            end
            self.skipProceduralSpawns = true
        else
            print("[SaveLoad] Failed to preload save: " .. tostring(err))
            self.skipProceduralSpawns = nil
        end
    else
        self.skipProceduralSpawns = nil
    end

    if not self.universeSeed then
        local maxSeed = 0x7fffffff
        self.universeSeed = love.math.random(0, maxSeed)
    end

    local sectorId = resolveSectorId(config)
    self.currentSectorId = sectorId or self.currentSectorId

    local prevSeed1, prevSeed2 = love.math.getRandomSeed()
    love.math.setRandomSeed(self.universeSeed, self.universeSeed)

    self.universe = Universe.generate({
        galaxy_count = 3,
        sectors_per_galaxy = { min = 10, max = 18 },
    })

    if prevSeed1 then
        love.math.setRandomSeed(prevSeed1, prevSeed2)
    end

    -- Initialize subsystems
    UIStateManager.initialize(self)
    
    self.performanceStatsRecords = {}
    self.performanceStats = {}

    FloatingText.setFallback(self)
    FloatingText.clear(self)
    
    self.engineTrail = EngineTrail.new()

    World.loadSector(self, sectorId)
    World.initialize(self)
    PhysicsCallbacks.ensureRouter(self)
    View.initialize(self)
    self.activeTarget = nil
    Systems.initialize(self, Entities.damage)

    AudioManager.play_music("music:adrift", { loop = true, restart = true })

    local restoredFromSave = false
    if pendingSaveData then
        local ok, err = SaveLoad.loadGame(self, pendingSaveData)
        if not ok then
            print("[SaveLoad] Failed to load save data: " .. tostring(err))
            self.skipProceduralSpawns = nil
        else
            restoredFromSave = true
        end
    end

    -- Spawn and setup player
    if not restoredFromSave then
        local player = Entities.spawnPlayer(self)
        if player then
            if self.engineTrail then
                self.engineTrail:attachPlayer(player)
            end
            PlayerLifecycle.registerCallbacks(self, player)
        end
    end
    
    View.updateCamera(self)
end

function gameplay:leave()
    PlayerManager.clearShip(self)
    Entities.destroyWorldEntities(self.world)
    self.activeTarget = nil
    Systems.teardown(self)
    PhysicsCallbacks.clear(self)
    World.teardown(self)
    View.teardown(self)

    AudioManager.stop_music()

    if self.engineTrail then
        self.engineTrail:clear()
        self.engineTrail = nil
    end

    FloatingText.clear(self)
    FloatingText.setFallback(nil)
    
    UIStateManager.cleanup(self)

    self.performanceStatsRecords = nil
    self.performanceStats = nil
end

-- ============================================================================
-- Update Loop
-- ============================================================================

function gameplay:update(dt)
    if not self.world then
        return
    end

    local updateStart = Metrics.beginUpdate(self, dt)

    -- Handle respawn request
    if UIStateManager.isRespawnRequested(self) then
        PlayerLifecycle.respawn(self)
    end

    -- Update target locking
    Targeting.update(self, dt)

    -- Skip update if paused
    if UIStateManager.isPaused(self) then
        Metrics.finalizeUpdate(self, updateStart)
        return
    end

    -- Fixed timestep physics for deterministic simulation
    -- Physics MUST update BEFORE world systems to ensure systems read fresh state
    local physicsWorld = self.physicsWorld
    if physicsWorld then
        local FIXED_DT = constants.physics.fixed_timestep or (1/60)
        local MAX_STEPS = constants.physics.max_steps or 4
        
        self.physicsAccumulator = (self.physicsAccumulator or 0) + dt
        
        local steps = 0
        while self.physicsAccumulator >= FIXED_DT and steps < MAX_STEPS do
            physicsWorld:update(FIXED_DT)
            self.physicsAccumulator = self.physicsAccumulator - FIXED_DT
            steps = steps + 1
        end
        
        -- Cap accumulator to prevent spiral of death
        if self.physicsAccumulator > FIXED_DT * MAX_STEPS then
            self.physicsAccumulator = 0
        end
    end

    -- Update ECS systems (reads freshly updated physics state)
    self.world:update(dt)

    -- Update game subsystems
    Docking.updateState(self)

    if self.engineTrail then
        self.engineTrail:update(dt)
    end

    FloatingText.update(self, dt)
    Entities.updateHealthTimers(self.world, dt)
    View.updateCamera(self)

    Metrics.finalizeUpdate(self, updateStart)
end

-- ============================================================================
-- Render Loop
-- ============================================================================

function gameplay:draw()
    if not (self.world and self.renderSystem) then
        return
    end

    local renderStart = Metrics.beginRender(self)

    -- Clear screen
    local clearColor = constants.render.clear_color or { 0, 0, 0, 1 }
    love.graphics.clear(clearColor[1] or 0, clearColor[2] or 0, clearColor[3] or 0, clearColor[4] or 1)

    -- Draw background
    View.drawBackground(self)

    -- Draw world with camera transform
    local cam = self.camera
    love.graphics.push("all")
    local zoom = cam and cam.zoom or 1
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-(cam and cam.x or 0), -(cam and cam.y or 0))
    
    if self.engineTrail then
        self.engineTrail:draw()
    end
    
    self.world:draw()
    FloatingText.draw(self)
    
    -- Safe pop (handle potential stack underflow)
    local stack_depth = love.graphics.getStackDepth and love.graphics.getStackDepth() or nil
    if not stack_depth or stack_depth > 1 then
        love.graphics.pop()
    end

    Metrics.finalizeRender(self, renderStart)
end

-- ============================================================================
-- Input Handlers
-- ============================================================================

function gameplay:wheelmoved(x, y)
    Input.wheelmoved(self, x, y)
end

function gameplay:mousepressed(x, y, button, istouch, presses)
    Input.mousepressed(self, x, y, button, istouch, presses)
end

function gameplay:mousereleased(x, y, button, istouch, presses)
    Input.mousereleased(self, x, y, button, istouch, presses)
end

function gameplay:textinput(text)
    Input.textinput(self, text)
end

function gameplay:keypressed(key, scancode, isrepeat)
    Input.keypressed(self, key, scancode, isrepeat)
end

-- ============================================================================
-- Window Events
-- ============================================================================

function gameplay:resize(w, h)
    View.resize(self, w, h)
    UIStateManager.onResize(self, w, h)
    View.updateCamera(self)
end

function gameplay:updateCamera()
    View.updateCamera(self)
end

return gameplay
