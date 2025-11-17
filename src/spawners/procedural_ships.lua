---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local ProceduralShipGenerator = require("src.util.procedural_ship_generator")
local ShipFactory = require("src.entities.ship_factory")
local PlayerManager = require("src.player.manager")
local LevelScaling = require("src.combat.level_scaling")
local math_util = require("src.util.math")

local TAU = math_util.TAU

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

local function apply_level_override(ship, override)
    if not override then
        return
    end

    ship.level = ship.level or {}

    if type(override) == "number" then
        local value = math.max(1, math.floor(override + 0.5))
        ship.level.current = value
        ship.level.base = ship.level.base or value
        return
    end

    if type(override) ~= "table" then
        return
    end

    local minValue = override.min or override.minimum or override.lower or override[1]
    local maxValue = override.max or override.maximum or override.upper or override[2] or minValue

    if minValue or maxValue then
        minValue = minValue or maxValue
        maxValue = maxValue or minValue

        minValue = math.max(1, math.floor(minValue + 0.5))
        maxValue = math.max(minValue, math.floor(maxValue + 0.5))

        local rolled = love.math.random(minValue, maxValue)
        ship.level.min = ship.level.min or minValue
        ship.level.max = ship.level.max or maxValue
        ship.level.current = rolled
        ship.level.base = ship.level.base or rolled
    end

    local current = override.current or override.value or override.level
    if current then
        current = math.max(1, math.floor(current + 0.5))
        ship.level.current = current
        ship.level.base = ship.level.base or current
    end

    for key, value in pairs(override) do
        if key ~= "min" and key ~= "max" and key ~= 1 and key ~= 2 then
            if ship.level[key] == nil then
                ship.level[key] = type(value) == "table" and clone_table(value) or value
            end
        end
    end
end

return function(context)
    context = context or {}

    local function should_skip_spawns()
        local state = context.state or context
        return state and state.skipProceduralSpawns
    end

    local proceduralConfig = context.proceduralShipConfig or {}
    local bounds = context.worldBounds
    if not bounds then
        return tiny.system {}
    end

    -- Configuration
    local defaultCount = proceduralConfig.count or 5
    local count = choose_count(defaultCount)
    local safe_radius = proceduralConfig.safe_radius or proceduralConfig.spawn_safe_radius or 600
    local difficulty = proceduralConfig.difficulty or "normal"
    
    -- Size distribution (weighted random)
    local size_weights = proceduralConfig.size_distribution or {
        small = 0.5,    -- 50% small ships
        medium = 0.35,  -- 35% medium ships
        large = 0.15,   -- 15% large ships
    }
    
    local instantiateContext = {
        physicsWorld = context.physicsWorld,
        worldBounds = bounds,
    }

    local spawn_positions = {}

    local function resolve_avoid_entity()
        return PlayerManager.resolveLocalPlayer(context)
    end

    local function pick_spawn_point()
        local avoid_entity = resolve_avoid_entity()
        local avoid_pos = avoid_entity and avoid_entity.position
        local safe_sq = safe_radius * safe_radius
        local spacing_sq = (proceduralConfig.separation_radius or safe_radius * 0.8) ^ 2

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

            if valid then
                return spawn_x, spawn_y
            end
        end

        -- Fallback: random position in world bounds
        return love.math.random(bounds.x + safe_radius, bounds.x + bounds.width - safe_radius),
               love.math.random(bounds.y + safe_radius, bounds.y + bounds.height - safe_radius)
    end
    
    local function pick_size_class()
        local roll = love.math.random()
        local cumulative = 0
        
        for size, weight in pairs(size_weights) do
            cumulative = cumulative + weight
            if roll <= cumulative then
                return size
            end
        end
        
        return "medium" -- fallback
    end

    local function spawn_once(world)
        if not world then
            return
        end
        
        print(string.format("[PROCEDURAL SHIPS] Generating %d procedural ships...", count))

        for i = 1, count do
            local spawn_x, spawn_y = pick_spawn_point()
            spawn_positions[#spawn_positions + 1] = { x = spawn_x, y = spawn_y }

            -- Generate a procedural ship blueprint
            local size_class = pick_size_class()
            local ship_blueprint = ProceduralShipGenerator.generate({
                size_class = size_class,
                difficulty = difficulty,
                seed = love.math.random(1, 999999),
            })
            
            -- Instantiate the ship using the ship factory
            local instantiate_context = {
                position = { x = spawn_x, y = spawn_y },
                physicsWorld = instantiateContext.physicsWorld,
                worldBounds = instantiateContext.worldBounds,
            }

            local ship = ShipFactory.instantiate(ship_blueprint, instantiate_context)

            ship.enemy = true
            ship.faction = ship.faction or "enemy"

            -- Apply level scaling if configured
            apply_level_override(ship, proceduralConfig.level)
            LevelScaling.apply(ship)

            ship.spawnPosition = ship.spawnPosition or { x = spawn_x, y = spawn_y }
            ship.ai = ship.ai or {}
            ship.ai.home = ship.ai.home or ship.spawnPosition
            
            local wanderRadius = proceduralConfig.wander_radius or math.min(bounds.width, bounds.height) * 0.3
            if wanderRadius and wanderRadius > 0 then
                ship.ai.wanderRadius = ship.ai.wanderRadius or wanderRadius
            end
            if proceduralConfig.wander_speed then
                ship.ai.wanderSpeed = ship.ai.wanderSpeed or proceduralConfig.wander_speed
            end
            if proceduralConfig.wander_arrive_radius then
                ship.ai.wanderArriveRadius = ship.ai.wanderArriveRadius or proceduralConfig.wander_arrive_radius
            end

            world:add(ship)
            context.proceduralShipCount = (context.proceduralShipCount or 0) + 1
            
            print(string.format("[PROCEDURAL SHIPS] Spawned %s (%s) at (%.0f, %.0f)", 
                ship_blueprint.name, size_class, spawn_x, spawn_y))
        end
        
        print(string.format("[PROCEDURAL SHIPS] Spawned %d procedural ships", count))
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
                print("[PROCEDURAL SHIPS] Starting procedural ship spawn")
                spawn_once(self.world)
                print("[PROCEDURAL SHIPS] Procedural ship spawn completed")
            end
        end,
    }
end
