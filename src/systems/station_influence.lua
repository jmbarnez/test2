local tiny = require("libs.tiny")
local PlayerManager = require("src.player.manager")
local ShipRuntime = require("src.ships.runtime")

local function resolve_station_entities(state)
    if not (state and state.stationEntities) then
        return nil, 0
    end

    local stations = state.stationEntities
    local count = #stations
    if count == 0 then
        return nil, 0
    end

    return stations, count
end

local function normalize_radius(station)
    if not station then
        return nil
    end

    local influence = station.stationInfluence
    if influence and type(influence.radius) == "number" then
        return influence.radius
    end

    local drawable = station.drawable
    if drawable then
        local baseRadius = ShipRuntime.compute_drawable_radius(drawable)
        if baseRadius and baseRadius > 0 then
            return baseRadius * 2
        end
    end

    return 1000
end

local function update_station_influence_flags(state, player)
    if not state then
        return
    end

    state.playerUnderStationInfluence = false
    state.stationInfluenceSource = nil

    local stations, count = resolve_station_entities(state)
    if not stations or count == 0 then
        return
    end

    if not player then
        for i = 1, count do
            local station = stations[i]
            if station then
                station.stationInfluenceActive = false
            end
        end
        return
    end

    local playerPos = player.position
    if not (playerPos and playerPos.x and playerPos.y) then
        for i = 1, count do
            local station = stations[i]
            if station then
                station.stationInfluenceActive = false
            end
        end
        return
    end

    local bestStation
    local bestDistanceSq = math.huge
    local bestRadius = 0

    for i = 1, count do
        local station = stations[i]
        if station then
            local position = station.position
            local active = false
            if position and position.x and position.y then
                local radius = normalize_radius(station)
                if radius and radius > 0 then
                    local dx = playerPos.x - position.x
                    local dy = playerPos.y - position.y
                    local distSq = dx * dx + dy * dy
                    if distSq <= radius * radius then
                        active = true
                        if distSq < bestDistanceSq then
                            bestDistanceSq = distSq
                            bestStation = station
                            bestRadius = radius
                        end
                    end
                end
            end
            station.stationInfluenceActive = active
        end
    end

    if bestStation then
        state.playerUnderStationInfluence = true
        state.stationInfluenceSource = bestStation
        state.stationInfluenceRadius = bestRadius
    else
        state.stationInfluenceRadius = nil
    end
end

---@class StationInfluenceSystemContext
---@field state table|nil      # Gameplay state providing station entities and player

return function(context)
    context = context or {}

    return tiny.system {
        update = function()
            local state = context.state or context
            if not state then
                return
            end

            local player = PlayerManager.getCurrentShip(state)
            update_station_influence_flags(state, player)
        end,
    }
end
