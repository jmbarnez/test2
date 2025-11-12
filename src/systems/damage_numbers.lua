local FloatingText = require("src.effects.floating_text")

---@diagnostic disable-next-line: undefined-global
local love = love

local damage_numbers = {}

local DEFAULTS = {
    color = { 0.92, 0.36, 0.32, 1 },
    duration = 1.05,
    rise = 32,
    batchWindow = 0.18,
    refreshBuffer = 0.3,
}

local function get_time()
    return (love and love.timer and love.timer.getTime) and love.timer.getTime() or os.clock()
end

local function ensure_state(host)
    host.damageNumbers = host.damageNumbers or { buckets = {} }
    return host.damageNumbers
end

function damage_numbers.push(state, entity, amount, options)
    if not (FloatingText and entity and entity.position and amount) then return end
    
    options = options or {}
    local host = state or FloatingText.getFallback()
    if not host then return end
    
    local position = options.position or entity.position
    local radius = options.radius or (entity.drawable and entity.drawable.radius) or entity.radius or 24
    local batchWindow = options.batchWindow or DEFAULTS.batchWindow
    local key = options.key or entity
    local buckets = ensure_state(host).buckets
    local now = get_time()
    local offsetY = options.position and 0 or radius
    
    local bucket = key and buckets[key]
    if bucket and bucket.entry and bucket.entry.__alive and (now - bucket.lastUpdate) <= batchWindow then
        bucket.total = bucket.total + amount
        bucket.lastUpdate = now
        bucket.offsetY = offsetY
        bucket.offsetX = options.offsetX or bucket.offsetX or 0
        
        local entry = bucket.entry
        entry.text = string.format("-%d", math.floor(bucket.total + 0.5))
        entry.x = position.x + bucket.offsetX
        entry.y = position.y - bucket.offsetY
        entry.age = math.min(entry.age, math.max(0, entry.duration - DEFAULTS.refreshBuffer))
        entry.duration = math.max(entry.duration, options.duration or DEFAULTS.duration)
        return
    end
    
    local entry = FloatingText.add(host, position, string.format("-%d", math.floor(amount + 0.5)), {
        offsetY = offsetY,
        color = options.color or DEFAULTS.color,
        rise = options.rise or DEFAULTS.rise,
        duration = options.duration or DEFAULTS.duration,
        scale = options.scale,
        shadow = options.shadow,
        vx = options.vx,
    })
    
    if key and entry then
        buckets[key] = {
            entry = entry,
            total = amount,
            lastUpdate = now,
            offsetY = offsetY,
            offsetX = options.offsetX,
            batchWindow = batchWindow,
        }
    end
end

return damage_numbers
