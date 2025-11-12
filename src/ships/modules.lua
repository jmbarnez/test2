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

local function apply_module_effects(entity)
    if not entity then
        return
    end

    local modules = ensure_runtime_modules(entity)
    if not modules or type(modules.slots) ~= "table" then
        return
    end

    local totalShieldBonus = 0
    local totalShieldRegen = 0
    local moduleRechargeDelay = nil
    local hasShieldModifier = false

    for i = 1, #modules.slots do
        local slot = modules.slots[i]
        local stats = slot and slot.item and slot.item.module
        if stats then
            local bonus = tonumber(stats.shield_bonus)
            if bonus and bonus ~= 0 then
                totalShieldBonus = totalShieldBonus + bonus
                hasShieldModifier = true
            end

            local regen = tonumber(stats.shield_regen)
            if regen and regen ~= 0 then
                totalShieldRegen = totalShieldRegen + regen
                hasShieldModifier = true
            end

            local delay = tonumber(stats.shield_recharge_delay)
            if delay then
                delay = math.max(0, delay)
                if moduleRechargeDelay == nil then
                    moduleRechargeDelay = delay
                else
                    moduleRechargeDelay = math.min(moduleRechargeDelay, delay)
                end
                hasShieldModifier = true
            end
        end
    end

    entity._moduleBase = entity._moduleBase or {}

    local currentShield = entity.shield or (entity.health and entity.health.shield)
    local baseShield = entity._moduleBase.shield

    if not baseShield then
        if currentShield then
            baseShield = {
                max = math.max(0, tonumber(currentShield.max or currentShield.capacity or currentShield.limit or currentShield.current or 0) or 0),
                regen = math.max(0, tonumber(currentShield.regen) or 0),
                rechargeDelay = math.max(0, tonumber(currentShield.rechargeDelay) or 0),
            }
        else
            baseShield = { max = 0, regen = 0, rechargeDelay = 0 }
        end
        entity._moduleBase.shield = baseShield
    end

    local function resolve_shield_component()
        local shield = entity.shield or (entity.health and entity.health.shield)
        if not shield then
            shield = {
                max = 0,
                current = 0,
                regen = 0,
                rechargeDelay = baseShield.rechargeDelay or 0,
                rechargeTimer = 0,
                percent = 0,
                isDepleted = true,
            }
            entity.shield = shield
            if entity.health then
                entity.health.shield = shield
            end
        end
        return shield
    end

    local shieldComponent = resolve_shield_component()

    local previousMax = math.max(0, tonumber(shieldComponent.max or baseShield.max or 0) or 0)
    local ratio
    if previousMax > 0 then
        ratio = math.max(0, math.min(1, (tonumber(shieldComponent.current) or previousMax) / previousMax))
    else
        ratio = shieldComponent.percent
        if not (ratio and ratio > 0) then
            ratio = 1
        end
    end

    local newMax
    local newRegen
    local newDelay

    if hasShieldModifier then
        newMax = math.max(0, (baseShield.max or 0) + totalShieldBonus)
        newRegen = math.max(0, (baseShield.regen or 0) + totalShieldRegen)
        if moduleRechargeDelay ~= nil then
            newDelay = moduleRechargeDelay
        else
            newDelay = math.max(0, baseShield.rechargeDelay or 0)
        end
    else
        newMax = math.max(0, baseShield.max or 0)
        newRegen = math.max(0, baseShield.regen or 0)
        newDelay = math.max(0, baseShield.rechargeDelay or 0)
    end

    shieldComponent.max = newMax
    local newCurrent = newMax > 0 and math.min(newMax, ratio * newMax) or 0
    shieldComponent.current = newCurrent
    shieldComponent.regen = newRegen

    local clampedDelay = math.max(0, newDelay)
    shieldComponent.rechargeDelay = clampedDelay
    local timer = tonumber(shieldComponent.rechargeTimer) or 0
    shieldComponent.rechargeTimer = math.min(math.max(0, timer), clampedDelay)

    shieldComponent.percent = newMax > 0 and (newCurrent / newMax) or 0
    shieldComponent.isDepleted = newCurrent <= 0
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

local function get_cargo_items(entity)
    if not (entity and entity.cargo) then
        return nil
    end

    local cargoComponent = entity.cargo
    local items = cargoComponent.items
    if type(items) ~= "table" then
        items = {}
        cargoComponent.items = items
    end

    return items
end

local function detach_from_cargo(entity, item)
    local items = get_cargo_items(entity)
    if not items or type(item) ~= "table" then
        return false
    end

    for index = #items, 1, -1 do
        if items[index] == item then
            table.remove(items, index)
            entity.cargo.dirty = true
            return true
        end
    end

    return false
end

local function attach_to_cargo(entity, item)
    local items = get_cargo_items(entity)
    if not items or type(item) ~= "table" then
        return false
    end

    for index = 1, #items do
        if items[index] == item then
            return false
        end
    end

    items[#items + 1] = item
    entity.cargo.dirty = true
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

    apply_module_effects(entity)
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

    apply_module_effects(entity)
    return true
end

function Modules.sync_from_cargo(entity)
    local modules = ensure_runtime_modules(entity)
    if not modules or type(modules.slots) ~= "table" then
        return
    end

    for _, slot in ipairs(modules.slots) do
        if slot.item then
            slot.item.installed = true
            ensure_item_slot_metadata(slot, slot.item)
        end
    end

    local cargoItems = get_cargo_items(entity)
    if not cargoItems then
        return
    end

    local toEquip = {}
    for _, item in ipairs(cargoItems) do
        if type(item) == "table" then
            local isModule = (item.type == "module")
                or (type(item.id) == "string" and item.id:match("^module:"))
            if isModule and item.installed then
                toEquip[#toEquip + 1] = item
            end
        end
    end

    for index = 1, #toEquip do
        Modules.equip(entity, toEquip[index], nil)
    end

    apply_module_effects(entity)
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
