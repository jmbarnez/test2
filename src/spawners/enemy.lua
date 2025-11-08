---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local loader = require("src.blueprints.loader")

local TAU = math.pi * 2

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

return function(context)
    context = context or {}

    local enemyConfig = context.enemyConfig or {}
    local bounds = context.worldBounds
    if not bounds then
        return tiny.system {}
    end

    local defaultCount = enemyConfig.count or 8
    local count = choose_count(defaultCount)
    local ship_id = enemyConfig.ship_id or enemyConfig.shipId or enemyConfig.ship or enemyConfig.default_ship or "enemy_scout"
    local spawnRadius = enemyConfig.spawn_radius or math.min(bounds.width, bounds.height) * 0.25
    local safe_radius = enemyConfig.safe_radius or enemyConfig.spawn_safe_radius or 600

    local instantiateContext = {
        physicsWorld = context.physicsWorld,
        worldBounds = bounds,
    }

    local spawn_positions = {}

    local function pick_spawn_point()
        local avoid_entity = context.player or (context.state and context.state.player)
        local avoid_pos = avoid_entity and avoid_entity.position
        local safe_sq = safe_radius * safe_radius
        local spacing_sq = (enemyConfig.separation_radius or safe_radius * 0.8) ^ 2

        for attempt = 1, 24 do
            local spawn_x, spawn_y

            if spawnRadius and spawnRadius > 0 then
                local inner_override = math.min(spawnRadius * 0.85, spawnRadius)
                inner_override = math.max(inner_override, safe_radius * 0.75)
                spawn_x, spawn_y = random_point_in_ring(bounds, spawnRadius, inner_override)
            else
                spawn_x = love.math.random(bounds.x, bounds.x + bounds.width)
                spawn_y = love.math.random(bounds.y, bounds.y + bounds.height)
            end

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

            if valid then
                return spawn_x, spawn_y
            end
        end

        if avoid_pos then
            return avoid_pos.x + safe_radius, avoid_pos.y
        end

        return bounds.x + bounds.width * 0.5 + safe_radius, bounds.y + bounds.height * 0.5
    end

    local function spawn_once(world)
        if not world then
            return
        end

        for _ = 1, count do
            local spawn_x, spawn_y = pick_spawn_point()
            spawn_positions[#spawn_positions + 1] = { x = spawn_x, y = spawn_y }

            local enemy = loader.instantiate("ships", ship_id, {
                position = { x = spawn_x, y = spawn_y },
                physicsWorld = instantiateContext.physicsWorld,
                worldBounds = instantiateContext.worldBounds,
            })

            enemy.enemy = true
            enemy.faction = enemy.faction or "enemy"

            enemy.spawnPosition = enemy.spawnPosition or { x = spawn_x, y = spawn_y }
            enemy.ai = enemy.ai or {}
            enemy.ai.home = enemy.ai.home or enemy.spawnPosition
            local wanderRadius = enemyConfig.wander_radius or spawnRadius
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
            if not spawned then
                spawned = true
                spawn_once(self.world)
            end
        end,
    }
end
