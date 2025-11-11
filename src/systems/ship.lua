local tiny = require("libs.tiny")
local ShipRuntime = require("src.ships.runtime")

return function(context)
    context = context or {}

    return tiny.processingSystem {
        filter = function(entity)
            return entity.shipRuntime ~= nil or entity.cargo ~= nil
        end,

        process = function(_, entity, dt)
            if entity.shipRuntime then
                ShipRuntime.update(entity, dt or 0)
            end

            local cargo = entity.cargo
            if cargo and cargo.autoRefresh ~= false and cargo.dirty and type(cargo.refresh) == "function" then
                cargo.refresh(cargo)
                cargo.dirty = false
            end
        end,
    }
end
