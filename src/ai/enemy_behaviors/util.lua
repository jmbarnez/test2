local math_util = require("src.util.math")
local vector = require("src.util.vector")
local PlayerManager = require("src.player.manager")

local M = {}

local random = love.math.random
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local sqrt = math.sqrt
local abs = math.abs
local min = math.min
local max = math.max
local huge = math.huge

local clamp_angle = math_util.clamp_angle

function M.has_tag(entity, tag)
    if not entity or not tag then
        return false
    end

    if tag == "player" then
        return entity.player ~= nil
    end

    return entity[tag] ~= nil
end

function M.within_range(origin, candidate, range)
    if not (origin and candidate and candidate.position) then
        return false
    end

    if not range or range <= 0 then
        return true
    end

    local dx = candidate.position.x - origin.x
    local dy = candidate.position.y - origin.y
    return (dx * dx + dy * dy) <= (range * range)
end

function M.is_target_valid(target)
    if not target then
        return false
    end

    if target.pendingDestroy or target.destroyed then
        return false
    end

    local dead = (target.health and target.health.current and target.health.current <= 0)
        or (target.body and target.body:isDestroyed())

    return not dead
end

function M.resolve_state_from_context(context)
    if not context then
        return nil
    end

    local resolver = context.resolveState
    if type(resolver) == "function" then
        local ok, state = pcall(resolver, context)
        if not ok then
            ok, state = pcall(resolver)
        end
        if ok and type(state) == "table" then
            return state
        end
    end

    if type(context.state) == "table" then
        return context.state
    end

    if type(context) == "table" then
        return context
    end

    return nil
end

