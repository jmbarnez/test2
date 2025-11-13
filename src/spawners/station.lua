---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local Entities = require("src.states.gameplay.entities")

return function(context)
    local state = context.state or context

    local spawned = false

    return tiny.system {
        update = function(self, _)
            if spawned then
                return
            end

            spawned = true

            if not state then
                print("[STATION SPAWNER] No state")
                return
            end

            local configs = state.stationConfig
            if not configs then
                print("[STATION SPAWNER] No stationConfig in state")
                return
            end

            print("[STATION SPAWNER] Spawning stations with config:", configs)
            local result = Entities.spawnStations(state, configs)
            print("[STATION SPAWNER] Spawn result:", result, "stationEntities count:", state.stationEntities and #state.stationEntities or 0)
        end,
    }
end
