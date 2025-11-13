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
local station_window = require("src.ui.windows.station")
local ShipRuntime = require("src.ships.runtime")
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
local SaveLoad = require("src.util.save_load")

local love = love

local SAMPLE_WINDOW = 120

local DOCK_RADIUS_MULTIPLIER = 2.0
local DOCK_RADIUS_FALLBACK = 1000

local function resolve_station_dock_radius(station)
    if not station then
        return DOCK_RADIUS_FALLBACK
    end

    local drawable = station.drawable
    if drawable then
        local base = ShipRuntime.compute_drawable_radius(drawable)
        if base and base > 0 then
            return math.max(base * DOCK_RADIUS_MULTIPLIER, DOCK_RADIUS_FALLBACK)
        end
    end

    local mountRadius = station.mountRadius
    if type(mountRadius) == "number" and mountRadius > 0 then
        return math.max(mountRadius * DOCK_RADIUS_MULTIPLIER, DOCK_RADIUS_FALLBACK)
    end

    return DOCK_RADIUS_FALLBACK
end

local function update_station_dock_state(state)
    if not state then
        return
    end

    state.stationDockTarget = nil
    state.stationDockRadius = nil
    state.stationDockDistance = nil

    local stations = state.stationEntities
    if not (stations and #stations > 0) then
        print("[DOCK] No stations found. stationEntities:", stations, "count:", stations and #stations or 0)
        return
    end

    local player = PlayerManager.getCurrentShip(state)
    local position = player and player.position
    if not (position and position.x and position.y) then
        print("[DOCK] No player position")
        return
    end
    
    print("[DOCK] Checking", #stations, "stations. Player at:", position.x, position.y)

    local px, py = position.x, position.y
    local bestStation
    local bestDistanceSq = math.huge
    local bestRadius = 0

    for i = 1, #stations do
        local station = stations[i]
        if station then
            station.stationInfluenceActive = false
        end
        local stationPos = station and station.position
        if stationPos and stationPos.x and stationPos.y then
            local radius = resolve_station_dock_radius(station)
            print("[DOCK] Station", i, "at", stationPos.x, stationPos.y, "radius:", radius)
            if radius and radius > 0 then
                local dx = px - stationPos.x
                local dy = py - stationPos.y
                local distSq = dx * dx + dy * dy
                local dist = math.sqrt(distSq)
                local radiusSq = radius * radius
                
                print("[DOCK]   Distance:", dist, "vs radius:", radius, "in range?", distSq <= radiusSq)

                if distSq <= radiusSq and distSq < bestDistanceSq then
                    bestDistanceSq = distSq
                    bestStation = station
                    bestRadius = radius
                    print("[DOCK]   -> Selected as best station")
                end
            end
        end
    end

    if bestStation then
        state.stationDockTarget = bestStation
        state.stationDockRadius = bestRadius
        state.stationDockDistance = math.sqrt(bestDistanceSq)
        bestStation.stationInfluenceActive = true
        print("[DOCK] DOCKING AVAILABLE - distance:", state.stationDockDistance, "radius:", bestRadius)
    else
        print("[DOCK] No station in range")
    end
end

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

local METRIC_ORDER = { "frame_dt_ms", "update_ms", "render_ms" }
local METRIC_LABELS = {
    frame_dt_ms = "Frame dt",
    update_ms = "Update",
    render_ms = "Render",
}

local function update_performance_strings(state)
    if not state then
        return
    end

    local metrics = state.performanceStatsRecords
    if not metrics then
        state.performanceStats = nil
        return
    end

    local lines = {}
    for i = 1, #METRIC_ORDER do
        local key = METRIC_ORDER[i]
        local bucket = metrics[key]
        if bucket and bucket.last then
            local avg = bucket.avg or bucket.last
            local minv = bucket.min or bucket.last
            local maxv = bucket.max or bucket.last
            local last = bucket.last
            lines[#lines + 1] = string.format(
                "%s: avg %.2fms (%.2f-%.2f) last %.2f",
                METRIC_LABELS[key] or key,
                avg,
                minv,
                maxv,
                last
            )
        end
    end

    state.performanceStats = lines
end

local function finalize_update_metrics(state, start_time)
    if not state then
        return
    end

    local metrics = state.performanceStatsRecords
    if metrics and start_time then
        local stop = get_time()
        if stop then
            record_metric(metrics, "update_ms", math.max(0, (stop - start_time) * 1000))
        end
    end

    update_performance_strings(state)
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
        if love.keyboard.isDown(key) then
            return true
        end
    end

    return false
end

local function show_status_toast(state, message, color)
    if not (state and message and FloatingText and FloatingText.add) then
        return
    end

    local player = PlayerManager.getCurrentShip(state)
    local position
    local offsetY = 28

    if player and player.position then
        position = {
            x = player.position.x or 0,
            y = player.position.y or 0,
        }
        offsetY = (player.mountRadius or 36) + 24
    elseif state.camera then
        local cam = state.camera
        local width = cam.width or state.viewport and state.viewport.width or 0
        local height = cam.height or state.viewport and state.viewport.height or 0
        position = {
            x = (cam.x or 0) + width * 0.5,
            y = (cam.y or 0) + height * 0.5,
        }
        offsetY = math.max(24, height * 0.1)
    end

    if not position then
        return
    end

    FloatingText.add(state, position, message, {
        color = color,
        offsetY = offsetY,
        rise = 32,
        scale = 1.1,
    })
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
    
    if UIStateManager.isStationUIVisible(self) then
        if station_window.wheelmoved(self, x, y) then
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

    self.performanceStatsRecords = {}
    self.performanceStats = {}

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

    self.performanceStatsRecords = nil
    self.performanceStats = nil
end

function gameplay:update(dt)
    if not self.world then
        return
    end

    local metrics = self.performanceStatsRecords
    if not metrics then
        metrics = {}
        self.performanceStatsRecords = metrics
    end

    if dt then
        record_metric(metrics, "frame_dt_ms", dt * 1000)
    end

    local updateStart = get_time()

    if UIStateManager.isRespawnRequested(self) then
        self:respawnPlayer()
    end

    if UIStateManager.isPaused(self) then
        finalize_update_metrics(self, updateStart)
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

    update_station_dock_state(self)

    if self.engineTrail then
        self.engineTrail:update(dt)
    end

    FloatingText.update(self, dt)

    Entities.updateHealthTimers(self.world, dt)

    View.updateCamera(self)

    finalize_update_metrics(self, updateStart)
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

    local metrics = self.performanceStatsRecords
    if not metrics then
        metrics = {}
        self.performanceStatsRecords = metrics
    end

    local renderStart = get_time()

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

    if metrics and renderStart then
        local renderStop = get_time()
        if renderStop then
            record_metric(metrics, "render_ms", math.max(0, (renderStop - renderStart) * 1000))
        end
    end

    update_performance_strings(self)
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
    
    if station_window.keypressed(self, key) then
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

    if key == "e" then
        if self.uiInput and self.uiInput.keyboardCaptured then
            return
        end
        
        -- Check if player is near a station
        if self.stationDockTarget then
            UIStateManager.showStationUI(self)
            return
        end
        
        -- Otherwise cycle weapons
        local player = PlayerManager.getCurrentShip(self)
        if player then
            PlayerWeapons.cycle(player, 1)
        end
        return
    end
    
    if key == "q" then
        if self.uiInput and self.uiInput.keyboardCaptured then
            return
        end

        local player = PlayerManager.getCurrentShip(self)
        if player then
            PlayerWeapons.cycle(player, -1)
        end
        return
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

    if key == "f5" then
        local success, err = SaveLoad.saveGame(self)
        if success then
            show_status_toast(self, "Game Saved", { 0.4, 1.0, 0.4, 1.0 })
        else
            show_status_toast(self, "Save Failed: " .. tostring(err), { 1.0, 0.4, 0.4, 1.0 })
            print("[SaveLoad] Save error: " .. tostring(err))
        end
        return
    end

    if key == "f9" then
        local success, err = SaveLoad.loadGame(self)
        if success then
            show_status_toast(self, "Game Loaded", { 0.4, 1.0, 0.4, 1.0 })
        else
            show_status_toast(self, "Load Failed: " .. tostring(err), { 1.0, 0.4, 0.4, 1.0 })
            print("[SaveLoad] Load error: " .. tostring(err))
        end
        return
    end
end

return gameplay
