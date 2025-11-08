local tiny = require("libs.tiny")

return function(context)
    context = context or {}

    return tiny.processingSystem {
        filter = tiny.requireAll("cargo"),

        process = function(self, entity, dt)
            local cargo = entity.cargo
            if not cargo then
                return
            end

            if cargo.autoRefresh ~= false and cargo.dirty and type(cargo.refresh) == "function" then
                cargo.refresh(cargo)
                cargo.dirty = false
            end
        end,
    }
end
