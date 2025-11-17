local constants = require("src.constants.game")

local damage_constants = constants.damage or {}
local multipliers = damage_constants.multipliers or {}
local default_damage_type = damage_constants.defaultDamageType or "default"
local default_armor_type = damage_constants.defaultArmorType or "default"

local damage_util = {}

local function resolve_damage_row(damage_type)
    return multipliers[damage_type] or multipliers[default_damage_type]
end

local function resolve_type_multiplier(dmg_type, arm_type)
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

function damage_util.resolve_multiplier(damage_type, armor_type, overrides)
    local dmg_type = damage_type or default_damage_type
    local arm_type = armor_type or default_armor_type

    local multiplier = resolve_type_multiplier(dmg_type, arm_type)

    if overrides and type(overrides) == "table" then
        local override = overrides[arm_type]
            or overrides.default
            or (arm_type ~= default_armor_type and overrides[default_armor_type])

        if override ~= nil then
            multiplier = multiplier * override
        end
    end

    return multiplier
end

return damage_util
