---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local math_util = require("src.util.math")
local vector = require("src.util.vector")
local BehaviorTree = require("src.ai.behavior_tree")

local TAU = math_util.TAU
local BTStatus = BehaviorTree.Status

---@class EnemyBehaviorTreeInstance
---@field tick fun(self:EnemyBehaviorTreeInstance, entity:table, blackboard:table, dt:number):string

---@alias EnemyBehaviorContext table
---@alias EnemyEntity table
---@alias EnemyBlackboard table

-- Cache frequently used functions
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

---@param world table
---@param tag string
---@param preferred table|nil
---@param origin { x:number, y:number }|nil
---@param detectionRange number|nil
---@return table|nil
local function find_target(world, tag, preferred, origin, detectionRange)
    if preferred and is_target_valid(preferred) and has_tag(preferred, tag) and within_range(origin, preferred, detectionRange) then
        return preferred
    end

    if not (world and world.entities and tag) then
        return nil
    end

    local hasOrigin = origin and origin.x and origin.y
    local rangeSq = (detectionRange and detectionRange > 0) and detectionRange * detectionRange or huge
    local bestCandidate, bestDistSq = nil, huge
    local entities = world.entities

    for i = 1, #entities do
        local candidate = entities[i]
        if candidate and has_tag(candidate, tag) and is_target_valid(candidate) then
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
                return candidate
            end
        end
    end

    return bestCandidate
end

---@param entity EnemyEntity
---@return table
local function ensure_ai_state(entity)
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

local normalize_vector = vector.normalize
local clamp_vector = function(x, y, maxMagnitude)
    return vector.clamp(x, y, maxMagnitude)
end

---@param entity EnemyEntity
---@param isThrusting boolean
---@param impulseX number|nil
---@param impulseY number|nil
---@param dt number|nil
---@param desiredSpeed number|nil
local function update_engine_trail(entity, isThrusting, impulseX, impulseY, dt, desiredSpeed)
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

    -- Only show trail when actively applying impulse
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

---@param ai table
---@param entity EnemyEntity
---@return { x:number, y:number }|nil
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

---@param home { x:number, y:number }
---@param radius number
---@return number
---@return number
local function choose_wander_point(home, radius)
    local angle = random() * TAU
    local dist = sqrt(random()) * radius
    return home.x + cos(angle) * dist, home.y + sin(angle) * dist
end

local PlayerManager = require("src.player.manager")

---@param context EnemyBehaviorContext
---@return table|nil
local function get_local_player(context)
    return PlayerManager.resolveLocalPlayer(context)
end

---@param entity EnemyEntity
---@return number detection
---@return number engagement
---@return number preferred
---@return number|nil weaponRange
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

---@param body love.Body
---@param dt number
---@param factor number
local function apply_damping(body, dt, factor)
    local vx, vy = body:getLinearVelocity()
    local damping = max(0, 1 - dt * factor)
    body:setLinearVelocity(vx * damping, vy * damping)
end

---@param entity EnemyEntity
local function disable_weapon(entity)
    if entity.weapon then
        entity.weapon.firing = false
        entity.weapon.targetX = nil
        entity.weapon.targetY = nil
    end
end

---@param entity EnemyEntity
---@param body love.Body
---@param ai table
---@param stats table
---@param dt number
---@return boolean handled
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

---@param ai table
---@param context EnemyBehaviorContext
---@return EnemyBlackboard
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

---@param blackboard EnemyBlackboard
---@param detectionRange number
---@param engagementRange number
---@param preferredDistance number
---@param weaponRange number|nil
local function update_range_profile(blackboard, detectionRange, engagementRange, preferredDistance, weaponRange)
    local rangeProfile = blackboard.rangeProfile or {}
    rangeProfile.detection = detectionRange
    rangeProfile.engagement = engagementRange
    rangeProfile.preferred = preferredDistance
    rangeProfile.weapon = weaponRange
    blackboard.rangeProfile = rangeProfile
end

---@param context EnemyBehaviorContext
---@return EnemyBehaviorTreeInstance
local function create_behavior_tree(context)
    ---@param entity EnemyEntity
    ---@param blackboard EnemyBlackboard
    ---@param dt number
    local function ensure_target_action(entity, blackboard, dt)
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
            local preferred
            if entity.retaliationTarget and is_target_valid(entity.retaliationTarget) then
                preferred = entity.retaliationTarget
            else
                preferred = get_local_player(context)
            end
            target = find_target(blackboard.world, ai.targetTag or "player", preferred, position, detectionRange)
            entity.currentTarget = target
        end

        if target and target.position then
            return BTStatus.success
        end

        disable_weapon(entity)
        return BTStatus.failure
    end

    ---@param entity EnemyEntity
    ---@param blackboard EnemyBlackboard
    ---@param dt number
    local function engage_target_action(entity, blackboard, dt)
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
            if not (entity.retaliationTimer and entity.retaliationTimer > 0 and entity.retaliationTarget and is_target_valid(entity.retaliationTarget)) then
                entity.retaliationTarget = nil
                entity.currentTarget = nil
                disable_weapon(entity)
                apply_damping(body, dt, 4)
                update_engine_trail(entity, false)
                return BTStatus.failure
            end
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

        local desiredSpeed = vector.length(desiredVX, desiredVY)
        update_engine_trail(entity, true, impulseX, impulseY, dt, desiredSpeed)

        if entity.weapon then
            local weapon = entity.weapon
            local maxRange = weaponRange or weapon.maxRange or stats.max_range or engagementRange
            local canFire = maxRange and distance <= min(maxRange, engagementRange)

            if canFire then
                weapon.firing = (not weapon.cooldown or weapon.cooldown <= 0)
                weapon.targetX = weapon.firing and tx or nil
                weapon.targetY = weapon.firing and ty or nil
            else
                weapon.firing = false
                weapon.targetX = nil
                weapon.targetY = nil
            end
        end

        return BTStatus.running
    end

    ---@param entity EnemyEntity
    ---@param blackboard EnemyBlackboard
    ---@param dt number
    local function wander_action(entity, blackboard, dt)
        local body = entity.body
        if not body or body:isDestroyed() then
            return BTStatus.failure
        end

        local ai = entity.ai or {}
        local stats = entity.stats or {}

        return handle_wander(entity, body, ai, stats, dt) and BTStatus.success or BTStatus.failure
    end

    local ensureTargetNode = BehaviorTree.Action(ensure_target_action)
    local engageTargetNode = BehaviorTree.Action(engage_target_action)
    local wanderNode = BehaviorTree.Action(wander_action)

    local root = BehaviorTree.Selector({
        BehaviorTree.Sequence({
            ensureTargetNode,
            engageTargetNode,
        }),
        wanderNode,
    })

    return BehaviorTree.new(root)
end

---@param ai table
---@param context EnemyBehaviorContext
---@return EnemyBehaviorTreeInstance
local function ensure_behavior_tree(ai, context)
    if not ai.behaviorTree then
        ai.behaviorTree = create_behavior_tree(context)
    end

    return ai.behaviorTree
end

---@param context EnemyBehaviorContext
---@return table
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

            if entity.retaliationTimer and entity.retaliationTimer > 0 then
                entity.retaliationTimer = math.max(0, entity.retaliationTimer - dt)
                if entity.retaliationTimer <= 0 then
                    entity.retaliationTarget = nil
                end
            end

            local status = tree:tick(entity, blackboard, dt)

            if status == BTStatus.failure then
                disable_weapon(entity)
            end
        end,
    }
end
