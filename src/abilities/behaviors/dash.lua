---Dash ability behavior plugin
local base_dash = require("src.abilities.behaviors.base_dash")

return {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
}
