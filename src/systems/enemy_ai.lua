---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local math_util = require("src.util.math")
local vector = require("src.util.vector")
local BehaviorTree = require("src.ai.behavior_tree")

local TAU = math_util.TAU
local BTStatus = BehaviorTree.Status

-- Cache frequently used functions
local random = love.math.random
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local sqrt = math.sqrt
local abs = math.abs
local min = math.min
local max = math.max

local function has_tag(entity, tag)
    if not entity or not tag then
        return false
    end

    if tag == "player" then
        return entity.player ~= nil
    end

    return entity[tag] ~= nil
end

local function within_range(origin, candidate, range)
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

local function find_target(world, tag, preferred, origin, detectionRange)
    if preferred and has_tag(preferred, tag) and within_range(origin, preferred, detectionRange) then
        return preferred
    end

    if not world or not tag then
        return nil
    end

    local entities = world.entities
    for i = 1, #entities do
        local candidate = entities[i]
        if candidate and has_tag(candidate, tag) and within_range(origin, candidate, detectionRange) then
            return candidate
        end
    end

    return nil
end

local function ensure_ai_state(entity)
    local state = entity.aiState
    if not state then
        state = {
            strafeTimer = random() * 1.2 + 0.4,
            strafeDir = random() < 0.5 and -1 or 1,
        }
        entity.aiState = state
    end
    return state
end

local clamp_angle = math_util.clamp_angle

local function is_target_valid(target)
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

local normalize_vector = vector.normalize
local clamp_vector = function(x, y, max)
    return vector.clamp(x, y, max)
end

local function update_engine_trail(entity, isThrusting, impulseX, impulseY, dt, desiredSpeed)
    if not entity then
        return
    end

    impulseX = impulseX or 0
    impulseY = impulseY or 0

    local thrusting = not not isThrusting
    local currentThrust = entity.currentThrust or 0

    if thrusting then
        local impulseMagnitude = vector.length(impulseX, impulseY)
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
        return
    end

    local stats = entity.stats or {}
    if stats.main_thrust and stats.main_thrust > 0 then
        entity.maxThrust = stats.main_thrust
    elseif not entity.maxThrust or entity.maxThrust < currentThrust then
        entity.maxThrust = currentThrust
    end

    if entity.engineTrail then
        entity.engineTrail:setActive(true)
    end
end

local function ensure_home(ai, entity)
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

local function choose_wander_point(home, radius)
    local angle = random() * TAU
    local dist = random() * radius
    return home.x + cos(angle) * dist, home.y + sin(angle) * dist
end

local PlayerManager = require("src.player.manager")

local function get_local_player(context)
    return PlayerManager.resolveLocalPlayer(context)
end

local function compute_ranges(entity)
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

local function apply_damping(body, dt, factor)
    local vx, vy = body:getLinearVelocity()
    local damping = max(0, 1 - dt * factor)
    body:setLinearVelocity(vx * damping, vy * damping)
end

local function disable_weapon(entity)
    if entity.weapon then
        entity.weapon.firing = false
        entity.weapon.targetX = nil
        entity.weapon.targetY = nil
    end
end

local function handle_wander(entity, body, ai, stats, dt)
    local position = entity.position
    if not (position and position.x and position.y) then
        update_engine_trail(entity, false)
        return false
    end

    local home = ensure_home(ai, entity)
    if not home then
        update_engine_trail(entity, false)
        return false
    end

    local radius = ai.wanderRadius or stats.wander_radius or 0
    if radius <= 0 then
        update_engine_trail(entity, false)
        return false
    end

    local arriveRadius = ai.wanderArriveRadius or max(40, radius * 0.2)
    local state = ensure_ai_state(entity)

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
        local tx, ty = choose_wander_point(home, radius)
        state.wanderTarget = { x = tx, y = ty }
    end

    local target = state.wanderTarget
    local dx, dy = target.x - ex, target.y - ey
    local dirX, dirY, distance = normalize_vector(dx, dy)

    if distance <= arriveRadius then
        state.wanderTarget = nil
        apply_damping(body, dt, 5)
        update_engine_trail(entity, false)
        disable_weapon(entity)
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
    update_engine_trail(entity, true, impulseX, impulseY, dt, desiredSpeed)
    disable_weapon(entity)

    return true
end

local function ensure_blackboard(ai, context)
    local blackboard = ai.blackboard
    if not blackboard then
        blackboard = BehaviorTree.createBlackboard({
            context = context,
        })
        ai.blackboard = blackboard
    end

    blackboard.context = context
    return blackboard
end

local function update_range_profile(blackboard, detectionRange, engagementRange, preferredDistance, weaponRange)
    local rangeProfile = blackboard.rangeProfile or {}
    rangeProfile.detection = detectionRange
    rangeProfile.engagement = engagementRange
    rangeProfile.preferred = preferredDistance
    rangeProfile.weapon = weaponRange
    blackboard.rangeProfile = rangeProfile
end

