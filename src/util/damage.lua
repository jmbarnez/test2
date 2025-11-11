local constants = require("src.constants.game")

local damage_constants = constants.damage or {}
local multipliers = damage_constants.multipliers or {}
local default_damage_type = damage_constants.defaultDamageType or "default"
local default_armor_type = damage_constants.defaultArmorType or "default"

local damage_util = {}

local function resolve_damage_row(damage_type)
    return multipliers[damage_type] or multipliers[default_damage_type]
end

function damage_util.resolve_multiplier(damage_type, armor_type)
    local dmg_type = damage_type or default_damage_type
    local arm_type = armor_type or default_armor_type

    local row = resolve_damage_row(dmg_type)
    if row then
        local value = row[arm_type]
        if value ~= nil then
            return value
        end
        if row.default ~= nil then
            return row.default
        end
    end

    -- Fallback to default row, then final fallback of 1.0
    if dmg_type ~= default_damage_type then
        local default_row = resolve_damage_row(default_damage_type)
        if default_row then
            local value = default_row[arm_type]
            if value ~= nil then
                return value
            end
            if default_row.default ~= nil then
                return default_row.default
            end
        end
    end

    return 1.0
end

return damage_util
