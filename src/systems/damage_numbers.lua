local FloatingText = require("src.effects.floating_text")

local damage_numbers = {}

local DEFAULT_COLOR = { 0.92, 0.36, 0.32, 1 }
local DEFAULT_DURATION = 1.05
local DEFAULT_RISE = 32

function damage_numbers.push(state, entity, amount, options)
    if not (FloatingText and entity and entity.position and amount) then
        return
    end

    options = options or {}

    local host = state or FloatingText.getFallback()
    if not host then
        return
    end

    local position = options.position or entity.position
    if not position then
        return
    end

    local radius = options.radius
        or (entity.drawable and entity.drawable.radius)
        or entity.radius
        or 24

    FloatingText.add(host, position, string.format("-%d", math.floor(amount + 0.5)), {
        offsetY = options.position and 0 or radius,
        color = options.color or DEFAULT_COLOR,
        rise = options.rise or DEFAULT_RISE,
        duration = options.duration or DEFAULT_DURATION,
        scale = options.scale,
        shadow = options.shadow,
        vx = options.vx,
    })
end

return damage_numbers