local function create_behavior_tree(context)
    local ensureTargetNode = BehaviorTree.Action(function(entity, blackboard, dt)
        local body = entity.body
        if not body or body:isDestroyed() then
            entity.currentTarget = nil
            return BTStatus.failure
        end

        local position = entity.position
        if not (position and position.x and position.y) then
            entity.currentTarget = nil
            return BTStatus.failure
        end

        local ai = entity.ai or {}
        ensure_home(ai, entity)

        local detectionRange, engagementRange, preferredDistance, weaponRange = compute_ranges(entity)
        update_range_profile(blackboard, detectionRange, engagementRange, preferredDistance, weaponRange)

        local target = entity.currentTarget

        if not is_target_valid(target) then
            local preferred = get_local_player(context)
            target = find_target(blackboard.world, ai.targetTag or "player", preferred, position, detectionRange)
            entity.currentTarget = target
        end

        if target and target.position then
            return BTStatus.success
        end

        disable_weapon(entity)
        return BTStatus.failure
    end)

    local engageTargetNode = BehaviorTree.Action(function(entity, blackboard, dt)
        local body = entity.body
        if not body or body:isDestroyed() then
            update_engine_trail(entity, false)
            entity.currentTarget = nil
            return BTStatus.failure
        end

        local position = entity.position
        local target = entity.currentTarget
        if not (position and position.x and position.y and target and target.position) then
            apply_damping(body, dt, 4)
            update_engine_trail(entity, false)
            return BTStatus.failure
        end

        local ai = entity.ai or {}
        local stats = entity.stats or {}
        local detectionRange, engagementRange, preferredDistance, weaponRange = compute_ranges(entity)
        update_range_profile(blackboard, detectionRange, engagementRange, preferredDistance, weaponRange)

        local ex, ey = position.x, position.y
        local tx, ty = target.position.x, target.position.y
        local dx, dy = tx - ex, ty - ey
        local dirX, dirY, distance = normalize_vector(dx, dy)

        if not dirX or not dirY then
            apply_damping(body, dt, 4)
            update_engine_trail(entity, false)
            return BTStatus.failure
        end

        local desiredAngle = atan2(dy, dx) + math.pi * 0.5
        local currentAngle = body:getAngle()
        local delta = clamp_angle(desiredAngle - currentAngle)

        body:setAngularVelocity(0)
        body:setAngle(currentAngle + delta)
        entity.rotation = body:getAngle()

        local disengageRange = ai.disengageRange or stats.disengage_range or (detectionRange and detectionRange * 1.25)
        local dropRange = disengageRange or detectionRange or engagementRange
        if dropRange and dropRange > 0 and distance > dropRange then
            entity.currentTarget = nil
            disable_weapon(entity)
            apply_damping(body, dt, 4)
            update_engine_trail(entity, false)
            return BTStatus.failure
        end

        preferredDistance = max(80, preferredDistance or 0)
        local maxSpeed = stats.max_speed or 240
        local maxAccel = stats.max_acceleration or 600
        local mass = stats.mass or body:getMass() or 1

        local distanceError = distance - preferredDistance
        local normalizedError = preferredDistance > 0 
            and (distanceError / preferredDistance) 
            or (distanceError / max(distance, 1))
        normalizedError = max(-1, min(1, normalizedError))

        local desiredSpeed = maxSpeed * normalizedError
        local desiredVX, desiredVY = dirX * desiredSpeed, dirY * desiredSpeed

        local strafeThrust = stats.strafe_thrust or 0
        if strafeThrust > 0 then
            local state = ensure_ai_state(entity)
            state.strafeTimer = state.strafeTimer - dt
            if state.strafeTimer <= 0 then
                state.strafeTimer = random() * 1.2 + 0.4
                state.strafeDir = random() < 0.5 and -1 or 1
            end

            local strafeDirX, strafeDirY = -dirY * state.strafeDir, dirX * state.strafeDir
            local strafeSpeed = maxSpeed * 0.6
            local strafeScale = 1 - min(1, abs(normalizedError))
            desiredVX = desiredVX + strafeDirX * strafeSpeed * strafeScale
            desiredVY = desiredVY + strafeDirY * strafeSpeed * strafeScale
        end

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

        desiredSpeed = vector.length(desiredVX, desiredVY)
        update_engine_trail(entity, true, impulseX, impulseY, dt, desiredSpeed)

        if entity.weapon then
            local weapon = entity.weapon
            local maxRange = weaponRange or weapon.maxRange or stats.max_range or engagementRange
            local canFire = maxRange and distance <= min(maxRange, engagementRange)

            weapon.firing = canFire
            weapon.targetX = canFire and tx or nil
            weapon.targetY = canFire and ty or nil
        end

        return BTStatus.running
    end)

    local wanderNode = BehaviorTree.Action(function(entity, blackboard, dt)
        local body = entity.body
        if not body or body:isDestroyed() then
            return BTStatus.failure
        end

        local ai = entity.ai or {}
        local stats = entity.stats or {}

        return handle_wander(entity, body, ai, stats, dt) and BTStatus.success or BTStatus.failure
    end)

    local root = BehaviorTree.Selector({
        BehaviorTree.Sequence({
            ensureTargetNode,
            engageTargetNode,
        }),
        wanderNode,
    })

    return BehaviorTree.new(root)
end

local function ensure_behavior_tree(ai, context)
    if not ai.behaviorTree then
        ai.behaviorTree = create_behavior_tree(context)
    end

    return ai.behaviorTree
end

return function(context)
    context = context or {}

    return tiny.system {
        filter = tiny.requireAll("enemy", "body", "position", "ai"),
        process = function(self, entity, dt)
            local body = entity.body
            if not body or body:isDestroyed() then
                return
            end

            local ai = entity.ai or {}
            ensure_home(ai, entity)
            local tree = ensure_behavior_tree(ai, context)
            local blackboard = ensure_blackboard(ai, context)
            blackboard.world = self.world

            local status = tree:tick(entity, blackboard, dt)

            if status == BTStatus.failure then
                disable_weapon(entity)
            end
        end,
    }
end
