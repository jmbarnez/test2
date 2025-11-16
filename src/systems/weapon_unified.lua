---@diagnostic disable: undefined-global

---Unified weapon system that delegates to behavior plugins
local tiny = require("libs.tiny")
local BehaviorRegistry = require("src.weapons.behavior_registry")

---@class WeaponUnifiedContext
---@field world table|nil The ECS world
---@field physicsWorld love.World|nil The physics world
---@field damageEntity fun(target:table, amount:number, source:table, context:table)|nil Damage function
---@field camera table|nil The camera
---@field intentHolder table|nil Intent holder
---@field state table|nil The game state
---@field uiInput table|nil UI input state

return function(context)
    context = context or {}
    
    return tiny.processingSystem {
        filter = tiny.requireAll("weapon", "position"),
        
        process = function(self, entity, dt)
            local weapon = entity.weapon
            if not weapon then
                return
            end
            
            -- Get the behavior plugin for this weapon
            local behavior = BehaviorRegistry.resolve(weapon)
            if not behavior then
                -- No behavior registered, skip
                return
            end
            
            -- Prepare context for behavior
            local behaviorContext = {
                world = self.world,
                physicsWorld = context.physicsWorld,
                damageEntity = context.damageEntity,
                camera = context.camera,
                intentHolder = context.intentHolder,
                state = context.state,
                uiInput = context.uiInput,
            }
            
            -- Call update if behavior has it
            if behavior.update then
                behavior.update(entity, weapon, dt, behaviorContext)
            end
            
            -- Call onFireRequested if fire is requested and behavior has it
            if weapon._fireRequested and behavior.onFireRequested then
                behavior.onFireRequested(entity, weapon, behaviorContext)
            end
        end,
    }
end
