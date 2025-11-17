local constants = require("src.constants.game")

local HotbarManager = {}

local hotbar_constants = (constants.ui and constants.ui.hotbar) or {}
local HOTBAR_SIZE = hotbar_constants.slot_count or 10

local function is_weapon_item(item)
    if type(item) ~= "table" then
        return false
    end

    if item.type == "weapon" then
        return true
    end

    if item.blueprintCategory == "weapons" then
        return true
    end

    if type(item.id) == "string" and item.id:match("^weapon:") then
        return true
    end

    return false
end

local function normalize_weapon_id(item)
    if not item then
        return nil
    end

    if item.blueprintId then
        return item.blueprintId
    end

    if type(item.id) == "string" then
        local weaponId = item.id:match("^weapon:(.+)")
        if weaponId then
            return weaponId
        end
        return item.id
    end

    return nil
end

local function activate_weapon_from_item(player, item)
    if not (player and item) then
        return false
    end
    if item._weaponInstance and item._weaponInstance.weapon then
        local weaponInstance = item._weaponInstance
        player.weapon = weaponInstance.weapon
        player.weaponMount = weaponInstance.weaponMount

        if player.weapon then
            player.weapon.firing = false
        end

        return true
    end

    local blueprintId = normalize_weapon_id(item)
    if not blueprintId then
        return false
    end

    local loader = require("src.blueprints.loader")
    local context = { owner = player }
    if item.mount then
        context.mount = item.mount
    end

    local ok, weaponInstance = pcall(loader.instantiate, "weapons", blueprintId, context)
    if not ok or not weaponInstance then
        return false
    end

    if not weaponInstance.weapon then
        return false
    end

    item._weaponInstance = weaponInstance

    player.weapon = weaponInstance.weapon
    player.weaponMount = weaponInstance.weaponMount

    if player.weapon then
        player.weapon.firing = false
    end

    return true
end

local function is_activatable_module(item)
    if type(item) ~= "table" then
        return false
    end

    if item._activatableType == "ability" and item._abilityKey then
        return true
    end

    local abilityComponent = item.module and item.module.ability
    if abilityComponent then
        item._activatableType = item._activatableType or "ability"
        item._abilityKey = item._abilityKey or abilityComponent.id
        return true
    end

    return false
end

local function trigger_module_ability(player, item)
    if not (player and item and player._abilityState and player._abilitySlotLookup) then
        return false
    end

    local key = item._abilityKey
    if not key then
        return false
    end

    local slotEntry = player._abilitySlotLookup[key]
    local state = player._abilityState[key]
    if not (slotEntry and state) then
        return false
    end

    state._hotbarTrigger = true
    state._hotbarTriggerHold = slotEntry.ability and (slotEntry.ability.continuous == true or slotEntry.ability.holdToActivate == true)

    if love and love.timer and type(love.timer.getTime) == "function" then
        state._hotbarTriggerTime = love.timer.getTime()
    elseif type(os) == "table" and type(os.clock) == "function" then
        state._hotbarTriggerTime = os.clock()
    else
        state._hotbarTriggerTime = 0
    end

    return true
end

local function clear_weapon(player)
    player.weapon = nil
    if player.weaponMount then
        player.weaponMount = nil
    end
end

function HotbarManager.applySelectedWeapon(player)
    if not player then
        return false
    end

    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then
        return false
    end

    local selectedIndex = hotbar.selectedIndex or 1
    if selectedIndex < 1 or selectedIndex > HOTBAR_SIZE then
        return false
    end

    local selectedItem = hotbar.slots[selectedIndex]

    if is_weapon_item(selectedItem) then
        if activate_weapon_from_item(player, selectedItem) then
            return true
        end
    elseif is_activatable_module(selectedItem) then
        clear_weapon(player)
        return trigger_module_ability(player, selectedItem)
    end

    clear_weapon(player)

    return false
end

--- Initialize hotbar on player entity
---@param player table
function HotbarManager.initialize(player)
    if not player then return end
    
    player.hotbar = player.hotbar or {
        slots = {},
        selectedIndex = 1,
    }
    
    -- Ensure we have exactly HOTBAR_SIZE slots
    for i = 1, HOTBAR_SIZE do
        if not player.hotbar.slots[i] then
            player.hotbar.slots[i] = nil  -- Empty slot
        end
    end
    
    return player.hotbar
end

--- Get hotbar data
---@param player table
---@return table|nil
function HotbarManager.getHotbar(player)
    if not player then return nil end
    if not player.hotbar then
        return HotbarManager.initialize(player)
    end
    return player.hotbar
end

