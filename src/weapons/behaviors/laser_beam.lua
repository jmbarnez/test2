---Laser beam weapon behavior
---Simple continuous hitscan weapon
local base_hitscan = require("src.weapons.behaviors.base_hitscan")

return {
    -- Use standard hitscan behavior
    update = base_hitscan.update,
    onFireRequested = base_hitscan.onFireRequested,
    
    -- Could add custom behavior here if needed:
    -- onHit = function(entity, weapon, target, context)
    --     -- Custom hit effects
    -- end
}
