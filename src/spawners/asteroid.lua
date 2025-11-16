-- asteroid_spawner.lua
-- Generates a static asteroid field for the sector at state initialization

---@diagnostic disable: undefined-global
local tiny = require("libs.tiny")
local loader = require("src.blueprints.loader")

local function choose_count(range)
    if type(range) == "table" then
        local min = range.min or range[1] or 1
        local max = range.max or range[2] or min
        return love.math.random(min, max)
    end
    return range or 1
end

local function should_skip_spawns(context)
    local state = context and (context.state or context)
    return state and state.skipProceduralSpawns
end

return function(context)
    context = context or {}
    
    local asteroidConfig = context.asteroidConfig or {}
    local bounds = context.worldBounds
    if not bounds then
        return tiny.system {}
    end

    local spawned = false
    local fieldCount = asteroidConfig.field and asteroidConfig.field.count or { min = 30, max = 50 }
    local asteroidCount = choose_count(fieldCount)

    local instantiateContext = {
        physicsWorld = context.physicsWorld,
        worldBounds = bounds,
    }

    return tiny.system {
        update = function(self, dt)
            if should_skip_spawns(context) then
                spawned = true
                return
            end

            if not spawned then
                spawned = true
                print(string.format("[ASTEROID SPAWNER] Spawning %d asteroids in bounds (%d,%d,%d,%d)", 
                    asteroidCount, bounds.x, bounds.y, bounds.width, bounds.height))
                
                for i = 1, asteroidCount do
                    local radiusRange = asteroidConfig.radius or { min = 22, max = 64 }
                    local margin = radiusRange.max or 64
                    local x = love.math.random(bounds.x + margin, bounds.x + bounds.width - margin)
                    local y = love.math.random(bounds.y + margin, bounds.y + bounds.height - margin)
                    
                    local asteroid = loader.instantiate("asteroids", "default", {
                        position = { x = x, y = y },
                        physicsWorld = instantiateContext.physicsWorld,
                        worldBounds = instantiateContext.worldBounds,
                        config = asteroidConfig,
                    })
                    
                    self.world:add(asteroid)
                end
                
                context.asteroidCount = asteroidCount
            end
        end,
    }
end
