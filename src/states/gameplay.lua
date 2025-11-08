-- gameplay.lua
-- Main game state for Procedural Space
-- Manages the game world, entities, and systems
-- Handles entity creation, world initialization, and system updates
-- Uses tiny-ecs for entity-component-system architecture

---@diagnostic disable: undefined-global

local constants = require("src.constants.game")
require("src.entities.ship_factory")
require("src.entities.asteroid_factory")
require("src.entities.weapon_factory")
local World = require("src.states.gameplay.world")
local Entities = require("src.states.gameplay.entities")
local Systems = require("src.states.gameplay.systems")
local View = require("src.states.gameplay.view")
local FilmGrain = require("src.rendering.film_grain")

local love = love

local gameplay = {}

local function resolveSectorId(config)
    if type(config) == "table" then
        return config.sectorId or config.sector
    elseif type(config) == "string" then
        return config
    end
end

function gameplay:enter(_, config)
    local sectorId = resolveSectorId(config)

    World.loadSector(self, sectorId)
    World.initialize(self)
    View.initialize(self)
    FilmGrain.initialize(self)
    Systems.initialize(self, Entities.damage)
    Entities.spawnPlayer(self)
    View.updateCamera(self)
end

function gameplay:leave()
    Entities.destroyWorldEntities(self.world)
    Systems.teardown(self)
    World.teardown(self)
    View.teardown(self)
    FilmGrain.teardown(self)
    self.player = nil
end

function gameplay:update(dt)
    if not self.world then
        return
    end

    self.world:update(dt)

    local physicsWorld = self.physicsWorld
    if physicsWorld then
        physicsWorld:update(dt)
    end

    local movementSystem = self.movementSystem
    if movementSystem and movementSystem.update then
        movementSystem:update(dt)
    end

    Entities.updateHealthTimers(self.world, dt)

    View.updateCamera(self)
    FilmGrain.update(self, dt)
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
        love.graphics.translate(-cam.x, -cam.y)
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

return gameplay
