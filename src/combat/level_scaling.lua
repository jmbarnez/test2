local constants = require("src.constants.game")

local LevelScaling = {}

local DEFAULTS = {
    hull = 0.18,
    health = 0.18,
    shield = 0.18,
    damage = 0.12,
    speed = 0.04,
    credits = 0.12,
    xp = 0.16,
}

local function resolve_config()
    local enemy_constants = constants.enemies or {}
    return enemy_constants.level_scaling or DEFAULTS
end

local function compute_multiplier(rate, delta)
    if not rate or rate == 0 or delta <= 0 then
        return 1
    end

    return (1 + rate) ^ delta
end

local function scale_number(value, multiplier, minimum)
    if type(value) ~= "number" or multiplier == 1 then
        return value
    end

    local scaled = value * multiplier
    if minimum then
        scaled = math.max(minimum, scaled)
    end

    return math.floor(scaled + 0.5)
end

local function scale_resource(resource, multiplier)
    if type(resource) ~= "table" or multiplier == 1 then
        return
    end

    if resource.max then
        resource.max = scale_number(resource.max, multiplier, 1)
    end

    if resource.current then
        resource.current = scale_number(resource.current, multiplier, 1)
        if resource.max then
            resource.current = math.min(resource.current, resource.max)
        end
    end

    if resource.capacity then
        resource.capacity = scale_number(resource.capacity, multiplier, 1)
    end

    if resource.limit then
        resource.limit = scale_number(resource.limit, multiplier, 1)
    end
end

local function apply_speed_scaling(stats, multiplier)
    if type(stats) ~= "table" or multiplier == 1 then
        return
    end

    if stats.max_speed then
        stats.max_speed = scale_number(stats.max_speed, multiplier, 0)
    end

    if stats.turn_speed then
        stats.turn_speed = scale_number(stats.turn_speed, multiplier, 0)
    end
end

local function apply_thrust_scaling(stats, multiplier)
    if type(stats) ~= "table" or multiplier == 1 then
        return
    end

    local keys = {
        "main_thrust",
        "strafe_thrust",
        "reverse_thrust",
        "thrust_force",
        "max_acceleration",
    }

    for index = 1, #keys do
        local key = keys[index]
        if stats[key] then
            stats[key] = scale_number(stats[key], multiplier, 0)
        end
    end
end

local function scale_reward_entry(entry, credit_multiplier, xp_multiplier)
    if type(entry) ~= "table" then
        return
    end

    if entry.credit_reward and credit_multiplier ~= 1 then
        if type(entry.credit_reward) == "number" then
            entry.credit_reward = scale_number(entry.credit_reward, credit_multiplier, 1)
        elseif type(entry.credit_reward) == "table" then
            local reward = entry.credit_reward
            if reward.min then
                reward.min = scale_number(reward.min, credit_multiplier, 1)
            end
            if reward.max then
                reward.max = scale_number(reward.max, credit_multiplier, 1)
            end
            if reward.amount then
                reward.amount = scale_number(reward.amount, credit_multiplier, 1)
            end
        end
    end

    if entry.xp_reward and xp_multiplier ~= 1 then
        if type(entry.xp_reward) == "number" then
            entry.xp_reward = scale_number(entry.xp_reward, xp_multiplier, 1)
        elseif type(entry.xp_reward) == "table" then
            local reward = entry.xp_reward
            if reward.amount then
                reward.amount = scale_number(reward.amount, xp_multiplier, 1)
            end
            if reward.min then
                reward.min = scale_number(reward.min, xp_multiplier, 1)
            end
            if reward.max then
                reward.max = scale_number(reward.max, xp_multiplier, 1)
            end
        end
    end
end

local function apply_loot_scaling(enemy, credit_multiplier, xp_multiplier)
    if credit_multiplier == 1 and xp_multiplier == 1 then
        return
    end

    local loot = enemy.loot
    if type(loot) ~= "table" or type(loot.entries) ~= "table" then
        return
    end

    for index = 1, #loot.entries do
        scale_reward_entry(loot.entries[index], credit_multiplier, xp_multiplier)
    end
end

local function ensure_level_table(levelData)
    if type(levelData) ~= "table" then
        return nil
    end

    levelData.current = math.max(1, math.floor((levelData.current or levelData.value or levelData.level or 1) + 0.5))
    levelData.base = math.max(1, math.floor((levelData.base or levelData.baseLevel or levelData.base_level or 1) + 0.5))

    return levelData
end

function LevelScaling.apply(enemy)
    if type(enemy) ~= "table" or enemy._levelScalingApplied then
        return enemy
    end

    local levelData = ensure_level_table(enemy.level)
    if not levelData then
        return enemy
    end

    local delta = math.max(0, (levelData.current or 1) - (levelData.base or 1))
    if delta <= 0 then
        return enemy
    end

    local config = resolve_config()

    local health_multiplier = compute_multiplier(config.health or config.hull, delta)
    local hull_multiplier = compute_multiplier(config.hull or config.health, delta)
    local shield_multiplier = compute_multiplier(config.shield or config.health, delta)
    local damage_multiplier = compute_multiplier(config.damage, delta)
    local speed_multiplier = compute_multiplier(config.speed, delta)
    local credit_multiplier = compute_multiplier(config.credits, delta)
    local xp_multiplier = compute_multiplier(config.xp, delta)

    if enemy.health then
        scale_resource(enemy.health, health_multiplier)
    end
    if enemy.hull and enemy.hull ~= enemy.health then
        scale_resource(enemy.hull, hull_multiplier)
    end
    if enemy.shield then
        scale_resource(enemy.shield, shield_multiplier)
    end
    if enemy.energy then
        scale_resource(enemy.energy, health_multiplier)
    end

    if enemy.stats then
        apply_thrust_scaling(enemy.stats, health_multiplier)
        apply_speed_scaling(enemy.stats, speed_multiplier)
    end

    apply_loot_scaling(enemy, credit_multiplier, xp_multiplier)

    enemy.levelScaling = enemy.levelScaling or {}
    enemy.levelScaling.damage = (enemy.levelScaling.damage or 1) * damage_multiplier
    enemy.levelScaling.speed = (enemy.levelScaling.speed or 1) * speed_multiplier
    enemy.levelScaling.health = (enemy.levelScaling.health or 1) * health_multiplier

    levelData.delta = delta
    levelData.applied = true

    enemy._levelScalingApplied = true

    return enemy
end

return LevelScaling
