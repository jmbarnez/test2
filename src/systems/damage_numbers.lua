local FloatingText = require("src.effects.floating_text")

---@diagnostic disable-next-line: undefined-global
local love = love

local damage_numbers = {}

local DEFAULT_COLOR = { 0.92, 0.36, 0.32, 1 }
local DEFAULT_DURATION = 1.05
local DEFAULT_RISE = 32
local DEFAULT_BATCH_WINDOW = 0.18
local REFRESH_BUFFER = 0.3

local function get_time()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function ensure_state(host)
    host.damageNumbers = host.damageNumbers or {}
    local state = host.damageNumbers
    state.buckets = state.buckets or {}
    return state
end

local function format_amount(total)
    return string.format("-%d", math.floor(total + 0.5))
end

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

    local batchWindow = options.batchWindow or DEFAULT_BATCH_WINDOW
    local key = options.key or entity
    local stateData = ensure_state(host)
    local buckets = stateData.buckets
    local now = get_time()

    local bucket = key and buckets[key] or nil
    if bucket then
        local expired = (not bucket.entry)
            or (not bucket.entry.__alive)
            or (now - bucket.lastUpdate) > batchWindow
        if expired then
            buckets[key] = nil
            bucket = nil
        end
    end

    local offsetY = options.position and 0 or radius

    if bucket then
        bucket.total = bucket.total + amount
        bucket.lastUpdate = now
        bucket.offsetY = offsetY
        bucket.offsetX = options.offsetX or bucket.offsetX or 0

        local entry = bucket.entry
        entry.text = format_amount(bucket.total)
        entry.x = position.x + (bucket.offsetX or 0)
        entry.y = position.y - bucket.offsetY
        entry.age = math.min(entry.age, math.max(0, entry.duration - REFRESH_BUFFER))
        entry.duration = math.max(entry.duration or DEFAULT_DURATION, options.duration or DEFAULT_DURATION)

        return
    end

    local entry = FloatingText.add(host, position, format_amount(amount), {
        offsetY = offsetY,
        color = options.color or DEFAULT_COLOR,
        rise = options.rise or DEFAULT_RISE,
        duration = options.duration or DEFAULT_DURATION,
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
