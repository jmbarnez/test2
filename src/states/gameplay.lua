-- gameplay.lua
-- Main game state for Procedural Space
-- Manages the game world, entities, and systems
-- Handles entity creation, world initialization, and system updates
-- Uses tiny-ecs for entity-component-system architecture

---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")
local PlayerWeapons = require("src.player.weapons")
local UIStateManager = require("src.ui.state_manager")
require("src.entities.ship_factory")
require("src.entities.asteroid_factory")
require("src.entities.weapon_factory")
local World = require("src.states.gameplay.world")
local Entities = require("src.states.gameplay.entities")
local Systems = require("src.states.gameplay.systems")
local View = require("src.states.gameplay.view")
local PlayerEngineTrail = require("src.effects.player_engine_trail")
local Snapshot = require("src.network.snapshot")
local Interpolation = require("src.network.interpolation")
local Prediction = require("src.network.prediction")
local MultiplayerWindow = require("src.ui.windows.multiplayer")
local ChatWindow = require("src.ui.windows.chat")

local love = love

local gameplay = {}

local function resolveSectorId(config)
    if type(config) == "table" then
        return config.sectorId or config.sector
    elseif type(config) == "string" then
        return config
    end
end

function gameplay:textinput(text)
    if ChatWindow.textinput(self, text) then
        return
    end

    MultiplayerWindow.textinput(self, text)
end

function gameplay:getLocalPlayer()
    return PlayerManager.getLocalPlayer(self)
end

function gameplay:enter(_, config)
    local sectorId = resolveSectorId(config)
    self.currentSectorId = sectorId or self.currentSectorId

    -- Initialize UI state
    UIStateManager.initialize(self)
    
    -- Initialize engine trail
    self.engineTrail = PlayerEngineTrail.new()

    World.loadSector(self, sectorId)
    World.initialize(self)
    View.initialize(self)
    Systems.initialize(self, Entities.damage)
    
    -- Default role is offline until user chooses Host/Join
    self.netRole = config and config.netRole or self.netRole or 'offline'

    -- Initialize client-side prediction buffers
    self.prediction = self.prediction or {}
    self.prediction.maxSize = constants.network.prediction_buffer_size or self.prediction.maxSize or 90
    Prediction.reset(self)
    -- Do not pre-spawn when acting as a client; server will spawn on connect
    if self.netRole ~= 'client' then
        local player = Entities.spawnPlayer(self)
        if player then
            if self.engineTrail then
                self.engineTrail:attachPlayer(player)
            end
            self:registerPlayerCallbacks(player)
        end
    end
    View.updateCamera(self)
end

function gameplay:leave()
    PlayerManager.clearShip(self)
    Entities.destroyWorldEntities(self.world)
    Systems.teardown(self)
    World.teardown(self)
    View.teardown(self)

    if self.engineTrail then
        self.engineTrail:clear()
        self.engineTrail = nil
    end
    
    -- Clean up network connections
    if self.networkManager then
        self.networkManager:shutdown()
        self.networkManager = nil
    end
    if self.networkServer then
        self.networkServer:shutdown()
        self.networkServer = nil
    end
    
    -- Clean up UI state
    UIStateManager.cleanup(self)
end

function gameplay:reinitializeAsClient()
    -- Tear down existing world/state except network connections
    PlayerManager.clearShip(self)
    Entities.destroyWorldEntities(self.world)
    Systems.teardown(self)
    World.teardown(self)
    View.teardown(self)

    if self.engineTrail then
        self.engineTrail:clear()
    end
    self.engineTrail = PlayerEngineTrail.new()

    self.netRole = 'client'
    self.player = nil
    self.playerShip = nil
    self.players = {}
    self.entitiesById = {}
    self.worldSynced = false
    self.localPlayerId = nil
    self.networkServer = nil

    self.prediction = {
        tick = 0,
        history = {},
        order = {},
        maxSize = constants.network.prediction_buffer_size or 90,
        lastAck = 0,
    }

    World.loadSector(self, self.currentSectorId)
    World.initialize(self)
    View.initialize(self)
    Systems.initialize(self, Entities.damage)
    View.updateCamera(self)
end

function gameplay:captureSnapshot()
    return Snapshot.capture(self)
end

function gameplay:applySnapshot(data)
    Snapshot.apply(self, data)
end

function gameplay:update(dt)
    if not self.world then
        return
    end

    if UIStateManager.isRespawnRequested(self) then
        self:respawnPlayer()
    end

    -- Update network systems (only in multiplayer modes)
    if self.netRole ~= 'offline' then
        if self.networkManager then
            self.networkManager:update(dt)
        end
        if self.networkServer then
            self.networkServer:update(dt)
        end

        -- Initialize prediction module
        Prediction.initialize(self)

        -- Interpolate remote entities for smooth movement (both client and host)
        if constants.network.interpolation_enabled and (self.netRole == 'client' or self.netRole == 'host') then
            Interpolation.updateWorld(self.world, dt)
        end
    end

    -- Fixed timestep physics for deterministic multiplayer
    -- MUST update physics BEFORE world systems so systems read fresh physics state
    -- Accumulate frame time and step physics in fixed increments
    local physicsWorld = self.physicsWorld
    if physicsWorld then
        local FIXED_DT = constants.network.physics_timestep
        local MAX_STEPS = constants.network.physics_max_steps
        
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

    if constants.network.client_prediction_enabled and self.netRole == 'client' then
        local ship = PlayerManager.getCurrentShip(self)
        if ship then
            Prediction.recordState(self, ship)
        end
    end

    -- Update ECS systems after physics (systems read freshly updated physics state)
    self.world:update(dt)

    if self.engineTrail then
        self.engineTrail:update(dt)
    end

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
end

function gameplay:draw()
    if not (self.world and self.renderSystem) then
        return
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
    love.graphics.pop()
end

function gameplay:resize(w, h)
    View.resize(self, w, h)
end

function gameplay:updateCamera()
    View.updateCamera(self)
end

function gameplay:keypressed(key)
    if MultiplayerWindow.keypressed(self, key) then
        return
    end

    if ChatWindow.keypressed(self, key) then
        return
    end

    if UIStateManager.isDeathUIVisible(self) then
        if key == "return" or key == "space" then
            UIStateManager.requestRespawn(self)
        end
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
end

return gameplay
