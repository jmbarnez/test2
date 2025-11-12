local table_util = require("src.util.table")

local Items = {}

local definitions = {}
local weaponByBlueprint = {}
local moduleByBlueprint = {}
local builtin_definitions = {
    require("src.items.definitions.resource_ore_chunk"),
    require("src.items.definitions.resource_rare_crystal"),
    require("src.items.definitions.resource_hull_scrap"),
}

local function apply_overrides(target, overrides)
    if type(overrides) ~= "table" then
        return target
    end

    for key, value in pairs(overrides) do
        if type(value) == "table" then
            local existing = target[key]
            if type(existing) ~= "table" then
                existing = {}
                target[key] = existing
            end
            apply_overrides(existing, value)
        else
            target[key] = value
        end
    end

    return target
end

function Items.registerModuleBlueprint(blueprint)
    if type(blueprint) ~= "table" then
        return nil
    end

    local blueprintId = blueprint.id
    if not blueprintId then
        return nil
    end

    local itemId = "module:" .. blueprintId
    if definitions[itemId] then
        moduleByBlueprint[blueprintId] = itemId
        return itemId
    end

    local itemMeta = blueprint.item or {}
    local components = blueprint.components or {}
    local moduleStats = components.module
    local definitionMetadata
    if moduleStats then
        definitionMetadata = { module = table_util.deep_copy(moduleStats) }
    end

    Items.register({
        id = itemId,
        type = "module",
        name = blueprint.name or itemMeta.name or blueprintId,
        stackable = false,
        blueprintId = blueprintId,
        blueprintCategory = blueprint.category or "modules",
        icon = blueprint.icon and table_util.deep_copy(blueprint.icon) or nil,
        volume = itemMeta.volume,
        value = itemMeta.value,
        description = itemMeta.description or blueprint.description,
        rarity = blueprint.rarity,
        metadata = definitionMetadata,
        createInstance = function(instance, overrides)
            overrides = overrides or {}
            instance.quantity = 1
            instance.installed = overrides.installed or false
            instance.slot = overrides.slot or blueprint.slot or "defense"
            if overrides.overrides then
                instance.overrides = table_util.deep_copy(overrides.overrides)
            end
            if moduleStats then
                instance.module = table_util.deep_copy(moduleStats)
            end
        end,
    })

    moduleByBlueprint[blueprintId] = itemId
    return itemId
end

function Items.ensureModuleItem(blueprint, overrides)
    local itemId = Items.registerModuleBlueprint(blueprint)
    if not itemId then
        return nil, "invalid_module_blueprint"
    end
    return Items.instantiate(itemId, overrides)
end

function Items.createModuleItem(moduleId, overrides)
    if not moduleId then
        return nil, "invalid_module_id"
    end

    local itemId = moduleByBlueprint[moduleId]
    if not itemId then
        itemId = "module:" .. moduleId
        if not definitions[itemId] then
            Items.register({
                id = itemId,
                type = "module",
                name = moduleId,
                stackable = false,
                blueprintId = moduleId,
                blueprintCategory = "modules",
                createInstance = function(instance, overrides_)
                    overrides_ = overrides_ or {}
                    instance.quantity = 1
                    instance.installed = overrides_.installed or false
                    instance.slot = overrides_.slot or "defense"
                    if overrides_.overrides then
                        instance.overrides = table_util.deep_copy(overrides_.overrides)
                    end
                end,
            })
        end
        moduleByBlueprint[moduleId] = itemId
    end

    return Items.instantiate(itemId, overrides)
end

function Items.register(definition)
    assert(type(definition) == "table", "Item definition must be a table")
    local id = assert(definition.id, "Item definition requires an id")

    if definitions[id] then
        return definitions[id]
    end

    definitions[id] = definition
    return definition
end

-- Register built-in definitions supplied via modules -----------------------

for index = 1, #builtin_definitions do
    local definition = builtin_definitions[index]
    if type(definition) == "table" then
        Items.register(definition)
    else
        error(string.format("Invalid built-in item definition at index %d", index))
    end
end

function Items.has(id)
    return definitions[id] ~= nil
end

