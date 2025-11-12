local table_util = require("src.util.table")

local Modules = {}

local DEFAULT_SLOT_TYPE = "defense"

local function capitalize(value)
    if type(value) ~= "string" or value == "" then
        return value
    end
    return value:sub(1, 1):upper() .. value:sub(2)
end

local function normalize_slot(slot, index, fallbackType)
    if type(slot) ~= "table" then
        slot = {}
    end

    slot.type = slot.type or fallbackType or DEFAULT_SLOT_TYPE
    slot.index = index
    slot.id = slot.id or string.format("%s_slot_%d", slot.type, index)
    slot.name = slot.name or string.format("%s Slot %d", capitalize(slot.type), index)
    slot.item = slot.item or nil
    return slot
end

local function reindex_slots(modules)
    if not modules or type(modules.slots) ~= "table" then
        return
    end
    for index = 1, #modules.slots do
        modules.slots[index] = normalize_slot(modules.slots[index], index, modules.defaultType)
    end
end

local function ensure_runtime_modules(entity)
    if not entity then
        return nil
    end

    local current = entity.modules
    if current and current._runtime then
        reindex_slots(current)
        return current
    end

    local blueprintModules = current
    local runtimeModules = {
        slots = {},
        defaultType = blueprintModules and blueprintModules.defaultType,
        _runtime = true,
    }

    if blueprintModules and type(blueprintModules.slots) == "table" then
        for index = 1, #blueprintModules.slots do
            local slotDef = table_util.deep_copy(blueprintModules.slots[index])
            runtimeModules.slots[index] = normalize_slot(slotDef, index, blueprintModules.defaultType)
        end
    end

    entity.modules = runtimeModules
    return runtimeModules
end

local function remove_item_reference(modules, item)
    if not modules or type(modules.slots) ~= "table" then
        return
    end
    for _, slot in ipairs(modules.slots) do
        if slot.item == item then
            slot.item = nil
        end
    end
end

local function detach_from_cargo(entity, item)
    if not (entity and entity.cargo) or type(item) ~= "table" then
        return false
    end

    local cargoComponent = entity.cargo
    local items = cargoComponent.items
    if type(items) ~= "table" then
        return false
    end

    for index = #items, 1, -1 do
        if items[index] == item then
            table.remove(items, index)
            cargoComponent.dirty = true
            return true
        end
    end

    return false
end

