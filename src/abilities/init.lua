---Ability system initialization
---Registers all ability behaviors and provides easy access

local BehaviorRegistry = require("src.abilities.behavior_registry")

-- Base behaviors
local base_afterburner = require("src.abilities.behaviors.base_afterburner")
local base_dash = require("src.abilities.behaviors.base_dash")
local base_temporal_field = require("src.abilities.behaviors.base_temporal_field")

-- Register fallbacks for backward compatibility
BehaviorRegistry.registerFallback("afterburner", {
    update = base_afterburner.update,
    activate = base_afterburner.activate,
    deactivate = base_afterburner.deactivate,
})

BehaviorRegistry.registerFallback("dash", {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
})

BehaviorRegistry.registerFallback("temporal_field", {
    update = base_temporal_field.update,
    activate = base_temporal_field.activate,
    deactivate = base_temporal_field.deactivate,
})

return {
    BehaviorRegistry = BehaviorRegistry,
    base_afterburner = base_afterburner,
    base_dash = base_dash,
    base_temporal_field = base_temporal_field,
}
