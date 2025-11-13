local tiny = require("libs.tiny")
local Items = require("src.items.registry")
local table_util = require("src.util.table")

---@diagnostic disable-next-line: undefined-global
local love = love
local math = math

local deep_copy = table_util.deep_copy

local function resolve_quantity(spec, default)
    if type(spec) == "table" then
        local min = spec.min or spec[1] or default or 1
        local max = spec.max or spec[2] or min
        if min > max then
            min, max = max, min
        end
        min = math.floor(min + 0.5)
        max = math.floor(max + 0.5)
        return love.math.random(min, max)
    elseif type(spec) == "number" then
        return spec
    end
    return default or 1
end

local function should_drop(chance)
    if chance == nil then
        return true
    end
    if chance <= 0 then
        return false
    end
    if chance >= 1 then
        return true
    end
    return love.math.random() < chance
end

local function instantiate_item(entry, quantity)
    if not entry.id then
        return nil, nil
    end

    local overrides
    if type(entry.overrides) == "table" then
        overrides = deep_copy(entry.overrides)
    else
        overrides = {}
    end

    overrides.quantity = quantity

    local item, err = Items.instantiate(entry.id, overrides)
    if not item then
        return nil, err or "instantiate_failed"
    end

    return item
end

local function roll_loot(loot_config)
    if type(loot_config) ~= "table" then
        return nil
    end

    local entries = loot_config.entries
    if type(entries) ~= "table" or #entries == 0 then
        return nil
    end

    local rolls = loot_config.rolls or 1
    if rolls < 1 then
        rolls = 1
    end

    local drops = {}
    for _ = 1, rolls do
        for index = 1, #entries do
            local entry = entries[index]
            if type(entry) == "table" and should_drop(entry.chance) then
                local quantity = resolve_quantity(entry.quantity, 1)
                local item, err
                if entry.id and quantity > 0 then
                    item, err = instantiate_item(entry, quantity)
                end

                local creditSpec = entry.credit_reward or entry.credits
                local creditReward
                if creditSpec ~= nil then
                    if type(creditSpec) == "table" then
                        creditReward = resolve_quantity(creditSpec, 0)
                    else
                        creditReward = tonumber(creditSpec)
                    end
                    if creditReward and creditReward <= 0 then
                        creditReward = nil
                    end
                end

                local hasItem = item ~= nil
                local hasCredits = creditReward ~= nil

                if hasItem or hasCredits then
                    local drop = {
                        id = entry.id,
                        quantity = hasItem and quantity or nil,
                        item = item,
                        error = err,
                        offset = entry.offset or entry.positionOffset,
                        scatter = entry.scatter or entry.scatterRadius,
                        credit_reward = creditReward,
                        raw = entry,
                    }
                    drops[#drops + 1] = drop
                end
            end
        end
    end

    if #drops == 0 then
        return nil
    end

    return drops
end

return function(context)
    context = context or {}

    local spawnLootItem = context.spawnLootItem or context.spawnLoot
    local pending = context.pendingLootDrops or {}
    context.pendingLootDrops = pending
    local onLootDropped = context.onLootDropped

    local system = tiny.processingSystem {
        filter = tiny.requireAll("pendingDestroy", "loot", "position"),

        process = function(self, entity)
            if entity._lootProcessed then
                return
            end

            entity._lootProcessed = true

            local drops = roll_loot(entity.loot)
            entity.loot = nil

            if not drops then
                return
            end

            local position = entity.position
            local velocity = entity.velocity

            for i = 1, #drops do
                local drop = drops[i]
                local offset = drop.offset
                local x = position.x
                local y = position.y

                if offset and type(offset) == "table" then
                    x = x + (offset.x or 0)
                    y = y + (offset.y or 0)
                end

                if drop.scatter and drop.scatter > 0 then
                    local angle = love.math.random() * math.pi * 2
                    local radius = love.math.random() * drop.scatter
                    x = x + math.cos(angle) * radius
                    y = y + math.sin(angle) * radius
                end

                drop.position = { x = x, y = y }
                if velocity then
                    drop.velocity = { x = velocity.x or 0, y = velocity.y or 0 }
                end
                drop.source = entity

                if drop.item then
                    drop.item.quantity = drop.quantity
                end

                if drop.item then
                    if spawnLootItem then
                        spawnLootItem(drop, entity, context)
                    else
                        pending[#pending + 1] = drop
                    end
                end

                if onLootDropped then
                    onLootDropped(drop, entity, context)
                end
            end
        end,
    }

    return system
end