function M.gather_player_candidates(context)
    local state = M.resolve_state_from_context(context)
    if not state then
        return nil
    end

    local candidates = {}
    local seen = {}

    local function add(entity)
        if entity and entity.player and not seen[entity] then
            candidates[#candidates + 1] = entity
            seen[entity] = true
        end
    end

    add(state.player)
    add(state.playerShip)

    if type(state.players) == "table" then
        for _, entity in pairs(state.players) do
            add(entity)
        end
    end

    local playerMap = PlayerManager.collectAllPlayers(state)
    if type(playerMap) == "table" then
        for _, entity in pairs(playerMap) do
            add(entity)
        end
    end

    return candidates
end

function M.find_target(world, tag, preferred, origin, detectionRange, context)
    if preferred and M.is_target_valid(preferred) and M.has_tag(preferred, tag) and M.within_range(origin, preferred, detectionRange) then
        return preferred
    end

    if not (world and world.entities and tag) then
        return nil
    end

    local hasOrigin = origin and origin.x and origin.y
    local rangeSq = (detectionRange and detectionRange > 0) and detectionRange * detectionRange or huge
    local bestCandidate, bestDistSq = nil, huge
    local entities = world.entities

    local candidateLists
    if tag == "player" then
        local players = M.gather_player_candidates(context)
        if players and #players > 0 then
            candidateLists = { players, entities }
        end
    end

    if not candidateLists then
        candidateLists = { entities }
    end

    local function process_candidate(candidate)
        if candidate and M.has_tag(candidate, tag) and M.is_target_valid(candidate) then
            if hasOrigin then
                local pos = candidate.position
                if pos then
                    local dx = pos.x - origin.x
                    local dy = pos.y - origin.y
                    local distSq = dx * dx + dy * dy
                    if distSq <= rangeSq and distSq < bestDistSq then
                        bestDistSq = distSq
                        bestCandidate = candidate
                    end
                end
            else
                bestCandidate = candidate
                return true
            end
        end
        return false
    end

    for idx = 1, #candidateLists do
        local list = candidateLists[idx]
        if list then
            for i = 1, #list do
                if process_candidate(list[i]) then
                    return bestCandidate
                end
            end
        end
    end

    return bestCandidate
end

function M.ensure_ai_state(entity)
    local state = entity.aiState
    if not state then
        state = {
            strafeTimer = random() * 1.2 + 0.4,
            strafeDir = random() < 0.5 and -1 or 1,
            retaliationCooldown = 0,
        }
        entity.aiState = state
    end
    return state
end

function M.ensure_home(ai, entity)
    if ai.home then
        return ai.home
    end

    local spawn = entity.spawnPosition
    if spawn then
        ai.home = { x = spawn.x, y = spawn.y }
        return ai.home
    end

    local pos = entity.position
    if pos then
        ai.home = { x = pos.x, y = pos.y }
        return ai.home
    end

    return nil
end

function M.choose_wander_point(home, radius)
    local angle = random() * math_util.TAU
    local dist = sqrt(random()) * radius
    return home.x + cos(angle) * dist, home.y + sin(angle) * dist
end

local function clamp_vector(x, y, maxMagnitude)
    return vector.clamp(x, y, maxMagnitude)
end

function M.update_engine_trail(entity, isThrusting, impulseX, impulseY, dt, desiredSpeed)
    if not entity then
        return
    end

    impulseX = impulseX or 0
    impulseY = impulseY or 0
    local impulseMagnitude = vector.length(impulseX, impulseY)

    local thrusting = not not isThrusting
    local currentThrust = entity.currentThrust or 0

    if thrusting then
        if impulseMagnitude > 0 then
            currentThrust = dt and dt > 0 and (impulseMagnitude / dt) or impulseMagnitude
        elseif desiredSpeed and desiredSpeed > 0 then
            currentThrust = desiredSpeed
        elseif entity.body then
            local vx, vy = entity.body:getLinearVelocity()
            currentThrust = vector.length(vx, vy)
        end

        thrusting = currentThrust > 0.1
    end

    entity.isThrusting = thrusting
    entity.currentThrust = thrusting and currentThrust or 0

    if not thrusting then
        if entity.engineTrail then
            entity.engineTrail:setActive(false)
        end
        entity.engineTrailThrustVectorX = 0
        entity.engineTrailThrustVectorY = 0
        return
    end

    local stats = entity.stats or {}
    if stats.main_thrust and stats.main_thrust > 0 then
        entity.maxThrust = stats.main_thrust
    elseif not entity.maxThrust or entity.maxThrust < currentThrust then
        entity.maxThrust = currentThrust
    end

    if impulseMagnitude > 0 then
        entity.engineTrailThrustVectorX = impulseX
        entity.engineTrailThrustVectorY = impulseY
        if entity.engineTrail then
            entity.engineTrail:setActive(true)
        end
    else
        entity.engineTrailThrustVectorX = 0
        entity.engineTrailThrustVectorY = 0
        if entity.engineTrail then
            entity.engineTrail:setActive(false)
        end
    end
end

function M.compute_ranges(entity)
    local ai = entity.ai or {}
    local stats = entity.stats or {}
    local weapon = entity.weapon
    local weaponRange = weapon and weapon.maxRange or nil

    local detection = ai.detectionRange or stats.detection_range or ai.engagementRange or stats.max_range or weaponRange or (ai.wanderRadius and ai.wanderRadius * 1.5) or 600
    local engagement = ai.engagementRange or stats.max_range or weaponRange or detection

    if weaponRange then
        engagement = min(engagement or weaponRange, weaponRange)
        detection = max(detection or weaponRange, weaponRange * 1.1)
    end

    detection = detection or engagement or 600
    engagement = engagement or detection or 600

    local preferred = ai.preferredDistance or stats.preferred_distance or (engagement * 0.85)

    return detection, engagement, preferred, weaponRange
end

function M.apply_damping(body, dt, factor)
    local vx, vy = body:getLinearVelocity()
    local damping = max(0, 1 - dt * factor)
    body:setLinearVelocity(vx * damping, vy * damping)
end

function M.disable_weapon(entity)
    if entity.weapon then
        entity.weapon.firing = false
        entity.weapon.targetX = nil
        entity.weapon.targetY = nil
    end
end

function M.handle_wander(entity, body, ai, stats, dt)
    local position = entity.position
    if not (position and position.x and position.y) then
        M.update_engine_trail(entity, false)
        return false
    end

    local home = M.ensure_home(ai, entity)
    if not home then
        M.update_engine_trail(entity, false)
        return false
    end

    local radius = ai.wanderRadius or stats.wander_radius or 0
    if radius <= 0 then
        M.update_engine_trail(entity, false)
        return false
    end

    local arriveRadius = ai.wanderArriveRadius or max(40, radius * 0.2)
    local state = M.ensure_ai_state(entity)

    local maxSpeed = stats.max_speed or 240
    local wanderSpeed = ai.wanderSpeed or stats.wander_speed or (maxSpeed * 0.55)
    wanderSpeed = min(wanderSpeed, maxSpeed)

    local ex, ey = position.x, position.y
    local radiusSq = radius * radius

    local homeDx = ex - home.x
    local homeDy = ey - home.y
    local homeDistSq = homeDx * homeDx + homeDy * homeDy

    if homeDistSq > radiusSq * 1.1 then
        state.wanderTarget = { x = home.x, y = home.y }
    end

    if not state.wanderTarget then
        local tx, ty = M.choose_wander_point(home, radius)
        state.wanderTarget = { x = tx, y = ty }
    end

    local target = state.wanderTarget
    local dx, dy = target.x - ex, target.y - ey
    local dirX, dirY, distance = vector.normalize(dx, dy)

    if distance <= arriveRadius then
        state.wanderTarget = nil
        M.apply_damping(body, dt, 5)
        M.update_engine_trail(entity, false)
        M.disable_weapon(entity)
        return true
    end

    local desiredAngle = atan2(dy, dx) + math.pi * 0.5
    local currentAngle = body:getAngle()
    local delta = clamp_angle(desiredAngle - currentAngle)

    body:setAngularVelocity(0)
    body:setAngle(currentAngle + delta)
    entity.rotation = body:getAngle()

    local maxAccel = stats.max_acceleration or 600
    local mass = stats.mass or body:getMass() or 1

    local desiredVX, desiredVY = dirX * wanderSpeed, dirY * wanderSpeed
    desiredVX, desiredVY = clamp_vector(desiredVX, desiredVY, maxSpeed)

    local currentVX, currentVY = body:getLinearVelocity()
    local diffX, diffY = desiredVX - currentVX, desiredVY - currentVY
    local diffLen = vector.length(diffX, diffY)

    local impulseX, impulseY = 0, 0

    if diffLen > 0 then
        local maxDelta = maxAccel * dt
        if diffLen > maxDelta then
            local scale = maxDelta / diffLen
            diffX, diffY = diffX * scale, diffY * scale
        end

        impulseX, impulseY = diffX * mass, diffY * mass
        body:applyLinearImpulse(impulseX, impulseY)
    end

    local newVX, newVY = body:getLinearVelocity()
    newVX, newVY = clamp_vector(newVX, newVY, maxSpeed)
    body:setLinearVelocity(newVX, newVY)

    local desiredSpeed = vector.length(desiredVX, desiredVY)
    M.update_engine_trail(entity, true, impulseX, impulseY, dt, desiredSpeed)
    M.disable_weapon(entity)

    return true
end

function M.get_local_player(context)
    if context and type(context.getLocalPlayer) == "function" then
        return context:getLocalPlayer()
    end

    return PlayerManager.resolveLocalPlayer(context)
end

function M.update_range_profile(blackboard, detectionRange, engagementRange, preferredDistance, weaponRange)
    local rangeProfile = blackboard.rangeProfile or {}
    rangeProfile.detection = detectionRange
    rangeProfile.engagement = engagementRange
    rangeProfile.preferred = preferredDistance
    rangeProfile.weapon = weaponRange
    blackboard.rangeProfile = rangeProfile
end

return M
