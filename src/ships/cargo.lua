local loader = require("src.blueprints.loader")
local Items = require("src.items.registry")
local ship_util = require("src.ships.util")

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

local function sanitize_quantity(value)
    return ship_util.sanitize_positive_number(value or 0)
end

local function ensure_items_table(component)
    component.items = type(component.items) == "table" and component.items or {}
    return component.items
end

function cargo.populate_from_descriptors(cargoComponent, descriptors)
    if type(cargoComponent) ~= "table" or type(descriptors) ~= "table" then
        return
    end

    local items = ensure_items_table(cargoComponent)

    for i = 1, #descriptors do
        local descriptor = descriptors[i]
        local item = ship_util.instantiate_initial_item(descriptor, loader, Items)
        if item then
            local existing = find_existing_item(items, item.id)
            if existing then
                existing.quantity = sanitize_quantity((existing.quantity or 0) + (item.quantity or 0))
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

    local items = ensure_items_table(cargoComponent)
    context = context or {}
    local weaponOverrides = context.weaponOverrides or {}

    for i = 1, #weapons do
        local weapon = weapons[i]
        if weapon and weapon.itemId then
            local overrides
            if weapon.blueprint and weapon.blueprint.id then
                overrides = weaponOverrides[weapon.blueprint.id]
            end
            local itemInstance = Items.instantiate(weapon.itemId, {
                installed = true,
                slot = weapon.assign,
                mount = weapon.weaponMount,
                overrides = overrides,
            })

            if itemInstance then
                local existing = find_existing_item(items, itemInstance.id)
                if existing then
                    existing.quantity = sanitize_quantity((existing.quantity or 0) + (itemInstance.quantity or 0))
                else
                    items[#items + 1] = itemInstance
                end
                cargoComponent.dirty = true
            end
        end
    end
end

local function recalculate(cargoComponent)
    if type(cargoComponent) ~= "table" then
        return 0
    end

    local items = ensure_items_table(cargoComponent)
    local total = 0

    for index = #items, 1, -1 do
        local item = items[index]
        if type(item) ~= "table" then
            table.remove(items, index)
        else
            item.quantity = sanitize_quantity(item.quantity or item.count)
            item.volume = ship_util.sanitize_positive_number(item.volume or item.unitVolume)

            if item.quantity == 0 or item.volume == 0 then
                table.remove(items, index)
            else
                total = total + item.quantity * item.volume
            end
        end
    end

    cargoComponent.capacity = ship_util.sanitize_positive_number(cargoComponent.capacity)
    cargoComponent.used = total
    cargoComponent.available = math.max(0, cargoComponent.capacity - total)
    return total
end

local function can_fit(cargoComponent, additionalVolume)
    if type(cargoComponent) ~= "table" then
        return false
    end

    local volume = ship_util.sanitize_positive_number(additionalVolume)
    if volume == 0 then
        return true
    end

    local capacity = ship_util.sanitize_positive_number(cargoComponent.capacity)
    local used = ship_util.sanitize_positive_number(cargoComponent.used)
    return volume <= math.max(0, capacity - used)
end

function cargo.try_add_item(cargoComponent, descriptor, quantity)
    if type(cargoComponent) ~= "table" or type(descriptor) ~= "table" then
        return false, "invalid_descriptor"
    end

    local items = ensure_items_table(cargoComponent)
    local qty = ship_util.sanitize_positive_number(quantity or descriptor.quantity or 1)
    local perVolume = ship_util.sanitize_positive_number(descriptor.volume or descriptor.unitVolume)
    if qty == 0 or perVolume == 0 then
        return false, "zero_volume"
    end

    local deltaVolume = qty * perVolume
    if not can_fit(cargoComponent, deltaVolume) then
        return false, "insufficient_capacity"
    end

    local id = descriptor.id
    local target

    if id then
        for i = 1, #items do
            local existing = items[i]
            if existing and existing.id == id then
                target = existing
                break
            end
        end
    end

    if target then
        target.quantity = sanitize_quantity(target.quantity) + qty
        target.volume = ship_util.sanitize_positive_number(target.volume)
        if target.volume == 0 then
            target.volume = perVolume
        end
    else
        target = {
            id = id,
            name = descriptor.name or descriptor.displayName or id or "Unknown Cargo",
            quantity = qty,
            volume = perVolume,
            icon = descriptor.icon,
        }
        items[#items + 1] = target
    end

    cargoComponent.used = ship_util.sanitize_positive_number(cargoComponent.used) + deltaVolume
    cargoComponent.capacity = ship_util.sanitize_positive_number(cargoComponent.capacity)
    cargoComponent.available = math.max(0, cargoComponent.capacity - cargoComponent.used)
    cargoComponent.dirty = true
    return true
end

function cargo.try_remove_item(cargoComponent, itemId, quantity)
    if type(cargoComponent) ~= "table" or not itemId then
        return false, "invalid_item"
    end

    local items = ensure_items_table(cargoComponent)
    local qty = ship_util.sanitize_positive_number(quantity or 1)
    if qty == 0 then
        return false, "zero_quantity"
    end

    for index = 1, #items do
        local item = items[index]
        if item and (item.id == itemId or item.name == itemId) then
            local removable = math.min(item.quantity or 0, qty)
            if removable <= 0 then
                return false, "insufficient_quantity"
            end

            item.quantity = (item.quantity or 0) - removable
            local freedVolume = removable * (item.volume or 0)

            if item.quantity <= 0 then
                table.remove(items, index)
            end

            cargoComponent.used = math.max(0, ship_util.sanitize_positive_number(cargoComponent.used) - freedVolume)
            cargoComponent.capacity = ship_util.sanitize_positive_number(cargoComponent.capacity)
            cargoComponent.available = math.max(0, cargoComponent.capacity - cargoComponent.used)
            cargoComponent.dirty = true
            return true
        end
    end

    return false, "not_found"
end

function cargo.initialize(cargoComponent)
    if type(cargoComponent) ~= "table" then
        return nil
    end

    cargoComponent.capacity = ship_util.sanitize_positive_number(cargoComponent.capacity or cargoComponent.volumeCapacity or cargoComponent.volumeLimit)
    cargoComponent.items = ensure_items_table(cargoComponent)

    if #cargoComponent.items > 0 then
        local normalized = {}
        for index = 1, #cargoComponent.items do
            local resolved = ship_util.instantiate_initial_item(cargoComponent.items[index], loader, Items)
            if resolved then
                normalized[#normalized + 1] = resolved
            end
        end
        cargoComponent.items = normalized
    end

    cargoComponent.refresh = cargoComponent.refresh or recalculate
    cargoComponent.canFit = cargoComponent.canFit or can_fit
    cargoComponent.tryAddItem = cargoComponent.tryAddItem or cargo.try_add_item
    cargoComponent.tryRemoveItem = cargoComponent.tryRemoveItem or cargo.try_remove_item

    cargoComponent.refresh(cargoComponent)
    cargoComponent.dirty = false
    cargoComponent.autoRefresh = cargoComponent.autoRefresh ~= false
    return cargoComponent
end

function cargo.refresh_if_needed(cargoComponent)
    if not cargoComponent then
        return
    end

    if cargoComponent.autoRefresh ~= false and cargoComponent.dirty then
        local refresh = cargoComponent.refresh or recalculate
        if type(refresh) == "function" then
            refresh(cargoComponent)
            cargoComponent.dirty = false
        end
    end
end

cargo.recalculate = recalculate
cargo.can_fit = can_fit

return cargo
