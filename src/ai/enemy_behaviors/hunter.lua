local BehaviorTree = require("src.ai.behavior_tree")
local util = require("src.ai.enemy_behaviors.util")
local vector = require("src.util.vector")
local math_util = require("src.util.math")

local HunterBehavior = {}

local BTStatus = BehaviorTree.Status

local random = love.math.random
local atan2 = math.atan2
local abs = math.abs
local min = math.min
local max = math.max

local clamp_angle = math_util.clamp_angle
local normalize_vector = vector.normalize

local function ensure_blackboard(data, context)
    local blackboard = data.blackboard
    if not blackboard then
        blackboard = BehaviorTree.createBlackboard({ context = context })
        data.blackboard = blackboard
    end

    blackboard.context = context
    return blackboard
end

local function ensure_behavior_tree(data)
    local tree = data.tree
    if not tree then
        tree = HunterBehavior.buildTree()
        data.tree = tree
    end
    return tree
end

local function ensure_target_action(entity, blackboard)
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
    util.ensure_home(ai, entity)

    local retaliationTarget = entity.retaliationTarget
    if retaliationTarget and not util.is_target_valid(retaliationTarget) then
        retaliationTarget = nil
        entity.retaliationTarget = nil
    end

    local detectionRange, engagementRange, preferredDistance, weaponRange = util.compute_ranges(entity)
    util.update_range_profile(blackboard, detectionRange, engagementRange, preferredDistance, weaponRange)

    local target = entity.currentTarget

    if retaliationTarget then
        if target ~= retaliationTarget then
            target = retaliationTarget
            entity.currentTarget = retaliationTarget
        end
    elseif not util.is_target_valid(target) then
        local preferred = util.get_local_player(blackboard.context)
        target = util.find_target(blackboard.world, ai.targetTag or "player", preferred, position, detectionRange, blackboard.context)
        entity.currentTarget = target
    end

    if target and target.position then
        return BTStatus.success
    end

    util.disable_weapon(entity)
    return BTStatus.failure
end

local function engage_target_action(entity, blackboard, dt)
    local body = entity.body
    if not body or body:isDestroyed() then
        util.update_engine_trail(entity, false)
        entity.currentTarget = nil
        return BTStatus.failure
    end

    local position = entity.position
    local target = entity.currentTarget
    if not (position and position.x and position.y and target and target.position) then
        util.apply_damping(body, dt, 4)
        util.update_engine_trail(entity, false)
        return BTStatus.failure
    end

    local ai = entity.ai or {}
    local stats = entity.stats or {}
    local detectionRange, engagementRange, preferredDistance, weaponRange = util.compute_ranges(entity)
    util.update_range_profile(blackboard, detectionRange, engagementRange, preferredDistance, weaponRange)

    local ex, ey = position.x, position.y
    local tx, ty = target.position.x, target.position.y
    local dx, dy = tx - ex, ty - ey
    local dirX, dirY, distance = normalize_vector(dx, dy)

    if not dirX or not dirY then
        util.apply_damping(body, dt, 4)
        util.update_engine_trail(entity, false)
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
    local retaliationTarget = entity.retaliationTarget
    if retaliationTarget and not util.is_target_valid(retaliationTarget) then
        retaliationTarget = nil
        entity.retaliationTarget = nil
    end

    local hasRetaliationLock = retaliationTarget and retaliationTarget == target

    if dropRange and dropRange > 0 and distance > dropRange and not hasRetaliationLock then
        if not (entity.retaliationTimer and entity.retaliationTimer > 0 and entity.retaliationTarget and util.is_target_valid(entity.retaliationTarget)) then
            entity.retaliationTarget = entity.retaliationTarget or entity.currentTarget
            entity.retaliationTimer = entity.retaliationTimer or ai.retaliationDuration or stats.retaliation_duration or 3
        end

        entity.currentTarget = nil
        util.disable_weapon(entity)
        util.apply_damping(body, dt, 4)
        util.update_engine_trail(entity, false)
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

    if distance < preferredDistance * 0.7 and normalizedError < 0 then
        desiredSpeed = desiredSpeed * 0.3
        util.apply_damping(body, dt, 6)
    end

    local desiredVX, desiredVY = dirX * desiredSpeed, dirY * desiredSpeed

    local strafeThrust = stats.strafe_thrust or 0
    if strafeThrust > 0 then
        local state = util.ensure_ai_state(entity)
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

    desiredVX, desiredVY = vector.clamp(desiredVX, desiredVY, maxSpeed)

    local currentVX, currentVY = body:getLinearVelocity()
    local diffX, diffY = desiredVX - currentVX, desiredVY - currentVY
    local diffLen = vector.length(diffX, diffY)

    local impulseX, impulseY = 0, 0

    if diffLen > 0 then
        local maxDelta = maxAccel * dt

        local velLen = vector.length(currentVX, currentVY)
        if velLen > 0 and dirX and dirY then
            local vdx, vdy = currentVX / velLen, currentVY / velLen
            local forwardDot = vdx * dirX + vdy * dirY
            if forwardDot < -0.25 then
                util.apply_damping(body, dt, 6)
                maxDelta = maxDelta * 0.4
            end
        end

        if diffLen > maxDelta then
            local scale = maxDelta / diffLen
            diffX, diffY = diffX * scale, diffY * scale
        end

        impulseX, impulseY = diffX * mass, diffY * mass
        body:applyLinearImpulse(impulseX, impulseY)
    end

    local newVX, newVY = body:getLinearVelocity()
    newVX, newVY = vector.clamp(newVX, newVY, maxSpeed)
    body:setLinearVelocity(newVX, newVY)

    local desiredSpeedAbs = vector.length(desiredVX, desiredVY)
    util.update_engine_trail(entity, true, impulseX, impulseY, dt, desiredSpeedAbs)

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

local function wander_action(entity, _, dt)
    local body = entity.body
    if not body or body:isDestroyed() then
        return BTStatus.failure
    end

    local ai = entity.ai or {}
    local stats = entity.stats or {}

    return util.handle_wander(entity, body, ai, stats, dt) and BTStatus.success or BTStatus.failure
end

function HunterBehavior.buildTree()
    local ensureTargetNode = BehaviorTree.Action(ensure_target_action)
    local engageTargetNode = BehaviorTree.Action(function(entity, blackboard, dt)
        return engage_target_action(entity, blackboard, dt)
    end)
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

function HunterBehavior.tick(entity, data, systemContext, runtimeContext, dt)
    local ai = entity.ai or {}
    util.ensure_home(ai, entity)

    local blackboard = ensure_blackboard(data, systemContext)
    blackboard.world = runtimeContext.world

    if entity.retaliationTimer and entity.retaliationTimer > 0 then
        entity.retaliationTimer = math.max(0, entity.retaliationTimer - dt)
        if entity.retaliationTimer <= 0 then
            entity.retaliationTarget = nil
        end
    end

    local tree = ensure_behavior_tree(data)
    local status = tree:tick(entity, blackboard, dt)

    if status == BTStatus.failure then
        util.disable_weapon(entity)
    end

    return status
end

return HunterBehavior
