---Temporal field ability behavior plugin
local base_temporal_field = require("src.abilities.behaviors.base_temporal_field")

return {
    update = base_temporal_field.update,
    activate = base_temporal_field.activate,
    deactivate = base_temporal_field.deactivate,
}
