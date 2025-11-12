--- Main game state for Novus
-- Manages the game world, entities, and systems
-- Handles entity creation, world initialization, and system updates
-- Uses tiny-ecs for entity-component-system architecture

---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
local AudioManager = require("src.audio.manager")
local PlayerManager = require("src.player.manager")
local PlayerWeapons = require("src.player.weapons")
local UIStateManager = require("src.ui.state_manager")
local cargo_window = require("src.ui.windows.cargo")
local options_window = require("src.ui.windows.options")
local map_window = require("src.ui.windows.map")
local debug_window = require("src.ui.windows.debug")
require("src.entities.ship_factory")
require("src.entities.asteroid_factory")
require("src.entities.weapon_factory")
require("src.entities.station_factory")
local World = require("src.states.gameplay.world")
local Entities = require("src.states.gameplay.entities")
local Systems = require("src.states.gameplay.systems")
local View = require("src.states.gameplay.view")
local EngineTrail = require("src.effects.engine_trail")
local FloatingText = require("src.effects.floating_text")

local love = love

local SAMPLE_WINDOW = 120

local function get_time()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return nil
end

local function record_metric(container, key, value)
    if not container or type(value) ~= "number" then
        return
    end

    local bucket = container[key]
    if not bucket then
        bucket = {
            values = {},
            cursor = 1,
            count = 0,
            sum = 0,
            window = SAMPLE_WINDOW,
        }
        container[key] = bucket
    end

    local window = bucket.window or SAMPLE_WINDOW
    local cursor = bucket.cursor or 1

    if bucket.count < window then
        bucket.count = bucket.count + 1
    else
        local old = bucket.values[cursor]
        if old then
            bucket.sum = bucket.sum - old
        end
    end

    bucket.values[cursor] = value
    bucket.sum = (bucket.sum or 0) + value
    bucket.last = value

    if bucket.count > 0 then
        bucket.avg = bucket.sum / bucket.count
    else
        bucket.avg = value
    end

    local minValue, maxValue = value, value
    for i = 1, bucket.count do
        local sample = bucket.values[i]
        if sample then
            if sample < minValue then
                minValue = sample
            end
            if sample > maxValue then
                maxValue = sample
            end
        end
    end

    bucket.min = minValue
    bucket.max = maxValue
    bucket.cursor = (cursor % window) + 1
end

local gameplay = {}

local function resolveSectorId(config)
    if type(config) == "table" then
        return config.sectorId or config.sector
    elseif type(config) == "string" then
        return config
    end

    return nil
end

local CONTROL_KEYS = { "lctrl", "rctrl" }

local function is_control_modifier_active()
    if not (love and love.keyboard and love.keyboard.isDown) then
        return false
    end

    for i = 1, #CONTROL_KEYS do
        local key = CONTROL_KEYS[i]
        ---@cast key love.KeyboardConstant
        if love.keyboard.isDown(key) then
            return true
        end
    end

    return false
end

local VALID_PHYSICS_CALLBACK_PHASES = {
    beginContact = true,
    endContact = true,
    preSolve = true,
    postSolve = true,
}

function gameplay:ensurePhysicsCallbackRouter()
    local physicsWorld = self.physicsWorld
    if not physicsWorld then
        return
    end

    if not self.physicsCallbackLists then
        self.physicsCallbackLists = {
            beginContact = {},
            endContact = {},
            preSolve = {},
            postSolve = {},
        }
    end

    if not self._physicsCallbackRouter then
        local function forward(phase)
            return function(...)
                local lists = self.physicsCallbackLists
                if not lists then
                    return
                end

                local handlers = lists[phase]
                if not handlers then
                    return
                end

                for i = 1, #handlers do
                    local handler = handlers[i]
                    if handler then
                        handler(...)
                    end
                end
            end
        end

        self._physicsCallbackRouter = {
            beginContact = forward("beginContact"),
            endContact = forward("endContact"),
            preSolve = forward("preSolve"),
            postSolve = forward("postSolve"),
        }
    end

    physicsWorld:setCallbacks(
        self._physicsCallbackRouter.beginContact,
        self._physicsCallbackRouter.endContact,
        self._physicsCallbackRouter.preSolve,
        self._physicsCallbackRouter.postSolve
    )
end

