local loader = require("src.blueprints.loader")

local PlayerWeapons = {}

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

local function extract_blueprint_id(item)
    if type(item) ~= "table" then
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

local function reuse_or_create_entry(previous, key)
    if previous and key then
        return previous[key] or {}
    end
    return {}
end

local function index_previous_entries(player)
    local previous = {}
    local slots = player.weaponSlots
    if slots and slots.list then
        for _, entry in ipairs(slots.list) do
            if entry._key then
                previous[entry._key] = entry
            end
        end
    end
    return previous
end

local function refresh_slots(player)
    local previousEntries = index_previous_entries(player)
    local list = {}
    local activeWeaponComponent = player.weapon

    local cargoItems = player.cargo and player.cargo.items
    if type(cargoItems) == "table" then
        for i = 1, #cargoItems do
            local item = cargoItems[i]
            if is_weapon_item(item) then
                local key = tostring(item)
                local entry = reuse_or_create_entry(previousEntries, key)
                entry.item = item
                entry._key = key
                entry.blueprintId = extract_blueprint_id(item) or entry.blueprintId
                entry.name = item.name or entry.name or entry.blueprintId or "Weapon"
                entry.icon = item.icon or entry.icon
                entry.installed = not not item.installed
                list[#list + 1] = entry
            end
        end
    end

    local weapons = player.weapons
    if type(weapons) == "table" then
        for w = 1, #weapons do
            local weapon = weapons[w]
            if weapon then
                local blueprint = weapon.blueprint or {}
                local blueprintId = blueprint.id
                local entry

                if blueprintId then
                    for i = 1, #list do
                        local candidate = list[i]
                        if candidate.blueprintId == blueprintId and (candidate.weaponInstance == nil or candidate.weaponInstance == weapon) then
                            entry = candidate
                            break
                        end
                    end
                end

                if not entry then
                    local key = "weapon:" .. tostring(weapon)
                    entry = reuse_or_create_entry(previousEntries, key)
                    entry._key = key
                    entry.blueprintId = blueprintId or entry.blueprintId
                    entry.icon = entry.icon or blueprint.icon
                    entry.name = entry.name or blueprint.name or blueprintId or "Weapon"
                    list[#list + 1] = entry
                end

                entry.weaponInstance = weapon
            end
        end
    end

    local selectedIndex
    if #list > 0 then
        for i = 1, #list do
            local entry = list[i]
            if entry.weaponInstance and activeWeaponComponent and entry.weaponInstance.weapon == activeWeaponComponent then
                selectedIndex = i
                break
            end
        end

        if not selectedIndex then
            for i = 1, #list do
                local entry = list[i]
                if entry.item and entry.item.installed then
                    selectedIndex = i
                    break
                end
            end
        end

        if not selectedIndex and player.weaponSlots and player.weaponSlots.selectedIndex then
            local previousIndex = player.weaponSlots.selectedIndex
            if previousIndex >= 1 and previousIndex <= #list then
                selectedIndex = previousIndex
            end
        end

        if not selectedIndex then
            selectedIndex = 1
        end
    else
        selectedIndex = 0
    end

    player.weaponSlots = {
        list = list,
        selectedIndex = (#list > 0) and selectedIndex or nil,
        selectedEntry = (selectedIndex and selectedIndex >= 1 and selectedIndex <= #list) and list[selectedIndex] or nil,
    }

    return player.weaponSlots
end

function PlayerWeapons.refreshSlots(player)
    if not player then
        return nil
    end
    return refresh_slots(player)
end

function PlayerWeapons.getSlots(player, options)
    if not player then
        return nil
    end

    options = options or {}
    if options.refresh or not (player.weaponSlots and player.weaponSlots.list) then
        refresh_slots(player)
    end

    return player.weaponSlots
end

local function ensure_entry_weapon(player, entry)
    if not entry then
        return nil
    end

    if entry.weaponInstance then
        return entry.weaponInstance
    end

    local blueprintId = entry.blueprintId
    if not blueprintId then
        return nil
    end

    local context = { owner = player }
    if entry.item and entry.item.mount then
        context.mount = entry.item.mount
    end

    local ok, weaponInstance = pcall(loader.instantiate, "weapons", blueprintId, context)
    if not ok then
        return nil
    end

    entry.weaponInstance = weaponInstance
    if entry.item then
        entry.item.installed = true
    end

    return weaponInstance
end

function PlayerWeapons.selectByIndex(player, index, options)
    if not player then
        return nil
    end

    options = options or {}
    local slots = options.skipRefresh and player.weaponSlots or PlayerWeapons.getSlots(player)
    if not (slots and slots.list and #slots.list > 0) then
        return nil
    end

    local count = #slots.list
    if index < 1 then
        index = 1
    elseif index > count then
        index = count
    end

    local previousIndex = slots.selectedIndex or 0
    local previousEntry = slots.list[previousIndex]

    local entry = slots.list[index]
    if not entry then
        return nil
    end

    if previousEntry and previousEntry ~= entry and previousEntry.weaponInstance and previousEntry.weaponInstance.weapon then
        previousEntry.weaponInstance.weapon.firing = false
    end

    local weaponInstance = ensure_entry_weapon(player, entry)
    if not (weaponInstance and weaponInstance.weapon) then
        return nil
    end

    player.weapon = weaponInstance.weapon
    if weaponInstance.weaponMount then
        player.weaponMount = weaponInstance.weaponMount
    end

    for i = 1, #slots.list do
        local other = slots.list[i]
        if other ~= entry and other.item then
            other.item.installed = false
        end
    end
    if entry.item then
        entry.item.installed = true
    end

    if weaponInstance.weapon then
        weaponInstance.weapon.firing = false
    end

    slots.selectedIndex = index
    slots.selectedEntry = entry

    return entry
end

function PlayerWeapons.cycle(player, direction)
    if not player then
        return false
    end

    local slots = PlayerWeapons.getSlots(player, { refresh = true })
    if not (slots and slots.list and #slots.list > 0) then
        return false
    end

    local count = #slots.list
    if count <= 1 then
        return false
    end

    local currentIndex = slots.selectedIndex or 1
    if currentIndex < 1 or currentIndex > count then
        currentIndex = 1
    end
    direction = direction or 1
    local newIndex = ((currentIndex - 1 + direction) % count) + 1

    if newIndex == currentIndex then
        return false
    end

    return PlayerWeapons.selectByIndex(player, newIndex) ~= nil
end

function PlayerWeapons.getCurrentEntry(player, options)
    local slots = PlayerWeapons.getSlots(player, options)
    if not (slots and slots.list and #slots.list > 0) then
        return nil
    end

    local index = slots.selectedIndex or 1
    if index < 1 or index > #slots.list then
        index = math.max(1, math.min(#slots.list, index))
        slots.selectedIndex = index
    end

    return slots.list[index], index, #slots.list
end

function PlayerWeapons.initialize(player)
    if not player then
        return
    end

    local slots = refresh_slots(player)
    if not (slots and slots.list and #slots.list > 0) then
        return
    end

    local index = slots.selectedIndex
    if not index or index < 1 or index > #slots.list then
        index = 1
    end

    PlayerWeapons.selectByIndex(player, index, { skipRefresh = true })
end

return PlayerWeapons
