---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local Entities = require("src.states.gameplay.entities")

return function(context)
    local state = context.state or context
    local spawned = false

    return tiny.system {
        update = function()
            if spawned then
                return
            end

            spawned = true

            if not state then
                print("[WARPGATE SPAWNER] No state context")
                return
            end

            local configs = state.warpgateConfig
            if not configs then
                print("[WARPGATE SPAWNER] No warpgateConfig in state")
                return
            end

            print("[WARPGATE SPAWNER] Spawning warpgates with config:", configs)
            local result = Entities.spawnWarpgates(state, configs)
            print("[WARPGATE SPAWNER] Spawn result:", result, "warpgateEntities count:", state.warpgateEntities and #state.warpgateEntities or 0)
        end,
    }
end