--- Set an item in a hotbar slot
---@param player table
---@param slotIndex number 1-based slot index
---@param item table|nil Item instance or nil to clear
---@return boolean success
function HotbarManager.setSlot(player, slotIndex, item)
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return false end
    
    if slotIndex < 1 or slotIndex > HOTBAR_SIZE then
        return false
    end
    
    hotbar.slots[slotIndex] = item
    if hotbar.selectedIndex == slotIndex then
        HotbarManager.applySelectedWeapon(player)
    end

    return true
end

--- Get item from hotbar slot
---@param player table
---@param slotIndex number
---@return table|nil item
function HotbarManager.getSlot(player, slotIndex)
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return nil end
    
    if slotIndex < 1 or slotIndex > HOTBAR_SIZE then
        return nil
    end
    
    return hotbar.slots[slotIndex]
end

local function find_empty_slot(hotbar)
    for i = 1, HOTBAR_SIZE do
        if not hotbar.slots[i] then
            return i
        end
    end
    return nil
end

local function ensure_item_hotbar_reference(item, slotIndex)
    if type(item) == "table" then
        item._hotbarSlot = slotIndex
    end
end

function HotbarManager.syncActivatableModules(player, abilitySlots)
    if not player then return end

    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return end

    abilitySlots = abilitySlots or {}

    local occupiedByAbility = {}
    for _, entry in ipairs(abilitySlots) do
        local item = entry.item
        if item then
            occupiedByAbility[item] = true
        end
    end

    for slotIndex = 1, HOTBAR_SIZE do
        local slotItem = hotbar.slots[slotIndex]
        if slotItem and slotItem._activatableType == "ability" and not occupiedByAbility[slotItem] then
            hotbar.slots[slotIndex] = nil
        end
    end

    for _, entry in ipairs(abilitySlots) do
        local item = entry.item
        if item then
            local preferred = item._hotbarSlot
            local index = preferred
            if not (index and hotbar.slots[index] == item) then
                local existing
                if preferred and hotbar.slots[preferred] == nil then
                    index = preferred
                else
                    for i = 1, HOTBAR_SIZE do
                        if hotbar.slots[i] == item then
                            existing = i
                            break
                        end
                    end
                    if not existing then
                        index = find_empty_slot(hotbar)
                    end
                end

                if existing then
                    index = existing
                end

                if index then
                    hotbar.slots[index] = item
                    ensure_item_hotbar_reference(item, index)
                end
            else
                ensure_item_hotbar_reference(item, index)
            end
        end
    end

    local selectedIndex = hotbar.selectedIndex or 1
    if selectedIndex >= 1 and selectedIndex <= HOTBAR_SIZE then
        local selectedItem = hotbar.slots[selectedIndex]
        if selectedItem and selectedItem._activatableType == "ability" then
            HotbarManager.applySelectedWeapon(player)
        end
    end
end

--- Swap two hotbar slots
---@param player table
---@param slotA number
---@param slotB number
---@return boolean success
function HotbarManager.swapSlots(player, slotA, slotB)
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return false end
    
    if slotA < 1 or slotA > HOTBAR_SIZE or slotB < 1 or slotB > HOTBAR_SIZE then
        return false
    end
    
    local temp = hotbar.slots[slotA]
    hotbar.slots[slotA] = hotbar.slots[slotB]
    hotbar.slots[slotB] = temp
    -- Debugging: log slot swap
    if temp and (temp.id or temp.blueprintId or temp.name) then
        print(string.format("[HOTBAR] swapSlots: %d <-> %d : %s <-> %s",
            slotA, slotB, tostring(temp.id or temp.blueprintId or temp.name),
            tostring((hotbar.slots[slotA] and (hotbar.slots[slotA].id or hotbar.slots[slotA].blueprintId or hotbar.slots[slotA].name)) or "nil")))
    else
        print(string.format("[HOTBAR] swapSlots: %d <-> %d", slotA, slotB))
    end
    
    if hotbar.selectedIndex == slotA or hotbar.selectedIndex == slotB then
        HotbarManager.applySelectedWeapon(player)
    end

    return true
end

--- Move item from cargo to hotbar slot
---@param player table
---@param cargoItem table Item from cargo
---@param slotIndex number Target hotbar slot
---@return boolean success
function HotbarManager.moveFromCargo(player, cargoItem, slotIndex)
    if not player or not cargoItem then return false end
    
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return false end
    
    if slotIndex < 1 or slotIndex > HOTBAR_SIZE then
        return false
    end
    
    -- Ensure cargo exists
    if not player.cargo or not player.cargo.items then
        return false
    end
    
    -- If slot is occupied, swap back to cargo
    local existingItem = hotbar.slots[slotIndex]
    if existingItem then
        -- Put existing item back in cargo
        table.insert(player.cargo.items, existingItem)
    end
    
    -- Remove from cargo
    for i = #player.cargo.items, 1, -1 do
        if player.cargo.items[i] == cargoItem then
            table.remove(player.cargo.items, i)
            break
        end
    end
    
    -- Place in hotbar
    hotbar.slots[slotIndex] = cargoItem
    
    player.cargo.dirty = true
    
    if hotbar.selectedIndex == slotIndex then
        HotbarManager.applySelectedWeapon(player)
    end
    
    return true
