---Overdrive ability behavior plugin
local base_overdrive = require("src.abilities.behaviors.base_overdrive")

return {
    update = base_overdrive.update,
    activate = base_overdrive.activate,
    deactivate = base_overdrive.deactivate,
}
