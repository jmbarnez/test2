local loader = require("src.blueprints.loader")

local weapon_factory = {}

local function deep_copy(value, cache)
    if type(value) ~= "table" then
        return value
    end

    cache = cache or {}
    if cache[value] then
        return cache[value]
    end

    local copy = {}
    cache[value] = copy

    for k, v in pairs(value) do
        copy[deep_copy(k, cache)] = deep_copy(v, cache)
    end

    local mt = getmetatable(value)
    if mt then
        setmetatable(copy, mt)
    end

    return copy
end

local function merge_tables(target, source)
    if not source then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            local existing = target[key]
            if type(existing) ~= "table" then
                existing = {}
                target[key] = existing
            end
            merge_tables(existing, value)
        else
            target[key] = value
        end
    end

    return target
end

function weapon_factory.instantiate(blueprint, context)
    assert(type(blueprint) == "table", "instantiate requires a blueprint table")
    context = context or {}

    local weapon = {
        blueprint = {
            category = blueprint.category,
            id = blueprint.id,
            name = blueprint.name,
        }
    }

    local components = blueprint.components or {}
    local overrides = context.overrides or {}

    for componentName, component in pairs(components) do
        local copy = deep_copy(component)
        local override = overrides[componentName]
        if override then
            merge_tables(copy, override)
        end
        weapon[componentName] = copy
    end

    weapon.assign = context.assign or blueprint.assign

    if context.mount then
        weapon.mount = deep_copy(context.mount)
        if weapon.weaponMount then
            merge_tables(weapon.weaponMount, weapon.mount)
        else
            weapon.weaponMount = deep_copy(context.mount)
        end
    end

    local owner = context.owner
    if owner then
        weapon.owner = owner
        owner.weapons = owner.weapons or {}
        owner.weapons[#owner.weapons + 1] = weapon

        if weapon.assign and weapon[weapon.assign] then
            owner[weapon.assign] = weapon[weapon.assign]
        end

        if weapon.weaponMount then
            owner.weaponMount = weapon.weaponMount
        end
    end

    return weapon
end

loader.register_factory("weapons", weapon_factory)

return weapon_factory
