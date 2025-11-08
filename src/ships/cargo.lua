local loader = require("src.blueprints.loader")
local Items = require("src.items.registry")
local runtime = require("src.ships.runtime")

local cargo = {}

local function find_existing_item(items, id)
    if not id then
        return nil
    end

    for i = 1, #items do
        local existing = items[i]
        if existing and existing.id == id then
            return existing
        end
    end

    return nil
end

function cargo.populate_from_descriptors(cargoComponent, descriptors)
    if type(cargoComponent) ~= "table" or type(descriptors) ~= "table" then
        return
    end

    cargoComponent.items = cargoComponent.items or {}
    local items = cargoComponent.items

    for i = 1, #descriptors do
        local descriptor = descriptors[i]
        local item = runtime.instantiate_initial_item(descriptor)
        if item then
            local existing = find_existing_item(items, item.id)
            if existing then
                existing.quantity = runtime.sanitize_positive_number((existing.quantity or 0) + (item.quantity or 0))
            else
                items[#items + 1] = item
            end
        end
    end

    cargoComponent.dirty = true
end

function cargo.add_weapon_items(cargoComponent, weapons, context)
    if type(cargoComponent) ~= "table" or type(weapons) ~= "table" then
        return
    end

    cargoComponent.items = cargoComponent.items or {}
    local items = cargoComponent.items

    for i = 1, #weapons do
        local weapon = weapons[i]
        if weapon and weapon.itemId then
            local overrides = context and context.weaponOverrides and context.weaponOverrides[weapon.blueprint.id]
            local itemInstance = Items.instantiate(weapon.itemId, {
                installed = true,
                slot = weapon.assign,
                mount = weapon.weaponMount,
                overrides = overrides,
            })

            if itemInstance then
                local existing = find_existing_item(items, itemInstance.id)
                if existing then
                    existing.quantity = runtime.sanitize_positive_number((existing.quantity or 0) + (itemInstance.quantity or 0))
                else
                    items[#items + 1] = itemInstance
                end
                cargoComponent.dirty = true
            end
        end
    end
end

function cargo.initialize(cargoComponent)
    return runtime.initialize_cargo(cargoComponent)
end

function cargo.refresh_if_needed(cargoComponent)
    if cargoComponent then
        runtime.update({ cargo = cargoComponent }, 0)
    end
end

return cargo
