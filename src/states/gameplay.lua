-- gameplay.lua
-- Main game state for Procedural Space
-- Manages the game world, entities, and systems
-- Handles entity creation, world initialization, and system updates
-- Uses tiny-ecs for entity-component-system architecture

---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")
require("src.entities.ship_factory")
require("src.entities.asteroid_factory")
require("src.entities.weapon_factory")
local World = require("src.states.gameplay.world")
local Entities = require("src.states.gameplay.entities")
local Systems = require("src.states.gameplay.systems")
local View = require("src.states.gameplay.view")
local FilmGrain = require("src.rendering.film_grain")
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
    local ship = PlayerManager.getCurrentShip(self)
    if ship then
        self.player = ship
        return ship
    end

    -- Fallbacks for any legacy references still populating players table
    if self.players then
        if self.localPlayerId then
            local localPlayer = self.players[self.localPlayerId]
            if localPlayer then
                PlayerManager.attachShip(self, localPlayer)
                return localPlayer
            end
        end

        for _, entity in pairs(self.players) do
            if entity then
                PlayerManager.attachShip(self, entity)
                return entity
            end
        end
    end
end

function gameplay:enter(_, config)
    local sectorId = resolveSectorId(config)

    self.cargoUI = { visible = false }
    self.deathUI = {
        visible = false,
        title = "Ship Destroyed",
        message = "Your ship has been destroyed. Respawn to re-enter the fight.",
        buttonLabel = "Respawn",
        hint = "Press Enter to respawn",
    }
    self.respawnRequested = false

    self.players = {}
    self.localPlayerId = nil
    self.player = nil

    self.engineTrail = PlayerEngineTrail.new()

    World.loadSector(self, sectorId)
    World.initialize(self)
    View.initialize(self)
    FilmGrain.initialize(self)
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
    FilmGrain.teardown(self)
    if self.engineTrail then
        self.engineTrail:clear()
        self.engineTrail = nil
    end
    self.player = nil
    self.players = nil
    self.localPlayerId = nil
    self.playerPilot = nil
    self.playerShip = nil
    self.cargoUI = nil
    self.deathUI = nil
    self.respawnRequested = nil
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

    if self.respawnRequested then
        self:respawnPlayer()
    end

    self.world:update(dt)

    local physicsWorld = self.physicsWorld
    if physicsWorld then
        physicsWorld:update(dt)
    end

    if self.engineTrail then
        self.engineTrail:update(dt)
    end

    local movementSystem = self.movementSystem
    if movementSystem and movementSystem.update then
        movementSystem:update(dt)
    end

    Entities.updateHealthTimers(self.world, dt)

    View.updateCamera(self)
    FilmGrain.update(self, dt)
end

function gameplay:respawnPlayer()
    if not (self.world and self.physicsWorld) then
        return
    end

    local spawnConfig = self.localPlayerId and { playerId = self.localPlayerId } or nil
    local player = Entities.spawnPlayer(self, spawnConfig)
    if not player then
        return
    end

    self:registerPlayerCallbacks(player)

    self.respawnRequested = false

    if self.engineTrail then
        self.engineTrail:attachPlayer(player)
        self.engineTrail:setActive(false)
    end

    if self.deathUI then
        self.deathUI.visible = false
        self.deathUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    end

    if self.uiInput then
        self.uiInput.mouseCaptured = false
        self.uiInput.keyboardCaptured = false
    end

    View.updateCamera(self)
end

function gameplay:registerPlayerCallbacks(player)
    if not player then
        return
    end

    self.players = self.players or {}

    local playerId = player.playerId or "player"
    self.players[playerId] = player

    if not self.localPlayerId then
        self.localPlayerId = playerId
    end

    if self.localPlayerId == playerId then
        self.player = player
    end

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

    local playerId = entity.playerId

    if self.players and playerId and self.players[playerId] == entity then
        self.players[playerId] = nil
    end

    if self.player == entity then
        self.player = nil
    end

    if self.engineTrail then
        self.engineTrail:setActive(false)
        self.engineTrail:attachPlayer(nil)
    end

    if self.deathUI then
        self.deathUI.visible = true
        self.deathUI.buttonHovered = false
        self.deathUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    end

    if self.uiInput then
        self.uiInput.mouseCaptured = true
        self.uiInput.keyboardCaptured = true
    end

    self.respawnRequested = false
end

function gameplay:draw()
    if not (self.world and self.renderSystem) then
        return
    end

    local clearColor = constants.render.clear_color
    local function renderScene()
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

    FilmGrain.draw(self, renderScene, clearColor)
end

function gameplay:resize(w, h)
    View.resize(self, w, h)
    FilmGrain.resize(self, w, h)
end

function gameplay:updateCamera()
    View.updateCamera(self)
end

function gameplay:keypressed(key)
    if MultiplayerWindow.keypressed(self, key) then
        return
    end

    if self.deathUI and self.deathUI.visible then
        if key == "return" or key == "space" then
            self.respawnRequested = true
        end
        return
    end

    if key == "tab" then
        if not self.cargoUI then
            self.cargoUI = { visible = false }
        end
        self.cargoUI.visible = not self.cargoUI.visible
        return
    end
end

return gameplay
