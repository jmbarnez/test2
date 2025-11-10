local Entities = require("src.states.gameplay.entities")
local Systems = require("src.states.gameplay.systems")
local World = require("src.states.gameplay.world")
local Snapshot = require("src.network.snapshot")

local server_gameplay = {}
server_gameplay.__index = server_gameplay

local DEFAULT_FIXED_DT = 1 / 60
local MAX_STEPS = 4

function server_gameplay.new(config)
    config = config or {}

    local self = setmetatable({
        netRole = 'server',
        players = {},
        entitiesById = {},
        snapshotTick = 0,
        fixedDt = config.fixedDt or DEFAULT_FIXED_DT,
        maxSteps = config.maxSteps or MAX_STEPS,
        physicsAccumulator = 0,
    }, server_gameplay)

    -- Load world/physics identical to gameplay state
    World.loadSector(self, config.sectorId)
    World.initialize(self)

    Systems.initializeServer(self, Entities.damage)

    return self
end

function server_gameplay:spawnPlayer(playerId, config)
    config = config or {}
    config.playerId = playerId or config.playerId

    local entity = Entities.spawnPlayer(self, config)
    if entity and config.playerId then
        self.players[config.playerId] = entity
    end
    return entity
end

function server_gameplay:update(dt)
    if not self.world then
        return
    end

    -- Fixed timestep physics
    local physicsWorld = self.physicsWorld
    if physicsWorld then
        self.physicsAccumulator = self.physicsAccumulator + dt

        local steps = 0
        local fixedDt = self.fixedDt
        local maxSteps = self.maxSteps

        while self.physicsAccumulator >= fixedDt and steps < maxSteps do
            physicsWorld:update(fixedDt)
            self.physicsAccumulator = self.physicsAccumulator - fixedDt
            steps = steps + 1
        end

        if self.physicsAccumulator > fixedDt * maxSteps then
            self.physicsAccumulator = 0
        end
    end

    self.world:update(dt)
    Entities.updateHealthTimers(self.world, dt)
end

function server_gameplay:captureSnapshot()
    return Snapshot.capture(self)
end

function server_gameplay:teardown()
    Entities.destroyWorldEntities(self.world)
    Systems.teardown(self)
    World.teardown(self)
end

return server_gameplay
