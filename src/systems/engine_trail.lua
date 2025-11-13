local tiny = require("libs.tiny")

return tiny.processingSystem {
    filter = tiny.requireAll("engineTrail"),

    process = function(_, entity, dt)
        local trail = entity.engineTrail
        if trail then
            trail:update(dt or 0)
        end
    end,

    draw = function(self)
        local world = self.world
        local pool = self.__pool

        if not (world and pool) then
            return
        end

        local entities = world.entities
        for i = 1, #entities do
            local entity = entities[i]
            if pool[entity] then
                local trail = entity.engineTrail
                if trail then
                    trail:draw()
                end
            end
        end
    end,
}
