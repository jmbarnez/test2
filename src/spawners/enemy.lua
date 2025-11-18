---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local loader = require("src.blueprints.loader")
local math_util = require("src.util.math")
local PlayerManager = require("src.player.manager")
local LevelScaling = require("src.combat.level_scaling")

local TAU = math_util.TAU

local DEFAULT_STATION_EXCLUSION_RADIUS = 1500

local function resolve_station_id(spec)
    if type(spec) == "table" then
        return spec.id or spec.stationId or spec.blueprint or spec[1]
    end
    return spec
end

local function resolve_station_position(state, spec)
    if type(spec) ~= "table" then
        return nil
    end

    local offsetX, offsetY = 0, 0
    local offset = spec.offset
    if type(offset) == "table" then
        offsetX = offset.x or 0
        offsetY = offset.y or 0
    end

    if spec.position then
        local base = spec.position
        return {
            x = (base.x or 0) + offsetX,
            y = (base.y or 0) + offsetY,
        }
    end

    local bounds = state and state.worldBounds
    if bounds then
        return {
            x = (bounds.x or 0) + (bounds.width or 0) * 0.5 + offsetX,
            y = (bounds.y or 0) + (bounds.height or 0) * 0.5 + offsetY,
        }
    end

    return {
        x = offsetX,
        y = offsetY,
    }
end

local function build_restricted_zones(state)
    if type(state) ~= "table" then
        return {}
    end

    local configs = state.stationConfig
    if type(configs) ~= "table" then
        return {}
    end

    local zones = {}

    local function consider_spec(spec)
        local position = resolve_station_position(state, spec)
        if not position then
            return
        end

        local exclusion = (type(spec) == "table" and spec.exclusion_radius)
            or DEFAULT_STATION_EXCLUSION_RADIUS
        if type(exclusion) ~= "number" or exclusion <= 0 then
            exclusion = DEFAULT_STATION_EXCLUSION_RADIUS
        end

        zones[#zones + 1] = {
            x = position.x or 0,
            y = position.y or 0,
            radius_sq = exclusion * exclusion,
        }
    end

    if configs[1] ~= nil then
        for index = 1, #configs do
            consider_spec(configs[index])
        end
    else
        for _, spec in pairs(configs) do
            consider_spec(spec)
        end
    end

    return zones
end

local function random_point_in_ring(bounds, radius, inner_override)
    local cx = bounds.x + bounds.width * 0.5
    local cy = bounds.y + bounds.height * 0.5
    local inner = inner_override or (radius * 0.4)
    local outer = radius
    local dist = love.math.random() * (outer - inner) + inner
    local angle = love.math.random() * TAU

    local x = cx + math.cos(angle) * dist
    local y = cy + math.sin(angle) * dist

    return x, y
end

local function choose_count(range)
    if type(range) == "table" then
        local min = range.min or range[1] or 1
        local max = range.max or range[2] or min
        return love.math.random(min, max)
    end
    return range or 1
end

local function clone_table(value)
    if type(value) ~= "table" then
        return nil
    end

    local copy = {}
    for key, item in pairs(value) do
        if type(item) == "table" then
            copy[key] = clone_table(item)
        else
            copy[key] = item
        end
    end
    return copy
end

local function normalize_level_value(source)
    if source == nil then
        return nil
    end

    if type(source) == "number" then
        local value = math.floor(source + 0.5)
        return { current = math.max(1, value) }
    elseif type(source) == "table" then
        local copy = clone_table(source) or {}
        local current = copy.current or copy.value or copy.level
        if type(current) == "number" then
            copy.current = math.max(1, math.floor(current + 0.5))
            return copy
        end

        local minValue = copy.min or copy.minimum or copy.lower or copy[1]
        local maxValue = copy.max or copy.maximum or copy.upper or copy[2] or minValue

        if type(minValue) == "number" and type(maxValue) == "number" then
            local lower = math.floor(minValue + 0.5)
            local upper = math.floor(maxValue + 0.5)
            if upper < lower then
                lower, upper = upper, lower
            end
            local rolled = love.math.random(lower, upper)
            copy.current = math.max(1, rolled)
            copy.min = lower
            copy.max = upper
            return copy
        end

        if copy.current == nil then
            copy.current = 1
        end
        copy.current = math.max(1, math.floor((copy.current or 1) + 0.5))
        return copy
    end

    return nil
