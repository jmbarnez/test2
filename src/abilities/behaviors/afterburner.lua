---Afterburner ability behavior plugin
local base_afterburner = require("src.abilities.behaviors.base_afterburner")

return {
    update = base_afterburner.update,
    activate = base_afterburner.activate,
    deactivate = base_afterburner.deactivate,
}
