local loader = require("src.blueprints.loader")
local Items = require("src.items.registry")

local weapon_factory = {}

local function resolve_mount_anchor(mount, owner, source)
    if not mount or not owner then
        return mount
    end

    local anchor = mount.anchor
    if not anchor then
        return mount
    end

    local radius = owner.mountRadius or 0
    if radius > 0 then
        local anchorX = anchor.x or 0
        local anchorY = anchor.y or 0

        local baseLateral = 0
        local baseForward = 0

        if source then
            if source.lateral ~= nil then
                baseLateral = source.lateral
            end
            if source.forward ~= nil then
                baseForward = source.forward
            end
        end

        mount.lateral = baseLateral + anchorX * radius
        mount.forward = baseForward + anchorY * radius
    else
        if source then
            if source.lateral ~= nil then
                mount.lateral = source.lateral
            end
            if source.forward ~= nil then
                mount.forward = source.forward
            end
        end
    end

    mount.anchor = nil
    return mount
end

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

    weapon.isWeapon = true

    local itemId = Items.registerWeaponBlueprint(blueprint)
    weapon.itemId = itemId

    local components = blueprint.components or {}
    local overrides = context.overrides or {}

    for componentName, component in pairs(components) do
        local copy = deep_copy(component)
        local override = overrides[componentName]
        if override then
            merge_tables(copy, override)
        end
        if componentName == "weaponMount" then
            resolve_mount_anchor(copy, context.owner, override)
        end
        weapon[componentName] = copy
    end

    weapon.assign = context.assign or blueprint.assign

    if context.mount then
        weapon.mount = deep_copy(context.mount)
        if weapon.weaponMount then
            merge_tables(weapon.weaponMount, weapon.mount)
            resolve_mount_anchor(weapon.weaponMount, context.owner, context.mount)
        else
            weapon.weaponMount = deep_copy(context.mount)
            resolve_mount_anchor(weapon.weaponMount, context.owner, context.mount)
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