local function attach_to_cargo(entity, item)
    if not (entity and entity.cargo) or type(item) ~= "table" then
        return false
    end

    local cargoComponent = entity.cargo
    if type(cargoComponent.items) ~= "table" then
        cargoComponent.items = {}
    end

    local items = cargoComponent.items
    for index = 1, #items do
        if items[index] == item then
            return false
        end
    end

    items[#items + 1] = item
    cargoComponent.dirty = true
    return true
end

local function find_slot_by_id(modules, id)
    if not modules or type(modules.slots) ~= "table" or not id then
        return nil
    end
    for _, slot in ipairs(modules.slots) do
        if slot.id == id then
            return slot
        end
    end
    return nil
end

local function find_occupied_slot(modules, item)
    if not modules or type(modules.slots) ~= "table" then
        return nil
    end
    for _, slot in ipairs(modules.slots) do
        if slot.item == item then
            return slot
        end
    end
    return nil
end

local function find_matching_slot(modules, item, requestedIndex)
    if not modules or type(modules.slots) ~= "table" then
        return nil
    end

    if requestedIndex and modules.slots[requestedIndex] then
        return modules.slots[requestedIndex]
    end

    if item and item.moduleSlotId then
        local slot = find_slot_by_id(modules, item.moduleSlotId)
        if slot then
            return slot
        end
    end

    local desiredType = (item and item.slot) or modules.defaultType or DEFAULT_SLOT_TYPE

    for _, slot in ipairs(modules.slots) do
        if not slot.item and (not desiredType or slot.type == desiredType) then
            return slot
        end
    end

    for _, slot in ipairs(modules.slots) do
        if not slot.item then
            return slot
        end
    end

    return nil
end

local function ensure_item_slot_metadata(slot, item)
    if not item then
        return
    end
    item.installed = true
    item.slot = slot.type
    item.moduleSlotId = slot.id
end

function Modules.initialize(entity)
    local modules = ensure_runtime_modules(entity)
    if modules then
        reindex_slots(modules)
    end
    return modules
end

function Modules.ensure(entity)
    return ensure_runtime_modules(entity)
end

function Modules.get_slots(entity)
    local modules = ensure_runtime_modules(entity)
    return modules and modules.slots or {}
end

function Modules.equip(entity, item, preferredIndex)
    if type(item) ~= "table" then
        return false
    end

    local modules = ensure_runtime_modules(entity)
    if not modules or type(modules.slots) ~= "table" then
        return false
    end

    if find_occupied_slot(modules, item) then
        ensure_item_slot_metadata(find_occupied_slot(modules, item), item)
        return true
    end

    local slot = find_matching_slot(modules, item, preferredIndex)
    if not slot then
        return false
    end

    if slot.item and slot.item ~= item then
        Modules.unequip(entity, slot.index)
    end

    remove_item_reference(modules, item)
    detach_from_cargo(entity, item)

    slot.item = item
    ensure_item_slot_metadata(slot, item)

    if entity and entity.cargo then
        entity.cargo.dirty = true
    end

    return true
end

function Modules.unequip(entity, slotOrIndex)
    local modules = ensure_runtime_modules(entity)
    if not modules or type(modules.slots) ~= "table" then
        return false
    end

    local slot
    if type(slotOrIndex) == "number" then
        slot = modules.slots[slotOrIndex]
    elseif type(slotOrIndex) == "table" then
        slot = find_occupied_slot(modules, slotOrIndex)
    end

    if not slot or not slot.item then
        return false
    end

    local item = slot.item
    slot.item = nil

    if item then
        item.installed = false
        item.moduleSlotId = nil
        if not item._keep_slot_type then
            item.slot = nil
        end
    end

    attach_to_cargo(entity, item)

    return true
end

function Modules.sync_from_cargo(entity)
    local modules = ensure_runtime_modules(entity)
    if not modules or type(modules.slots) ~= "table" then
        return
    end

    local preserved = {}
    for _, slot in ipairs(modules.slots) do
        if slot.item then
            slot.item.installed = true
            ensure_item_slot_metadata(slot, slot.item)
            preserved[slot.id] = slot.item
        end
        slot.item = nil
    end

    local cargo = entity and entity.cargo
    local items = cargo and cargo.items
    if type(items) ~= "table" then
        return
    end

    for _, item in ipairs(items) do
        if type(item) == "table" then
            local isModule = (item.type == "module")
                or (type(item.id) == "string" and item.id:match("^module:"))
            if isModule and item.installed then
                local slot = find_matching_slot(modules, item, nil)
                if slot then
                    slot.item = item
                    ensure_item_slot_metadata(slot, item)
                    preserved[slot.id] = nil
                else
                    item.installed = false
                    item.moduleSlotId = nil
                end
            end
        end
    end

    for slotId, preservedItem in pairs(preserved) do
        if preservedItem then
            local slot = find_slot_by_id(modules, slotId)
            if slot and not slot.item then
                slot.item = preservedItem
                ensure_item_slot_metadata(slot, preservedItem)
            end
        end
    end
end

function Modules.serialize(entity)
    local modules = ensure_runtime_modules(entity)
    if not modules or type(modules.slots) ~= "table" then
        return nil
    end

    local serialized = {
        slots = {},
    }

    for index, slot in ipairs(modules.slots) do
        serialized.slots[index] = {
            id = slot.id,
            type = slot.type,
            itemId = slot.item and slot.item.id or nil,
        }
    end

    return serialized
end

function Modules.apply_snapshot(entity, snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    local modules = ensure_runtime_modules(entity)
    if not modules or type(modules.slots) ~= "table" then
        return
    end

    local lookup = {}
    if entity and entity.cargo and type(entity.cargo.items) == "table" then
        for _, item in ipairs(entity.cargo.items) do
            if type(item) == "table" and item.id then
                lookup[item.id] = item
            end
        end
    end

    for _, slot in ipairs(modules.slots) do
        slot.item = nil
    end

    if type(snapshot.slots) ~= "table" then
        Modules.sync_from_cargo(entity)
        return
    end

    for _, snapshotSlot in ipairs(snapshot.slots) do
        if snapshotSlot and snapshotSlot.id then
            local slot = find_slot_by_id(modules, snapshotSlot.id)
            if slot and snapshotSlot.itemId then
                local item = lookup[snapshotSlot.itemId]
                if item then
                    slot.item = item
                    ensure_item_slot_metadata(slot, item)
                    item.installed = true
                end
            end
        end
    end

    Modules.sync_from_cargo(entity)
end

return Modules
