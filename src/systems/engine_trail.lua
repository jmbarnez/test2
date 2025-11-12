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
        local entities = self.entities
        if not entities then
            return
        end

        for i = 1, #entities do
            local entity = entities[i]
            local trail = entity.engineTrail
            if trail then
                trail:draw()
            end
        end
    end,
}