function Items.get(id)
    return definitions[id]
end

function Items.instantiate(id, overrides)
    local definition = definitions[id]
    if not definition then
        return nil, string.format("unknown_item:%s", tostring(id))
    end

    local instance = {
        id = id,
        type = definition.type or "generic",
        name = overrides and overrides.name or definition.name or id,
        stackable = definition.stackable or false,
        quantity = overrides and overrides.quantity or definition.defaultQuantity or 1,
        metadata = definition.metadata and table_util.deep_copy(definition.metadata) or nil,
        blueprintId = definition.blueprintId,
        blueprintCategory = definition.blueprintCategory,
    }

    if definition.icon then
        instance.icon = table_util.deep_copy(definition.icon)
    end

    local overrideVolume = overrides and overrides.volume
    local overrideUnitVolume = overrides and overrides.unitVolume
    if overrideVolume ~= nil then
        instance.volume = overrideVolume
    elseif definition.volume ~= nil then
        instance.volume = definition.volume
    elseif overrideUnitVolume ~= nil then
        instance.volume = overrideUnitVolume
    elseif definition.unitVolume ~= nil then
        instance.volume = definition.unitVolume
    end

    if overrideUnitVolume ~= nil then
        instance.unitVolume = overrideUnitVolume
    elseif definition.unitVolume ~= nil then
        instance.unitVolume = definition.unitVolume
    end

    if instance.volume == nil and instance.unitVolume ~= nil then
        instance.volume = instance.unitVolume
    end

    if definition.createInstance then
        definition.createInstance(instance, overrides or {})
    elseif overrides then
        apply_overrides(instance, overrides)
    end

    return instance
end

function Items.registerWeaponBlueprint(blueprint)
    if type(blueprint) ~= "table" then
        return nil
    end

    local blueprintId = blueprint.id
    if not blueprintId then
        return nil
    end

    local itemId = "weapon:" .. blueprintId
    if definitions[itemId] then
        weaponByBlueprint[blueprintId] = itemId
        return itemId
    end

    Items.register({
        id = itemId,
        type = "weapon",
        name = blueprint.name or blueprintId,
        stackable = false,
        blueprintId = blueprintId,
        blueprintCategory = blueprint.category or "weapons",
        icon = blueprint.icon and table_util.deep_copy(blueprint.icon) or nil,
        createInstance = function(instance, overrides)
            overrides = overrides or {}
            instance.quantity = 1
            instance.installed = overrides.installed or false
            instance.slot = overrides.slot
            if overrides.mount then
                instance.mount = table_util.deep_copy(overrides.mount)
            end
            if overrides.overrides then
                instance.overrides = table_util.deep_copy(overrides.overrides)
            end
        end,
    })

    weaponByBlueprint[blueprintId] = itemId
    return itemId
end

function Items.ensureWeaponItem(blueprint, overrides)
    local itemId = Items.registerWeaponBlueprint(blueprint)
    if not itemId then
        return nil, "invalid_weapon_blueprint"
    end
    return Items.instantiate(itemId, overrides)
end

function Items.createWeaponItem(weaponId, overrides)
    if not weaponId then
        return nil, "invalid_weapon_id"
    end

    local itemId = weaponByBlueprint[weaponId]
    if not itemId then
        itemId = "weapon:" .. weaponId
        if not definitions[itemId] then
            Items.register({
                id = itemId,
                type = "weapon",
                name = weaponId,
                stackable = false,
                blueprintId = weaponId,
                blueprintCategory = "weapons",
                createInstance = function(instance, overrides_)
                    overrides_ = overrides_ or {}
                    instance.quantity = 1
                    instance.installed = overrides_.installed or false
                    instance.slot = overrides_.slot
                    if overrides_.mount then
                        instance.mount = table_util.deep_copy(overrides_.mount)
                    end
                    if overrides_.overrides then
                        instance.overrides = table_util.deep_copy(overrides_.overrides)
                    end
                end,
            })
        end
        weaponByBlueprint[weaponId] = itemId
    end

    return Items.instantiate(itemId, overrides)
end

function Items.iterateDefinitions()
    return pairs(definitions)
end

return Items
