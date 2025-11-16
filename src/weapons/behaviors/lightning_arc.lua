---Lightning arc weapon behavior
---Hitscan weapon with lightning beam style and chain lightning
local base_hitscan = require("src.weapons.behaviors.base_hitscan")

return {
    -- Use standard hitscan behavior
    -- Chain lightning is automatically handled by base_hitscan
    -- when weapon.chainLightning config is present
    update = base_hitscan.update,
    onFireRequested = base_hitscan.onFireRequested,
}
