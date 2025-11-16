---@diagnostic disable: undefined-global

local loader = require("src.blueprints.loader")
local constants = require("src.constants.game")

local love = love

local World = {}

local DEFAULT_WORLD_BOUNDS = constants.world.bounds
local DEFAULT_SECTOR_ID = constants.world.default_sector or "default_sector"

local function normalize_bounds(source)
    source = source or {}
    local fallback = DEFAULT_WORLD_BOUNDS or {}

    return {
        x = source.x or fallback.x or 0,
        y = source.y or fallback.y or 0,
        width = source.width or fallback.width or 4000,
        height = source.height or fallback.height or 4000,
    }
end

local function build_world_boundaries(state)
    local bounds = state.worldBounds
    local world = state.physicsWorld
    local body = love.physics.newBody(world, 0, 0, "static")

    local edges = {
        { bounds.x, bounds.y, bounds.x + bounds.width, bounds.y },
        { bounds.x, bounds.y + bounds.height, bounds.x + bounds.width, bounds.y + bounds.height },
        { bounds.x, bounds.y, bounds.x, bounds.y + bounds.height },
        { bounds.x + bounds.width, bounds.y, bounds.x + bounds.width, bounds.y + bounds.height },
    }

    local fixtures = {}
    for i = 1, #edges do
        local edge = edges[i]
        local x1, y1, x2, y2 = edge[1], edge[2], edge[3], edge[4]
        local shape = love.physics.newEdgeShape(x1, y1, x2, y2)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setFriction(0)
        fixture:setRestitution(0)
        fixture:setUserData({ type = "boundary" })
        fixtures[#fixtures + 1] = fixture
    end

    state.boundaryBody = body
    state.boundaryFixtures = fixtures
end

local function destroy_boundaries(state)
    local body = state.boundaryBody
    if body and not body:isDestroyed() then
        body:destroy()
    end

    state.boundaryBody = nil
    state.boundaryFixtures = nil
end

function World.loadSector(state, sectorId)
    local chosenId = sectorId or DEFAULT_SECTOR_ID
    local ok, sector = pcall(loader.load, "sectors", chosenId)

    if ok and type(sector) == "table" then
        state.sector = sector
        state.asteroidConfig = sector.asteroids
        state.enemyConfig = sector.enemies
        state.proceduralShipConfig = sector.proceduralShips
        state.stationConfig = sector.stations
        state.warpgateConfig = sector.warpgates
    else
        local reason = not ok and sector or "invalid sector data"
        print(string.format("[gameplay] Failed to load sector '%s': %s", tostring(chosenId), tostring(reason)))
        state.sector = nil
        state.asteroidConfig = nil
        state.enemyConfig = nil
        state.proceduralShipConfig = nil
        state.stationConfig = nil
        state.warpgateConfig = nil
    end
end

function World.initialize(state)
    local sector = state.sector
    local boundsSource = sector and (sector.worldBounds or sector.bounds) or DEFAULT_WORLD_BOUNDS
    state.worldBounds = normalize_bounds(boundsSource)

    local physics = constants.physics
    state.physicsWorld = love.physics.newWorld(physics.gravity.x, physics.gravity.y, physics.allow_sleeping)
    state.physicsWorld:setSleepingAllowed(physics.allow_sleeping)

    build_world_boundaries(state)
end

function World.teardown(state)
    destroy_boundaries(state)
    state.physicsWorld = nil
    state.worldBounds = nil
    state.sector = nil
    state.asteroidConfig = nil
    state.enemyConfig = nil
    state.proceduralShipConfig = nil
    state.stationConfig = nil
    state.warpgateConfig = nil
end

return World
