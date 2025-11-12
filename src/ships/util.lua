local table_util = require("src.util.table")

local util = {}

function util.sanitize_positive_number(value)
    local n = tonumber(value) or 0
    return n < 0 and 0 or n
end

function util.deep_copy(value, cache)
    return table_util.deep_copy(value, cache)
end

function util.instantiate_initial_item(descriptor, loader, Items)
    if type(descriptor) ~= "table" then
        if type(descriptor) == "string" then
            local itemInstance = Items.instantiate(descriptor)
            if itemInstance then
                return itemInstance
            end
        end
        return descriptor
    end

    if descriptor.id and descriptor.type then
        local clone = util.deep_copy(descriptor)
        clone.quantity = util.sanitize_positive_number(clone.quantity or 1)
        clone.volume = util.sanitize_positive_number(clone.volume or 1)
        return clone
    end

    local weaponId = descriptor.weapon or descriptor.weaponId
    if weaponId then
        local blueprint
        local ok, loaded = pcall(loader.load, "weapons", weaponId)
        if ok then
            blueprint = loaded
        end

        local overrides = {}
        if descriptor.quantity then
            overrides.quantity = util.sanitize_positive_number(descriptor.quantity)
        end
        if descriptor.installed ~= nil then
            overrides.installed = descriptor.installed
        end
        if descriptor.slot then
            overrides.slot = descriptor.slot
        end
        if descriptor.mount then
            overrides.mount = util.deep_copy(descriptor.mount)
        end
        if descriptor.overrides then
            overrides.overrides = util.deep_copy(descriptor.overrides)
        end
        if descriptor.name then
            overrides.name = descriptor.name
        end

        local instance
        if blueprint then
            instance = Items.ensureWeaponItem(blueprint, overrides)
        else
            instance = Items.createWeaponItem(weaponId, overrides)
        end

        if instance then
            instance.quantity = util.sanitize_positive_number(instance.quantity or descriptor.quantity or 1)
            instance.volume = util.sanitize_positive_number(descriptor.volume or instance.volume or 1)
            if not instance.icon and blueprint and blueprint.icon then
                instance.icon = util.deep_copy(blueprint.icon)
            end
            return instance
        end
    end

    local moduleId = descriptor.module or descriptor.moduleId or descriptor.blueprint
    if moduleId then
        local blueprint
        local ok, loaded = pcall(loader.load, "modules", moduleId)
        if ok then
            blueprint = loaded
        end

        local overrides = {}
        if descriptor.quantity then
            overrides.quantity = util.sanitize_positive_number(descriptor.quantity)
        end
        if descriptor.installed ~= nil then
            overrides.installed = descriptor.installed
        end
        if descriptor.slot then
            overrides.slot = descriptor.slot
        end
        if descriptor.overrides then
            overrides.overrides = util.deep_copy(descriptor.overrides)
        end
        if descriptor.name then
            overrides.name = descriptor.name
        end

        local instance
        if blueprint then
            instance = Items.ensureModuleItem(blueprint, overrides)
        else
            instance = Items.createModuleItem(moduleId, overrides)
        end

        if instance then
            instance.quantity = util.sanitize_positive_number(instance.quantity or descriptor.quantity or 1)
            instance.volume = util.sanitize_positive_number(descriptor.volume or instance.volume or 1)
            if not instance.icon and blueprint and blueprint.icon then
                instance.icon = util.deep_copy(blueprint.icon)
            end
            return instance
        end
    end

    local fallback = util.deep_copy(descriptor)
    fallback.quantity = util.sanitize_positive_number(fallback.quantity or 1)
    fallback.volume = util.sanitize_positive_number(fallback.volume or 1)
    return fallback
end

return util
