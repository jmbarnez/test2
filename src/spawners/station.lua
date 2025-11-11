---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local Entities = require("src.states.gameplay.entities")

return function(context)
    local state = context

    local spawned = false

    return tiny.system {
        update = function(self, _)
            if spawned then
                return
            end

            spawned = true

            if not state then
                return
            end

            local configs = state.stationConfig
            if not configs then
                return
            end

            Entities.spawnStations(state, configs)
        end,
    }
end