end

local function resolve_enemy_level(existing, override)
    local normalized = normalize_level_value(override)
    if normalized then
        if type(existing) == "table" then
            for key, value in pairs(existing) do
                if normalized[key] == nil then
                    normalized[key] = type(value) == "table" and clone_table(value) or value
                end
            end
        end
        return normalized
    end

    normalized = normalize_level_value(existing)
    if normalized then
        return normalized
    end

    return { current = 1 }
end
local function build_variant_level(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.level ~= nil then
        if type(entry.level) == "table" then
            return clone_table(entry.level)
        end
        return entry.level
    end

    local level_range = entry.level_range or entry.levelRange or entry.levels
    if type(level_range) == "table" then
        return clone_table(level_range)
    end

    local min_value = entry.level_min or entry.levelMin
    local max_value = entry.level_max or entry.levelMax

    if min_value or max_value then
        local min_level = min_value or max_value
        local max_level = max_value or min_value or min_level

        return {
            min = min_level,
            max = max_level,
        }
    end

    return nil
end

local function normalize_ship_variants(entries)
    if type(entries) ~= "table" then
        return nil
    end

    local normalized = {}
    local total_weight = 0

    for i = 1, #entries do
        local entry = entries[i]
        local entry_type = type(entry)

        if entry_type == "string" then
            normalized[#normalized + 1] = { id = entry, weight = 1 }
            total_weight = total_weight + 1
        elseif entry_type == "table" then
            local id = entry.id or entry.ship_id or entry.shipId or entry.ship or entry[1]
            if id then
                local weight = entry.weight or entry.chance or entry.probability or 1
                if type(weight) ~= "number" then
                    weight = 1
                end
                if weight > 0 then
                    local context = nil
                    if type(entry.context) == "table" then
                        context = clone_table(entry.context)
                    end

                    local level_override = build_variant_level(entry)
                    if level_override ~= nil then
                        context = context or {}
                        context.level = level_override
                    end

                    normalized[#normalized + 1] = {
                        id = id,
                        weight = weight,
                        context = context,
                    }
                    total_weight = total_weight + weight
                end
            end
        end
    end

    if total_weight <= 0 then
        return nil
    end

    return {
        entries = normalized,
        total_weight = total_weight,
    }
end

local function pick_ship_variant(pool)
    if not pool or pool.total_weight <= 0 then
        return nil
    end

    local roll = love.math.random() * pool.total_weight
    local cumulative = 0

    for i = 1, #pool.entries do
        local entry = pool.entries[i]
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry
        end
    end

    return pool.entries[#pool.entries]
end

return function(context)
    context = context or {}

    local function should_skip_spawns()
        local state = context.state or context
        return state and state.skipProceduralSpawns
    end

    local enemyConfig = context.enemyConfig or {}
    local bounds = context.worldBounds
    if not bounds then
        return tiny.system {}
    end

    local defaultCount = enemyConfig.count or 8
    local count = choose_count(defaultCount)
    local default_ship_id = enemyConfig.ship_id or enemyConfig.shipId or enemyConfig.ship or enemyConfig.default_ship or "enemy_scout"
    local ship_variant_pool = normalize_ship_variants(enemyConfig.ship_ids or enemyConfig.shipIds or enemyConfig.ships)
    local safe_radius = enemyConfig.safe_radius or enemyConfig.spawn_safe_radius or 600

    local instantiateContext = {
        physicsWorld = context.physicsWorld,
        worldBounds = bounds,
    }

    local spawn_positions = {}
    local restricted_zones = build_restricted_zones(context.state or context)

    local function resolve_avoid_entity()
        return PlayerManager.resolveLocalPlayer(context)
    end

    local function pick_spawn_point()
        local avoid_entity = resolve_avoid_entity()
        local avoid_pos = avoid_entity and avoid_entity.position
        local safe_sq = safe_radius * safe_radius
        local spacing_sq = (enemyConfig.separation_radius or safe_radius * 0.8) ^ 2

        for attempt = 1, 50 do
            -- Spawn across the entire world bounds
            local spawn_x = love.math.random(bounds.x + safe_radius, bounds.x + bounds.width - safe_radius)
            local spawn_y = love.math.random(bounds.y + safe_radius, bounds.y + bounds.height - safe_radius)

            local valid = true

            if avoid_pos then
                local dx = spawn_x - avoid_pos.x
                local dy = spawn_y - avoid_pos.y
                if (dx * dx + dy * dy) < safe_sq then
                    valid = false
                end
            end

            if valid then
                for i = 1, #spawn_positions do
                    local pos = spawn_positions[i]
                    local dx = spawn_x - pos.x
                    local dy = spawn_y - pos.y
                    if (dx * dx + dy * dy) < spacing_sq then
                        valid = false
                        break
                    end
                end
            end

            if valid and restricted_zones and #restricted_zones > 0 then
                for i = 1, #restricted_zones do
                    local zone = restricted_zones[i]
                    local dx = spawn_x - zone.x
                    local dy = spawn_y - zone.y
                    if (dx * dx + dy * dy) < zone.radius_sq then
                        valid = false
                        break
                    end
                end
            end

            if valid then
                return spawn_x, spawn_y
            end
        end

        -- Fallback: random position in world bounds
        local fallback_x, fallback_y
        for _ = 1, 80 do
            fallback_x = love.math.random(bounds.x + safe_radius, bounds.x + bounds.width - safe_radius)
            fallback_y = love.math.random(bounds.y + safe_radius, bounds.y + bounds.height - safe_radius)

            local valid = true
            if restricted_zones and #restricted_zones > 0 then
                for i = 1, #restricted_zones do
                    local zone = restricted_zones[i]
                    local dx = fallback_x - zone.x
                    local dy = fallback_y - zone.y
                    if (dx * dx + dy * dy) < zone.radius_sq then
                        valid = false
                        break
                    end
                end
            end

            if valid then
                return fallback_x, fallback_y
            end
        end

        return fallback_x, fallback_y
    end

    local function spawn_once(world)
        if not world then
            return
        end

        for _ = 1, count do
            local spawn_x, spawn_y = pick_spawn_point()
            spawn_positions[#spawn_positions + 1] = { x = spawn_x, y = spawn_y }

            local chosen_variant = pick_ship_variant(ship_variant_pool)
            local ship_id = (chosen_variant and chosen_variant.id) or default_ship_id

            local instantiate_context = {
                position = { x = spawn_x, y = spawn_y },
                physicsWorld = instantiateContext.physicsWorld,
                worldBounds = instantiateContext.worldBounds,
            }

            if chosen_variant and chosen_variant.context then
                for key, value in pairs(chosen_variant.context) do
                    if instantiate_context[key] == nil then
                        instantiate_context[key] = value
                    end
                end
            end

            local enemy = loader.instantiate("ships", ship_id, instantiate_context)

            enemy.enemy = true
            enemy.faction = enemy.faction or "enemy"

            local variantContextLevel = chosen_variant and chosen_variant.context and chosen_variant.context.level
            local overrideLevel = instantiate_context.level or variantContextLevel or enemyConfig.level
            enemy.level = resolve_enemy_level(enemy.level, overrideLevel)
            LevelScaling.apply(enemy)

            enemy.spawnPosition = enemy.spawnPosition or { x = spawn_x, y = spawn_y }
            enemy.ai = enemy.ai or {}
            enemy.ai.home = enemy.ai.home or enemy.spawnPosition
            local wanderRadius = enemyConfig.wander_radius or math.min(bounds.width, bounds.height) * 0.3
            if wanderRadius and wanderRadius > 0 then
                enemy.ai.wanderRadius = enemy.ai.wanderRadius or wanderRadius
            end
            if enemyConfig.wander_speed then
                enemy.ai.wanderSpeed = enemy.ai.wanderSpeed or enemyConfig.wander_speed
            end
            if enemyConfig.wander_arrive_radius then
                enemy.ai.wanderArriveRadius = enemy.ai.wanderArriveRadius or enemyConfig.wander_arrive_radius
            end

            world:add(enemy)
            context.enemyCount = (context.enemyCount or 0) + 1
        end
    end

    local spawned = false

    return tiny.system {
        onAddToWorld = function(self, world)
            self.world = world
            context.state = context
        end,
        update = function(self, dt)
            if should_skip_spawns() then
                spawned = true
                return
            end

            if not spawned then
                spawned = true
                print("[ENEMY SPAWNER] Starting enemy spawn")
                spawn_once(self.world)
                print("[ENEMY SPAWNER] Enemy spawn completed")
            end
        end,
    }
end
