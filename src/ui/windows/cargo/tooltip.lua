-- Cargo Tooltip: Item tooltip generation and weapon stat formatting
-- Handles detailed item information display for hover tooltips

local Items = require("src.items.registry")
local loader = require("src.blueprints.loader")

local CargoTooltip = {}

---@alias CargoTooltipBody string[]
---@alias CargoItem table
---@alias CargoWeaponData table

--- Formats a number with appropriate decimal places
---@param value number The value to format
---@param decimals number|nil Optional decimal places
---@return string The formatted number
local function format_number(value, decimals)
    if type(value) ~= "number" then
        return tostring(value or "--")
    end

    if not decimals then
        if math.abs(value - math.floor(value)) < 0.001 then
            return string.format("%d", value)
        end

        local magnitude = math.abs(value)
        if magnitude >= 100 then
            decimals = 0
        elseif magnitude >= 10 then
            decimals = 1
        else
            decimals = 2
        end
    end

    return string.format("%." .. tostring(decimals) .. "f", value)
end

--- Capitalizes the first letter of a string
---@param value string The string to capitalize
---@return string The capitalized string
local function capitalize(value)
    if type(value) ~= "string" or value == "" then
        return value
    end
    return value:sub(1, 1):upper() .. value:sub(2)
end

--- Appends a line to the body array if text is valid
---@param body CargoTooltipBody The body array
---@param text string|nil The text to append
local function append_line(body, text)
    if type(text) == "string" and text ~= "" then
        body[#body + 1] = text
    end
end

--- Checks if an item is a weapon
---@param target CargoItem|nil The item to check
---@return boolean True if the item is a weapon
local function is_weapon_item(target)
    if type(target) ~= "table" then
        return false
    end
    if target.type == "weapon" then
        return true
    end
    if target.blueprintCategory == "weapons" then
        return true
    end
    if type(target.id) == "string" and target.id:match("^weapon:") then
        return true
    end
    return false
end

--- Extracts blueprint ID from an item
---@param target CargoItem|nil The item
---@return string|nil The blueprint ID
local function extract_blueprint_id(target)
    if type(target) ~= "table" then
        return nil
    end
    if type(target.blueprintId) == "string" then
        return target.blueprintId
    end
    if type(target.id) == "string" then
        local blueprintId = target.id:match("^weapon:(.+)")
        if blueprintId then
            return blueprintId
        end
    end
    return nil
end

--- Generates weapon stats for tooltip
---@param weapon_data CargoWeaponData The weapon data
---@return string[] Array of weapon stat strings
local function generate_weapon_stats(weapon_data)
    local weapon_stats = {}

    ---@param label string
    ---@param value string|number|nil
    ---@param suffix string|nil
    ---@param decimals number|nil
    local function append_weapon_stat(label, value, suffix, decimals)
        if value == nil then
            return
        end
        local text
        if type(value) == "number" then
            text = format_number(value, decimals)
        else
            text = tostring(value)
        end
        if suffix then
            text = text .. suffix
        end
        weapon_stats[#weapon_stats + 1] = string.format("%s: %s", label, text)
    end

    append_weapon_stat("Mode", weapon_data.fireMode and capitalize(weapon_data.fireMode))

    if weapon_data.damage then
        append_weapon_stat("Damage", weapon_data.damage)
    end

    if weapon_data.damagePerSecond then
        append_weapon_stat("Damage/sec", weapon_data.damagePerSecond)
    end

    if weapon_data.fireRate and weapon_data.fireRate > 0 then
        local rate_text = format_number(weapon_data.fireRate, 2)
        local per_second = 1 / weapon_data.fireRate
        weapon_stats[#weapon_stats + 1] = string.format(
            "Rate: %s s between shots (%s/s)",
            rate_text,
            format_number(per_second, 1)
        )
    end

    if weapon_data.beamDuration then
        append_weapon_stat("Beam Duration", weapon_data.beamDuration, " s", 2)
    end

    if weapon_data.projectileSpeed then
        append_weapon_stat("Projectile Speed", weapon_data.projectileSpeed)
    end

    if weapon_data.projectileLifetime then
        append_weapon_stat("Projectile Lifetime", weapon_data.projectileLifetime, " s", 2)
    end

    if weapon_data.maxRange then
        append_weapon_stat("Range", weapon_data.maxRange)
    elseif weapon_data.projectileSpeed and weapon_data.projectileLifetime then
        append_weapon_stat("Range", weapon_data.projectileSpeed * weapon_data.projectileLifetime)
    end

    if weapon_data.projectileSize then
        append_weapon_stat("Projectile Size", weapon_data.projectileSize)
    end

    if weapon_data.width then
        append_weapon_stat("Beam Width", weapon_data.width)
    end

    if weapon_data.damageType then
        append_weapon_stat("Damage Type", capitalize(weapon_data.damageType))
    end

    return weapon_stats
end

--- Creates a tooltip for an item
---@param item CargoItem|nil The item to create a tooltip for
---@param overrideDescription string|nil Optional description override
function CargoTooltip.create(item, overrideDescription)
    if not item then
        return
    end

    local tooltip = require("src.ui.components.tooltip")
    local definition = item.id and Items.get(item.id) or nil

    local tooltip_body = {} ---@type CargoTooltipBody

    -- Basic item info
    local item_type = (definition and definition.type) or item.type
    if item_type then
        append_line(tooltip_body, string.format("Type: %s", capitalize(tostring(item_type))))
    end

    if item.stackable ~= nil then
        append_line(tooltip_body, string.format("Stackable: %s", item.stackable and "Yes" or "No"))
    end

    if item.installed ~= nil then
        append_line(tooltip_body, string.format("Installed: %s", item.installed and "Yes" or "No"))
    end

    local slot = item.slot or (definition and definition.assign)
    if slot then
        append_line(tooltip_body, string.format("Slot: %s", tostring(slot)))
    end

    local quantity = item.quantity or (definition and definition.defaultQuantity)
    if quantity then
        append_line(tooltip_body, string.format("Quantity: %s", format_number(quantity, 0)))
    end

    local per_unit_volume = item.volume or item.unitVolume or (definition and (definition.volume or definition.unitVolume))
    if per_unit_volume then
        append_line(tooltip_body, string.format("Volume (per): %s", format_number(per_unit_volume)))
        if quantity and quantity > 1 then
            append_line(tooltip_body, string.format("Volume (total): %s", format_number(per_unit_volume * quantity)))
        end
    end

    local description = overrideDescription or item.description or (definition and definition.description)

    -- Weapon-specific info
    if is_weapon_item(item) then
        local blueprint_id = extract_blueprint_id(item)
        local blueprint_weapon

        if blueprint_id then
            local ok, blueprint = pcall(loader.load, "weapons", blueprint_id)
            if ok and type(blueprint) == "table" then
                local components = blueprint.components
                if type(components) == "table" then
                    blueprint_weapon = components.weapon
                end
                if not description then
                    description = blueprint.description or blueprint.summary
                end
            end
        end

        local weapon_data = blueprint_weapon or (item.metadata and item.metadata.weapon)

        if type(weapon_data) == "table" then
            local weapon_stats = generate_weapon_stats(weapon_data)
            
            if #weapon_stats > 0 then
                append_line(tooltip_body, "Weapon Stats:")
                for i = 1, #weapon_stats do
                    append_line(tooltip_body, "  " .. weapon_stats[i])
                end
            end
        end
    end

    -- Request tooltip display
    tooltip.request({
        heading = item.name or (definition and definition.name) or "Unknown Item",
        body = tooltip_body,
        description = description,
    })
end

return CargoTooltip
