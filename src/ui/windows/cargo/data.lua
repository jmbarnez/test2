-- Cargo Data: Item management, sorting, filtering, and currency formatting
-- Handles cargo item operations and data transformations

local CargoData = {}

--- Sort modes for cargo display
CargoData.SORT_MODES = {
    name = { label = "Name", next = "quantity" },
    quantity = { label = "Quantity", next = "name" },
}

--- Creates a shallow copy of an item list
---@param list table The item list to copy
---@return table A copy of the list
local function copy_items(list)
    local result = {}
    for i = 1, #list do
        result[i] = list[i]
    end
    return result
end

--- Sorts items by the specified mode
---@param items table The items to sort (modified in place)
---@param mode string "name" or "quantity"
function CargoData.sortItems(items, mode)
    if #items <= 1 then
        return
    end
    
    if mode == "quantity" then
        table.sort(items, function(a, b)
            if not a then
                return false
            end
            if not b then
                return true
            end
            local qa = tonumber(a.quantity) or 0
            local qb = tonumber(b.quantity) or 0
            if qa == qb then
                local nameA = tostring(a.name or ""):lower()
                local nameB = tostring(b.name or ""):lower()
                return nameA < nameB
            end
            return qa > qb
        end)
        return
    end
    
    -- Sort by name
    table.sort(items, function(a, b)
        if not a then
            return false
        end
        if not b then
            return true
        end
        local nameA = tostring(a.name or ""):lower()
        local nameB = tostring(b.name or ""):lower()
        if nameA == nameB then
            local qa = tonumber(a.quantity) or 0
            local qb = tonumber(b.quantity) or 0
            return qa > qb
        end
        return nameA < nameB
    end)
end

--- Filters items by search query
---@param items table The items to filter
---@param query string The search query
---@return table Filtered items
function CargoData.filterItems(items, query)
    if not query or query == "" then
        return copy_items(items)
    end
    
    local lowerQuery = query:lower()
    local filtered = {}
    for _, item in ipairs(items) do
        local name = item and item.name
        if type(name) == "string" and name:lower():find(lowerQuery, 1, true) then
            filtered[#filtered + 1] = item
        end
    end
    return filtered
end

--- Formats a currency value with thousands separators
---@param value number The currency value
---@return string The formatted currency string
function CargoData.formatCurrency(value)
    if type(value) ~= "number" then
        return tostring(value or "--")
    end

    local rounded = math.floor(value + 0.5)
    local absValue = math.abs(rounded)
    local chunks = {}

    repeat
        local remainder = absValue % 1000
        absValue = math.floor(absValue / 1000)
        if absValue > 0 then
            chunks[#chunks + 1] = string.format("%03d", remainder)
        else
            chunks[#chunks + 1] = tostring(remainder)
        end
    until absValue == 0

    local ordered = {}
    for index = #chunks, 1, -1 do
        ordered[#ordered + 1] = chunks[index]
    end

    local formatted = table.concat(ordered, ",")
    if rounded < 0 then
        formatted = "-" .. formatted
    end

    return formatted
end

--- Gets cargo information from player entity
---@param player table The player entity
---@return table Cargo info with items, used, capacity, available, percentFull
function CargoData.getCargoInfo(player)
    local cargo = player and player.cargo
    if cargo and cargo.refresh then
        cargo:refresh()
    end

    local items = (cargo and cargo.items) or {}
    local usedVolume = cargo and cargo.used or 0
    local capacityVolume = cargo and cargo.capacity or 0
    local availableVolume = cargo and cargo.available
    
    if availableVolume == nil and capacityVolume > 0 then
        availableVolume = math.max(0, capacityVolume - usedVolume)
    end
    
    local percentFull = 0
    if capacityVolume and capacityVolume > 0 then
        percentFull = usedVolume / capacityVolume
    end
    percentFull = math.max(0, math.min(percentFull, 1))

    return {
        items = items,
        used = usedVolume,
        capacity = capacityVolume,
        available = availableVolume,
        percentFull = percentFull,
    }
end

--- Gets currency value from player or context
---@param context table The game context
---@param player table The player entity
---@return number|nil The currency value
function CargoData.getCurrency(context, player)
    local PlayerManager = require("src.player.manager")
    
    local currencyValue
    if context then
        currencyValue = PlayerManager.getCurrency(context)
    end

    if currencyValue == nil and player then
        local wallet = player.wallet
        if type(wallet) == "table" and wallet.balance ~= nil then
            currencyValue = wallet.balance
        elseif type(wallet) == "number" then
            currencyValue = wallet
        end
    end

    return currencyValue
end

--- Wraps text to fit within a maximum width
---@param text string The text to wrap
---@param font table The font to use
---@param maxWidth number The maximum width
---@return table Array of text lines
function CargoData.wrapText(text, font, maxWidth)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local currentLine = ""

    for _, word in ipairs(words) do
        local testLine = currentLine == "" and word or currentLine .. " " .. word
        if font:getWidth(testLine) <= maxWidth then
            currentLine = testLine
        else
            if currentLine ~= "" then
                table.insert(lines, currentLine)
                currentLine = word
            else
                table.insert(lines, word)
            end
        end
    end

    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

return CargoData
