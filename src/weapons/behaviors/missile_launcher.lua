---Missile launcher weapon behavior
---Projectile weapon with homing capabilities
local base_projectile = require("src.weapons.behaviors.base_projectile")

return {
    -- Use standard projectile behavior
    -- The homing behavior is handled by the projectile system itself
    -- via the projectileHoming config in the weapon blueprint
    update = base_projectile.update,
    onFireRequested = base_projectile.onFireRequested,
    
    -- Could add custom behavior here if needed:
    -- onProjectileSpawned = function(entity, weapon, projectile, context)
    --     -- Custom projectile setup
    -- end
}
