--- Main game state for Novus
-- Manages the game world, entities, and systems
-- Handles entity creation, world initialization, and system updates
-- Uses tiny-ecs for entity-component-system architecture

---@diagnostic disable: undefined-global

-- ============================================================================
-- Dependencies
-- ============================================================================

local constants = require("src.constants.game")
local UIStateManager = require("src.ui.state_manager")
local PlayerManager = require("src.player.manager")
local PhysicsCallbacks = require("src.states.gameplay.physics_callbacks")

-- Core gameplay modules
local Entities = require("src.states.gameplay.entities")
local Metrics = require("src.states.gameplay.metrics")
local Docking = require("src.states.gameplay.docking")
local Targeting = require("src.states.gameplay.targeting")
local PlayerLifecycle = require("src.states.gameplay.player")
local View = require("src.states.gameplay.view")
local Input = require("src.states.gameplay.input")
local FloatingText = require("src.effects.floating_text")
local Lifecycle = require("src.states.gameplay.lifecycle")

local love = love

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
    Lifecycle.enter(self, config)
end

function gameplay:leave()
    Lifecycle.leave(self)
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
    local world = self.world
    local simulatedTime = 0
    if physicsWorld and world then
        local FIXED_DT = constants.physics.fixed_timestep or (1 / 60)
        local MAX_STEPS = constants.physics.max_steps or 4

        self.physicsAccumulator = (self.physicsAccumulator or 0) + dt

        local steps = 0
        while self.physicsAccumulator >= FIXED_DT and steps < MAX_STEPS do
            physicsWorld:update(FIXED_DT)
            world:update(FIXED_DT)
            self.physicsAccumulator = self.physicsAccumulator - FIXED_DT
            steps = steps + 1
        end

        if steps > 0 then
            simulatedTime = steps * FIXED_DT
        end

        -- Cap accumulator to prevent spiral of death
        if self.physicsAccumulator > FIXED_DT * MAX_STEPS then
            self.physicsAccumulator = 0
        end
    elseif world then
        -- No physics world available; fall back to variable timestep updates
        world:update(dt)
        simulatedTime = dt
    end

    -- Update game subsystems
    Docking.updateState(self)

    if self.engineTrail then
        self.engineTrail:update(dt)
    end

    FloatingText.update(self, dt)
    if simulatedTime > 0 then
        Entities.updateHealthTimers(world, simulatedTime)
    elseif not physicsWorld then
        Entities.updateHealthTimers(world, dt)
    end
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
