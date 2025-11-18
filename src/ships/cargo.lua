local loader = require("src.blueprints.loader")
local Items = require("src.items.registry")
local ship_util = require("src.ships.util")
local table_util = require("src.util.table")

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

local function resolve_stackable(source)
    if type(source) ~= "table" then
        return false
    end

    if source.stackable ~= nil then
        return source.stackable and true or false
    end

    local id = source.id
    if id then
        local definition = Items.get(id)
        if definition and definition.stackable ~= nil then
            return definition.stackable and true or false
        end
    end

    return false
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
            local stackable = resolve_stackable(item)
            item.stackable = stackable
            local quantity = sanitize_quantity(item.quantity or 1)

            if stackable then
                if quantity > 0 then
                    item.quantity = quantity
                    local existing = find_existing_item(items, item.id)
                    if existing and resolve_stackable(existing) then
                        existing.quantity = sanitize_quantity((existing.quantity or 0) + quantity)
                    else
                        items[#items + 1] = item
                    end
                end
            else
                local count = quantity > 0 and quantity or 1
                for index = 1, count do
                    local entry
                    if index == 1 then
                        entry = item
                    else
                        entry = table_util.deep_copy(item)
                    end
                    entry.quantity = 1
                    entry.stackable = false
                    items[#items + 1] = entry
                end
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
                local stackable = resolve_stackable(itemInstance)
                itemInstance.stackable = stackable
                local quantity = sanitize_quantity(itemInstance.quantity or 1)

                if stackable then
                    if quantity > 0 then
                        itemInstance.quantity = quantity
                        local existing = find_existing_item(items, itemInstance.id)
                        if existing and resolve_stackable(existing) then
                            existing.quantity = sanitize_quantity((existing.quantity or 0) + quantity)
                        else
                            items[#items + 1] = itemInstance
                        end
                    end
                else
                    local count = quantity > 0 and quantity or 1
                    for index = 1, count do
                        local entry
                        if index == 1 then
                            entry = itemInstance
                        else
                            entry = table_util.deep_copy(itemInstance)
                        end
                        entry.quantity = 1
                        entry.stackable = false
                        items[#items + 1] = entry
                    end
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

function cargo.add_item_instance(cargoComponent, instance, quantity)
    if type(cargoComponent) ~= "table" or type(instance) ~= "table" then
        return false, "invalid_instance"
    end

    local qty = sanitize_quantity(quantity or instance.quantity or 1)
    if qty <= 0 then
        qty = 1
    end

    local perVolume = ship_util.sanitize_positive_number(instance.volume or instance.unitVolume)
    if perVolume <= 0 then
        perVolume = 1
    end

    if not can_fit(cargoComponent, perVolume * qty) then
        return false, "insufficient_capacity"
    end

    local items = ensure_items_table(cargoComponent)

    if instance.stackable then
        local existing = find_existing_item(items, instance.id)
        if existing then
            existing.quantity = sanitize_quantity((existing.quantity or 0) + qty)
            existing.volume = ship_util.sanitize_positive_number(existing.volume or perVolume)

            local deltaVolume = perVolume * qty
            cargoComponent.used = ship_util.sanitize_positive_number(cargoComponent.used) + deltaVolume
            cargoComponent.capacity = ship_util.sanitize_positive_number(cargoComponent.capacity)
            cargoComponent.available = math.max(0, cargoComponent.capacity - cargoComponent.used)
            cargoComponent.dirty = true
            return true
        end
    end

    local deltaVolume = perVolume * qty
    if instance.stackable then
        local copy = table_util.deep_copy(instance)
        copy.quantity = qty
        copy.volume = perVolume
        items[#items + 1] = copy
    else
        for _ = 1, qty do
            local copy = table_util.deep_copy(instance)
            copy.quantity = 1
            copy.volume = perVolume
            items[#items + 1] = copy
        end
    end

    cargoComponent.used = ship_util.sanitize_positive_number(cargoComponent.used) + deltaVolume
    cargoComponent.capacity = ship_util.sanitize_positive_number(cargoComponent.capacity)
    cargoComponent.available = math.max(0, cargoComponent.capacity - cargoComponent.used)
    cargoComponent.dirty = true
    return true
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

    local stackable = resolve_stackable(descriptor)
    descriptor.stackable = stackable

    local id = descriptor.id
    local target

    if stackable and id then
        target = find_existing_item(items, id)
        if target and not resolve_stackable(target) then
            target = nil
        end
    end

    if stackable and target then
        target.quantity = sanitize_quantity(target.quantity) + qty
        target.volume = ship_util.sanitize_positive_number(target.volume)
        if target.volume == 0 then
            target.volume = perVolume
        end
        target.stackable = true
    elseif stackable then
        if qty <= 0 then
            qty = 1
        end
        target = table_util.deep_copy(descriptor)
        target.id = id
        target.name = target.name or target.displayName or descriptor.name or descriptor.displayName or id or "Unknown Cargo"
        target.quantity = qty
        target.volume = perVolume
        target.icon = target.icon or descriptor.icon
        target.stackable = true
        items[#items + 1] = target
    else
        local count = qty > 0 and qty or 1
        for _ = 1, count do
            local entry = table_util.deep_copy(descriptor)
            entry.id = entry.id or id
            entry.name = entry.name or entry.displayName or descriptor.name or descriptor.displayName or id or "Unknown Cargo"
            entry.quantity = 1
            entry.volume = perVolume
            entry.icon = entry.icon or descriptor.icon
            entry.stackable = false
            items[#items + 1] = entry
        end
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
