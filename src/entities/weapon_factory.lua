local loader = require("src.blueprints.loader")
local Items = require("src.items.registry")
local table_util = require("src.util.table")

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

    if blueprint.icon ~= nil then
        weapon.blueprint.icon = table_util.deep_copy(blueprint.icon)
    end

    weapon.isWeapon = true

    local itemId = Items.registerWeaponBlueprint(blueprint)
    weapon.itemId = itemId

    local components = blueprint.components or {}
    local overrides = context.overrides or {}

    for componentName, component in pairs(components) do
        local copy = table_util.deep_copy(component)
        local override = overrides[componentName]
        if override then
            table_util.deep_merge(copy, override)
        end
        if componentName == "weaponMount" then
            resolve_mount_anchor(copy, context.owner, override)
        end
        weapon[componentName] = copy
    end

    weapon.assign = context.assign or blueprint.assign

    if context.mount then
        weapon.mount = table_util.deep_copy(context.mount)
        if weapon.weaponMount then
            table_util.deep_merge(weapon.weaponMount, weapon.mount)
            resolve_mount_anchor(weapon.weaponMount, context.owner, context.mount)
        else
            weapon.weaponMount = table_util.deep_copy(context.mount)
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
