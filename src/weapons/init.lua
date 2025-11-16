---Weapon behavior system initialization
---Registers fallback behaviors for backward compatibility with fireMode
local BehaviorRegistry = require("src.weapons.behavior_registry")
local base_hitscan = require("src.weapons.behaviors.base_hitscan")
local base_projectile = require("src.weapons.behaviors.base_projectile")
local base_cloud = require("src.weapons.behaviors.base_cloud")

-- Register fallback behaviors for fireMode compatibility
-- This allows weapons without registered behaviors to still work
BehaviorRegistry.registerFallback("hitscan", base_hitscan)
BehaviorRegistry.registerFallback("projectile", base_projectile)
BehaviorRegistry.registerFallback("cloud", base_cloud)

return BehaviorRegistry
