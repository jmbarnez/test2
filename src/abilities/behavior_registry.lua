local RegistryFactory = require("src.util.behavior_registry")

local AbilityRegistry = RegistryFactory.create({
    name = "AbilityBehaviorRegistry",
    resolve = function(self, ability)
        if not ability then
            return nil
        end

        local behavior = self:get(ability.id)
        if behavior then
            return behavior
        end

        local abilityType = ability and (ability.type or ability.id)
        if abilityType then
            local fallback = self:getFallback(abilityType)
            if fallback then
                return fallback
            end
        end

        return nil
    end,
})

return AbilityRegistry
