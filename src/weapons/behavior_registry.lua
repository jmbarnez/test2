local RegistryFactory = require("src.util.behavior_registry")

local WeaponRegistry = RegistryFactory.create({
    name = "WeaponBehaviorRegistry",
    resolve = function(self, weapon)
        if not weapon then
            return nil
        end

        local behavior = self:get(weapon.constantKey)
        if behavior then
            return behavior
        end

        local fireMode = weapon.fireMode
        if fireMode then
            local fallback = self:getFallback(fireMode)
            if fallback then
                return fallback
            end
        end

        return nil
    end,
})

return WeaponRegistry
