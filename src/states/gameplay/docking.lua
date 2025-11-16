--- Station Docking System
-- Manages player proximity to stations and docking state

local PlayerManager = require("src.player.manager")
local ShipRuntime = require("src.ships.runtime")

local DOCK_RADIUS_MULTIPLIER = 2.0
local DOCK_RADIUS_FALLBACK = 1000

local Docking = {}

--- Resolve the docking radius for a station
---@param station table Station entity
---@return number Dock radius in world units
local function resolveDockRadius(station)
    if not station then
        return DOCK_RADIUS_FALLBACK
    end

    -- Try drawable radius first
    local drawable = station.drawable
    if drawable then
        local base = ShipRuntime.compute_drawable_radius(drawable)
        if base and base > 0 then
            return math.max(base * DOCK_RADIUS_MULTIPLIER, DOCK_RADIUS_FALLBACK)
        end
    end

    -- Fallback to mount radius
    local mountRadius = station.mountRadius
    if type(mountRadius) == "number" and mountRadius > 0 then
        return math.max(mountRadius * DOCK_RADIUS_MULTIPLIER, DOCK_RADIUS_FALLBACK)
    end

    return DOCK_RADIUS_FALLBACK
end

--- Update station docking state based on player position
---@param state table Gameplay state
function Docking.updateState(state)
    if not state then
        return
    end

    -- Clear previous dock state
    state.stationDockTarget = nil
    state.stationDockRadius = nil
    state.stationDockDistance = nil

    local stations = state.stationEntities
    if not (stations and #stations > 0) then
        return
    end

    local player = PlayerManager.getCurrentShip(state)
    local position = player and player.position
    if not (position and position.x and position.y) then
        return
    end

    local px, py = position.x, position.y
    local bestStation, bestDistanceSq, bestRadius = nil, math.huge, 0

    -- Find closest station within range
    for i = 1, #stations do
        local station = stations[i]
        if station then
            station.stationInfluenceActive = false
        end
        
        local stationPos = station and station.position
        if stationPos and stationPos.x and stationPos.y then
            local radius = resolveDockRadius(station)
            if radius and radius > 0 then
                local dx, dy = px - stationPos.x, py - stationPos.y
                local distSq = dx * dx + dy * dy
                local radiusSq = radius * radius

                if distSq <= radiusSq and distSq < bestDistanceSq then
                    bestDistanceSq = distSq
                    bestStation = station
                    bestRadius = radius
                end
            end
        end
    end

    -- Update state with best station
    if bestStation then
        state.stationDockTarget = bestStation
        state.stationDockRadius = bestRadius
        state.stationDockDistance = math.sqrt(bestDistanceSq)
        bestStation.stationInfluenceActive = true
    end
end

return Docking