end

--- Move item from hotbar to cargo
---@param player table
---@param slotIndex number Source hotbar slot
---@return boolean success
function HotbarManager.moveToCargo(player, slotIndex)
    if not player then return false end
    
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return false end
    
    if slotIndex < 1 or slotIndex > HOTBAR_SIZE then
        return false
    end
    
    local item = hotbar.slots[slotIndex]
    if not item then return false end
    
    -- Add to cargo
    if not player.cargo or not player.cargo.items then
        return false
    end
    
    table.insert(player.cargo.items, item)
    hotbar.slots[slotIndex] = nil
    
    if player.cargo then
        player.cargo.dirty = true
    end
    
    if hotbar.selectedIndex == slotIndex then
        HotbarManager.applySelectedWeapon(player)
    end
    
    return true
end

--- Clear a hotbar slot (returns item to cargo)
---@param player table
---@param slotIndex number
---@return boolean success
function HotbarManager.clearSlot(player, slotIndex)
    return HotbarManager.moveToCargo(player, slotIndex)
end

--- Set selected slot index
---@param player table
---@param slotIndex number
---@return boolean success
function HotbarManager.setSelected(player, slotIndex)
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return false end
    
    if slotIndex < 1 or slotIndex > HOTBAR_SIZE then
        return false
    end
    
    hotbar.selectedIndex = slotIndex
    HotbarManager.applySelectedWeapon(player)
    return true
end

--- Get selected slot index
---@param player table
---@return number|nil
function HotbarManager.getSelected(player)
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return nil end
    return hotbar.selectedIndex or 1
end

--- Get selected item
---@param player table
---@return table|nil
function HotbarManager.getSelectedItem(player)
    local selected = HotbarManager.getSelected(player)
    if not selected then return nil end
    return HotbarManager.getSlot(player, selected)
end

--- Cycle selected slot
---@param player table
---@param direction number 1 for next, -1 for previous
---@return boolean success
function HotbarManager.cycle(player, direction)
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return false end
    
    local current = hotbar.selectedIndex or 1
    local next = current + (direction or 1)
    
    if next < 1 then
        next = HOTBAR_SIZE
    elseif next > HOTBAR_SIZE then
        next = 1
    end
    
    hotbar.selectedIndex = next
    HotbarManager.applySelectedWeapon(player)
    return true
end

--- Autopopulate empty hotbar slots from cargo
---@param player table
---@param options table|nil Options: {weaponsOnly: boolean}
function HotbarManager.autopopulate(player, options)
    if not player then return end
    
    options = options or {}
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar then return end
    
    if not player.cargo or not player.cargo.items then return end
    
    -- Find empty slots
    local emptySlots = {}
    for i = 1, HOTBAR_SIZE do
        if not hotbar.slots[i] then
            table.insert(emptySlots, i)
        end
    end
    
    if #emptySlots == 0 then return end
    
    -- Find suitable items from cargo
    local availableItems = {}
    for i = 1, #player.cargo.items do
        local item = player.cargo.items[i]
        if item then
            -- Check if item is already in hotbar
            local alreadyInHotbar = false
            for j = 1, HOTBAR_SIZE do
                if hotbar.slots[j] == item then
                    alreadyInHotbar = true
                    break
                end
            end
            
            if not alreadyInHotbar then
                if options.weaponsOnly then
                    if item.type == "weapon" or item.blueprintCategory == "weapons" then
                        table.insert(availableItems, item)
                    end
                else
                    table.insert(availableItems, item)
                end
            end
        end
    end
    
    -- Fill empty slots with available items
    local itemIndex = 1
    for _, slotIndex in ipairs(emptySlots) do
        if itemIndex <= #availableItems then
            -- Don't remove from cargo, just reference it
            -- This allows items to stay in cargo while being on hotbar
            local item = availableItems[itemIndex]
            hotbar.slots[slotIndex] = item
            itemIndex = itemIndex + 1
        else
            break
        end
    end

    HotbarManager.applySelectedWeapon(player)
end

--- Check if an item is in the hotbar
---@param player table
---@param item table
---@return number|nil slotIndex
function HotbarManager.findItem(player, item)
    local hotbar = HotbarManager.getHotbar(player)
    if not hotbar or not item then return nil end
    
    for i = 1, HOTBAR_SIZE do
        if hotbar.slots[i] == item then
            return i
        end
    end
    
    return nil
end

return HotbarManager
