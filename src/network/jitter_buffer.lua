-- Jitter buffer for smooth remote player movement
-- Buffers incoming snapshots and plays them back at a consistent rate

local constants = require("src.constants.game")

local JitterBuffer = {}

local BUFFER_TIME = (constants.network.jitter_buffer_ms or 100) / 1000 -- Convert to seconds
local MAX_BUFFER_SIZE = 10

function JitterBuffer.new()
    return {
        snapshots = {},
        playbackTime = 0,
        initialized = false,
    }
end

function JitterBuffer.addSnapshot(buffer, snapshot, timestamp)
    if not buffer then return end
    
    local entry = {
        snapshot = snapshot,
        timestamp = timestamp or love.timer.getTime(),
    }
    
    -- Insert in chronological order
    local inserted = false
    for i = 1, #buffer.snapshots do
        if buffer.snapshots[i].timestamp > entry.timestamp then
            table.insert(buffer.snapshots, i, entry)
            inserted = true
            break
        end
    end
    
    if not inserted then
        table.insert(buffer.snapshots, entry)
    end
    
    -- Initialize playback time on first snapshot
    if not buffer.initialized then
        buffer.playbackTime = entry.timestamp - BUFFER_TIME
        buffer.initialized = true
    end
    
    -- Trim old snapshots
    while #buffer.snapshots > MAX_BUFFER_SIZE do
        table.remove(buffer.snapshots, 1)
    end
end

function JitterBuffer.getInterpolatedSnapshot(buffer, currentTime)
    if not (buffer and buffer.initialized) then
        return nil
    end
    
    -- Update playback time
    buffer.playbackTime = currentTime - BUFFER_TIME
    
    -- Find snapshots to interpolate between
    local before, after = nil, nil
    
    for i = 1, #buffer.snapshots do
        local entry = buffer.snapshots[i]
        if entry.timestamp <= buffer.playbackTime then
            before = entry
        elseif entry.timestamp > buffer.playbackTime then
            after = entry
            break
        end
    end
    
    -- No snapshots available
    if not before then
        return nil
    end
    
    -- Only one snapshot, return it
    if not after then
        return before.snapshot
    end
    
    -- Interpolate between snapshots
    local timeDiff = after.timestamp - before.timestamp
    if timeDiff <= 0 then
        return before.snapshot
    end
    
    local t = (buffer.playbackTime - before.timestamp) / timeDiff
    t = math.max(0, math.min(1, t)) -- Clamp to [0,1]
    
    -- Create interpolated snapshot
    local interpolated = {}
    
    -- Interpolate position
    if before.snapshot.position and after.snapshot.position then
        interpolated.position = {
            x = before.snapshot.position.x + (after.snapshot.position.x - before.snapshot.position.x) * t,
            y = before.snapshot.position.y + (after.snapshot.position.y - before.snapshot.position.y) * t,
        }
    else
        interpolated.position = before.snapshot.position or after.snapshot.position
    end
    
    -- Interpolate rotation (handle wrapping)
    if before.snapshot.rotation ~= nil and after.snapshot.rotation ~= nil then
        local beforeRot = before.snapshot.rotation
        local afterRot = after.snapshot.rotation
        
        -- Handle angle wrapping
        local diff = afterRot - beforeRot
        if diff > math.pi then
            afterRot = afterRot - 2 * math.pi
        elseif diff < -math.pi then
            afterRot = afterRot + 2 * math.pi
        end
        
        interpolated.rotation = beforeRot + (afterRot - beforeRot) * t
    else
        interpolated.rotation = before.snapshot.rotation or after.snapshot.rotation
    end
    
    -- Interpolate velocity
    if before.snapshot.velocity and after.snapshot.velocity then
        interpolated.velocity = {
            x = before.snapshot.velocity.x + (after.snapshot.velocity.x - before.snapshot.velocity.x) * t,
            y = before.snapshot.velocity.y + (after.snapshot.velocity.y - before.snapshot.velocity.y) * t,
        }
    else
        interpolated.velocity = before.snapshot.velocity or after.snapshot.velocity
    end
    
    -- Copy other properties from the more recent snapshot
    interpolated.playerId = after.snapshot.playerId or before.snapshot.playerId
    interpolated.faction = after.snapshot.faction or before.snapshot.faction
    interpolated.blueprint = after.snapshot.blueprint or before.snapshot.blueprint
    interpolated.health = after.snapshot.health or before.snapshot.health
    interpolated.level = after.snapshot.level or before.snapshot.level
    interpolated.thrust = after.snapshot.thrust or before.snapshot.thrust
    interpolated.weapons = after.snapshot.weapons or before.snapshot.weapons
    interpolated.weapon = after.snapshot.weapon or before.snapshot.weapon
    interpolated.weaponMount = after.snapshot.weaponMount or before.snapshot.weaponMount
    interpolated.stats = after.snapshot.stats or before.snapshot.stats
    interpolated.cargo = after.snapshot.cargo or before.snapshot.cargo
    
    return interpolated
end

function JitterBuffer.cleanup(buffer)
    if not buffer then return end
    
    local currentTime = love.timer.getTime()
    local cutoffTime = currentTime - BUFFER_TIME * 2 -- Keep some extra history
    
    -- Remove old snapshots
    while #buffer.snapshots > 0 and buffer.snapshots[1].timestamp < cutoffTime do
        table.remove(buffer.snapshots, 1)
    end
end

return JitterBuffer