function gameplay:registerPhysicsCallback(phase, handler)
    if not VALID_PHYSICS_CALLBACK_PHASES[phase] then
        error(string.format("Invalid physics callback phase '%s'", tostring(phase)))
    end

    if type(handler) ~= "function" then
        error("Physics callback handler must be a function")
    end

    if not self.physicsWorld then
        return function() end
    end

    self:ensurePhysicsCallbackRouter()

    local list = self.physicsCallbackLists[phase]
    list[#list + 1] = handler

    return function()
        self:unregisterPhysicsCallback(phase, handler)
    end
end

function gameplay:unregisterPhysicsCallback(phase, handler)
    local lists = self.physicsCallbackLists
    if not (lists and VALID_PHYSICS_CALLBACK_PHASES[phase]) then
        return
    end

    local handlers = lists[phase]
    if not handlers then
        return
    end

    for i = #handlers, 1, -1 do
        if handlers[i] == handler then
            table.remove(handlers, i)
            break
        end
    end
end

function gameplay:clearPhysicsCallbacks()
    if self.physicsWorld then
        self.physicsWorld:setCallbacks()
    end

    self.physicsCallbackLists = nil
    self._physicsCallbackRouter = nil
end

function gameplay:wheelmoved(x, y)
    if UIStateManager.isOptionsUIVisible(self) then
        if options_window.wheelmoved(self, x, y) then
            return
        end
    end

    if UIStateManager.isMapUIVisible(self) then
        if map_window.wheelmoved(self, x, y) then
            return
        end
    end

    if UIStateManager.isDebugUIVisible(self) then
        if debug_window.wheelmoved(self, x, y) then
            return
        end
    end

    cargo_window.wheelmoved(self, x, y)

    if not y or y == 0 then
        return
    end

    if self.uiInput and self.uiInput.mouseCaptured then
        return
    end

    local cam = self.camera
    if not cam then
        return
    end

    local currentZoom = cam.zoom or 1
    local zoomStep = 0.1
    local desiredZoom = currentZoom + y * zoomStep
    local clampedZoom = math.max(0.5, math.min(2, desiredZoom))

    if math.abs(clampedZoom - currentZoom) < 1e-4 then
        return
    end

    cam.zoom = clampedZoom
    View.updateCamera(self)
end

function gameplay:getLocalPlayer()
    return PlayerManager.getLocalPlayer(self)
end

function gameplay:enter(_, config)
    local sectorId = resolveSectorId(config)
    self.currentSectorId = sectorId or self.currentSectorId

    -- Initialize UI state
    UIStateManager.initialize(self)

    FloatingText.setFallback(self)
    FloatingText.clear(self)
    
    -- Initialize engine trail
    self.engineTrail = EngineTrail.new()

    World.loadSector(self, sectorId)
    World.initialize(self)
    self:ensurePhysicsCallbackRouter()
    View.initialize(self)
    self.activeTarget = nil
    Systems.initialize(self, Entities.damage)

    AudioManager.play_music("music:adrift", { loop = true, restart = true })

    local player = Entities.spawnPlayer(self)
    if player then
        local engineTrail = self.engineTrail
        if engineTrail then
            engineTrail:attachPlayer(player)
        end
        self:registerPlayerCallbacks(player)
    end
    View.updateCamera(self)
end

function gameplay:leave()
    PlayerManager.clearShip(self)
    Entities.destroyWorldEntities(self.world)
    self.activeTarget = nil
    Systems.teardown(self)
    self:clearPhysicsCallbacks()
    World.teardown(self)
    View.teardown(self)

    AudioManager.stop_music()

    if self.engineTrail then
        self.engineTrail:clear()
        self.engineTrail = nil
    end

    FloatingText.clear(self)
    FloatingText.setFallback(nil)
    
    -- Clean up UI state
    UIStateManager.cleanup(self)
end

function gameplay:update(dt)
    if not self.world then
        return
    end

    if self._pendingCameraRefresh then
        View.updateCamera(self)
        self._pendingCameraRefresh = nil
    end

    if UIStateManager.isRespawnRequested(self) then
        self:respawnPlayer()
    end

    if UIStateManager.isPaused(self) then
        return
    end

    -- Fixed timestep physics for deterministic multiplayer
    -- MUST update physics BEFORE world systems so systems read fresh physics state
    -- Accumulate frame time and step physics in fixed increments
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
        
        -- Cap accumulator to prevent runaway accumulation
        if self.physicsAccumulator > FIXED_DT * MAX_STEPS then
            self.physicsAccumulator = 0
        end
    end

    -- Update ECS systems after physics (systems read freshly updated physics state)
    self.world:update(dt)

    if self.engineTrail then
        self.engineTrail:update(dt)
    end

    FloatingText.update(self, dt)

    Entities.updateHealthTimers(self.world, dt)

    View.updateCamera(self)
end

function gameplay:respawnPlayer()
    if not (self.world and self.physicsWorld) then
        return
    end

    local player = Entities.spawnPlayer(self)
    if not player then
        return
    end

    self:registerPlayerCallbacks(player)

    if self.engineTrail then
        self.engineTrail:clear()
        self.engineTrail:attachPlayer(player)
        self.engineTrail:setActive(false)
    end

    UIStateManager.hideDeathUI(self)
    UIStateManager.clearRespawnRequest(self)
    View.updateCamera(self)
end

function gameplay:registerPlayerCallbacks(player)
    if not player then
        return
    end

    -- Use PlayerManager to handle player registration
    PlayerManager.attachShip(self, player)

    local previousOnDestroyed = player.onDestroyed
    player.onDestroyed = function(entity, context)
        if type(previousOnDestroyed) == "function" then
            previousOnDestroyed(entity, context)
        end
        self:onPlayerDestroyed(entity)
    end
end

function gameplay:onPlayerDestroyed(entity)
    if not entity then
        return
    end

    PlayerManager.clearShip(self, entity)

    if self.engineTrail then
        self.engineTrail:setActive(false)
        self.engineTrail:attachPlayer(nil)
    end

    UIStateManager.showDeathUI(self)
    UIStateManager.clearRespawnRequest(self)
    View.updateCamera(self)
end

function gameplay:draw()
    if not (self.world and self.renderSystem) then
        return
    end

    if self._pendingCameraRefresh then
        View.updateCamera(self)
        self._pendingCameraRefresh = nil
    end

    local clearColor = constants.render.clear_color or { 0, 0, 0, 1 }
    local r = clearColor[1] or 0
    local g = clearColor[2] or 0
    local b = clearColor[3] or 0
    local a = clearColor[4] or 1

    love.graphics.clear(r, g, b, a)

    View.drawBackground(self)

    local cam = self.camera
    love.graphics.push("all")
    local zoom = cam.zoom or 1
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-cam.x, -cam.y)
    if self.engineTrail then
        self.engineTrail:draw()
    end
    self.world:draw()
    FloatingText.draw(self)
    love.graphics.pop()
