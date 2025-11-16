---Cannon weapon behavior
---Simple projectile weapon
local base_projectile = require("src.weapons.behaviors.base_projectile")

return {
    -- Use standard projectile behavior
    update = base_projectile.update,
    onFireRequested = base_projectile.onFireRequested,
}
