-- gameplay.lua
-- Main game state for Procedural Space
-- Manages the game world, entities, and systems
-- Handles entity creation, world initialization, and system updates
-- Uses tiny-ecs for entity-component-system architecture

---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")
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
local MultiplayerWindow = require("src.ui.windows.multiplayer")

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
    MultiplayerWindow.textinput(self, text)
end

function gameplay:getLocalPlayer()
    return PlayerManager.getLocalPlayer(self)
end

function gameplay:enter(_, config)
    local sectorId = resolveSectorId(config)

    -- Initialize UI state
    UIStateManager.initialize(self)
    
    -- Initialize engine trail
    self.engineTrail = PlayerEngineTrail.new()

    World.loadSector(self, sectorId)
    World.initialize(self)
    View.initialize(self)
    Systems.initialize(self, Entities.damage)
    local player = Entities.spawnPlayer(self)
    if player then
        if self.engineTrail then
            self.engineTrail:attachPlayer(player)
        end
        self:registerPlayerCallbacks(player)
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

    -- Update network systems
    if self.networkManager then
        self.networkManager:update(dt)
    end
    if self.networkServer then
        self.networkServer:update(dt)
    end

    self.world:update(dt)

    local physicsWorld = self.physicsWorld
    if physicsWorld then
        physicsWorld:update(dt)
    end

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

    if UIStateManager.isDeathUIVisible(self) then
        if key == "return" or key == "space" then
            UIStateManager.requestRespawn(self)
        end
        return
    end

    if key == "tab" then
        UIStateManager.toggleCargoUI(self)
        return
    end
end

return gameplay