end

function gameplay:resize(w, h)
    View.resize(self, w, h)
    UIStateManager.onResize(self, w, h)
    View.updateCamera(self)
end

function gameplay:updateCamera()
    View.updateCamera(self)
end

function gameplay:mousepressed(_, _, button)
    if button ~= 1 then
        return
    end

    if UIStateManager.isAnyUIVisible(self) then
        return
    end

    local uiInput = self.uiInput
    if uiInput and uiInput.mouseCaptured then
        return
    end

    if not is_control_modifier_active() then
        return
    end

    local cache = self.targetingCache
    local hovered = cache and cache.hoveredEntity or nil

    if hovered and hovered.enemy then
        if hovered ~= self.activeTarget then
            self.activeTarget = hovered
        else
            self.activeTarget = nil
        end
    else
        self.activeTarget = nil
    end

    if cache then
        cache.activeEntity = self.activeTarget
        cache.entity = self.activeTarget or cache.hoveredEntity
    end
end

function gameplay:keypressed(key)
    if cargo_window.keypressed(self, key) then
        return
    end

    if UIStateManager.isMapUIVisible(self) then
        if map_window.keypressed(self, key) then
            return
        end
    end

    if UIStateManager.isOptionsUIVisible(self) then
        if options_window.keypressed(self, key) then
            return
        end
    end

    if key == "f1" then
        if UIStateManager.isDebugUIVisible(self) then
            UIStateManager.hideDebugUI(self)
        else
            UIStateManager.showDebugUI(self)
        end
        return
    end

    if key == "f11" then
        options_window.toggle_fullscreen(self)
        return
    end

    if UIStateManager.isPauseUIVisible(self) then
        if key == "escape" or key == "return" or key == "kpenter" then
            UIStateManager.hidePauseUI(self)
        end
        return
    end

    if UIStateManager.isDeathUIVisible(self) then
        if key == "return" or key == "space" then
            UIStateManager.requestRespawn(self)
        end
        return
    end

    if key == "escape" then
        UIStateManager.showPauseUI(self)
        return
    end

    if key == "q" or key == "e" then
        if self.uiInput and self.uiInput.keyboardCaptured then
            return
        end

        local player = PlayerManager.getCurrentShip(self)
        if not player then
            return
        end

        local direction = key == "q" and -1 or 1
        if PlayerWeapons.cycle(player, direction) then
            return
        end
    end

    if key == "tab" then
        UIStateManager.toggleCargoUI(self)
        return
    end

    if key == "m" then
        UIStateManager.toggleMapUI(self)
        return
    end

    if key == "k" then
        UIStateManager.toggleSkillsUI(self)
        return
    end
end

return gameplay
