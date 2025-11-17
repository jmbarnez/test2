local BehaviorRegistry = require("src.ai.enemy_behaviors.behavior_registry")

local hunter = require("src.ai.enemy_behaviors.hunter")

BehaviorRegistry:register("hunter", hunter)
BehaviorRegistry:setDefault("hunter")

return BehaviorRegistry
