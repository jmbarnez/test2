local loader = require("src.blueprints.loader")
local ship_factory = require("src.entities.ship_factory")

local station_factory = {}

local function normalize_station_components(blueprint)
    local components = blueprint.components or {}
    blueprint.components = components

    components.station = true
    components.type = components.type or "station"
    components.position = components.position or { x = 0, y = 0 }
    components.velocity = components.velocity or { x = 0, y = 0 }
    components.rotation = components.rotation or 0

    local drawable = components.drawable or {}
    components.drawable = drawable
    drawable.type = drawable.type or "ship"

    return components
end

function station_factory.instantiate(blueprint, context)
    assert(type(blueprint) == "table", "station blueprint must be a table")
    normalize_station_components(blueprint)

    local physics = blueprint.physics or {}
    physics.body = physics.body or { type = "static", fixedRotation = true }
    physics.fixture = physics.fixture or {}
    blueprint.physics = physics

    context = context or {}
    context.station = true

    return ship_factory.instantiate(blueprint, context)
end

loader.register_factory("stations", station_factory)

return station_factory
