local base_projectile = require("src.weapons.behaviors.base_projectile")

return {
    update = base_projectile.update,
    onFireRequested = base_projectile.onFireRequested,
}
