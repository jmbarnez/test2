---@diagnostic disable: undefined-global, deprecated

local tiny = require("libs.tiny")

local TAU = math.pi * 2

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
            strafeTimer = love.math.random() * 1.2 + 0.4,
            strafeDir = love.math.random() < 0.5 and -1 or 1,
        }
        entity.aiState = state
    end
    return state
end

local function clamp_angle(angle)
    angle = angle % TAU
    if angle > math.pi then
        angle = angle - TAU
    elseif angle < -math.pi then
        angle = angle + TAU
    end
    return angle
end

local function is_target_valid(target)
    if not target then
        return false
    end

    local dead = (target.health and target.health.current and target.health.current <= 0)
        or (target.body and target.body:isDestroyed())

    return not dead
end

local function normalize_vector(x, y)
    local len = math.sqrt(x * x + y * y)
    if len < 1e-5 then
        return 0, 0, 1e-5
    end
    return x / len, y / len, len
end

local function clamp_vector(vx, vy, maxMagnitude)
    local magSq = vx * vx + vy * vy
    local maxSq = maxMagnitude * maxMagnitude
    if magSq > maxSq then
        local scale = math.sqrt(maxSq / magSq)
        return vx * scale, vy * scale
    end
    return vx, vy
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
    local angle = love.math.random() * TAU
    local dist = love.math.random() * radius
    return home.x + math.cos(angle) * dist, home.y + math.sin(angle) * dist
end

local function handle_wander(entity, body, ai, stats, dt)
    local position = entity.position
    if not (position and position.x and position.y) then
        return false
    end

    local home = ensure_home(ai, entity)
    if not home then
        return false
    end

    local radius = ai.wanderRadius or stats.wander_radius or 0
    if radius <= 0 then
        return false
    end

    local arriveRadius = ai.wanderArriveRadius or math.max(40, radius * 0.2)
    local state = ensure_ai_state(entity)

    local maxSpeed = stats.max_speed or 240
    local wanderSpeed = ai.wanderSpeed or stats.wander_speed or (maxSpeed * 0.55)
    wanderSpeed = math.min(wanderSpeed, maxSpeed)

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
    local tx, ty = target.x, target.y
    local dx, dy = tx - ex, ty - ey
    local dirX, dirY, distance = normalize_vector(dx, dy)

    if distance <= arriveRadius then
        state.wanderTarget = nil
        local vx, vy = body:getLinearVelocity()
        local damping = math.max(0, 1 - dt * 5)
        body:setLinearVelocity(vx * damping, vy * damping)

        if entity.weapon then
            entity.weapon.firing = false
            entity.weapon.targetX = nil
            entity.weapon.targetY = nil
        end

        return true
    end

    local desiredAngle = math.atan2(dy, dx) + math.pi * 0.5
    local currentAngle = body:getAngle()
    local delta = clamp_angle(desiredAngle - currentAngle)

    body:setAngularVelocity(0)
    body:setAngle(currentAngle + delta)
    entity.rotation = body:getAngle()

    local maxAccel = stats.max_acceleration or 600
    local mass = stats.mass or body:getMass() or 1

    local desiredVX = dirX * wanderSpeed
    local desiredVY = dirY * wanderSpeed
    desiredVX, desiredVY = clamp_vector(desiredVX, desiredVY, maxSpeed)

    local currentVX, currentVY = body:getLinearVelocity()
    local diffX, diffY = desiredVX - currentVX, desiredVY - currentVY
    local diffLen = math.sqrt(diffX * diffX + diffY * diffY)

    if diffLen > 0 then
        local maxDelta = maxAccel * dt
        if diffLen > maxDelta then
            local scale = maxDelta / diffLen
            diffX, diffY = diffX * scale, diffY * scale
        end

        body:applyLinearImpulse(diffX * mass, diffY * mass)
    end

    local newVX, newVY = body:getLinearVelocity()
    newVX, newVY = clamp_vector(newVX, newVY, maxSpeed)
    body:setLinearVelocity(newVX, newVY)

    if entity.weapon then
        entity.weapon.firing = false
        entity.weapon.targetX = nil
        entity.weapon.targetY = nil
    end

    return true
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
            local stats = entity.stats or {}
            ensure_home(ai, entity)
            local detectionRange = ai.detectionRange or stats.detection_range or ai.engagementRange or stats.max_range
            local disengageRange = ai.disengageRange or stats.disengage_range or (detectionRange and detectionRange * 1.25)

            local target = entity.currentTarget

            if not is_target_valid(target) then
                local preferred = context.player
                target = find_target(self.world, ai.targetTag or "player", preferred, entity.position, detectionRange)
                entity.currentTarget = target
            end

            if not (target and target.position) then
                if handle_wander(entity, body, ai, stats, dt) then
                    return
                end

                if entity.weapon then
                    entity.weapon.firing = false
                    entity.weapon.targetX = nil
                    entity.weapon.targetY = nil
                end
                return
            end

            local ex, ey = entity.position.x, entity.position.y
            local tx, ty = target.position.x, target.position.y
            local dx, dy = tx - ex, ty - ey
            local dirX, dirY, distance = normalize_vector(dx, dy)

            local desiredAngle = math.atan2(dy, dx) + math.pi * 0.5
            local currentAngle = body:getAngle()
            local delta = clamp_angle(desiredAngle - currentAngle)

            body:setAngularVelocity(0)
            body:setAngle(currentAngle + delta)
            entity.rotation = body:getAngle()

            local preferredDistance = ai.preferredDistance or stats.preferred_distance or (ai.engagementRange or 600) * 0.6
            local maxSpeed = stats.max_speed or 240
            local maxAccel = stats.max_acceleration or 600
            local mass = stats.mass or body:getMass() or 1

            local dropRange = disengageRange or detectionRange
            if dropRange and dropRange > 0 and distance > dropRange then
                entity.currentTarget = nil
                if entity.weapon then
                    entity.weapon.firing = false
                    entity.weapon.targetX = nil
                    entity.weapon.targetY = nil
                end
                return
            end

            local desiredVX, desiredVY = 0, 0
            local farDistance = preferredDistance * 1.1
            local closeDistance = math.max(80, preferredDistance * 0.8)

            if distance > farDistance then
                desiredVX, desiredVY = dirX * maxSpeed, dirY * maxSpeed
            elseif distance < closeDistance then
                desiredVX, desiredVY = -dirX * maxSpeed, -dirY * maxSpeed
            end

            local strafeThrust = stats.strafe_thrust or 0
            if strafeThrust > 0 and distance <= farDistance then
                local state = ensure_ai_state(entity)
                state.strafeTimer = state.strafeTimer - dt
                if state.strafeTimer <= 0 then
                    state.strafeTimer = love.math.random() * 1.2 + 0.4
                    state.strafeDir = love.math.random() < 0.5 and -1 or 1
                end

                local strafeDirX, strafeDirY = -dirY * state.strafeDir, dirX * state.strafeDir
                local strafeSpeed = maxSpeed * 0.6
                desiredVX = desiredVX + strafeDirX * strafeSpeed
                desiredVY = desiredVY + strafeDirY * strafeSpeed
            end

            desiredVX, desiredVY = clamp_vector(desiredVX, desiredVY, maxSpeed)

            local currentVX, currentVY = body:getLinearVelocity()
            local diffX, diffY = desiredVX - currentVX, desiredVY - currentVY
            local diffLen = math.sqrt(diffX * diffX + diffY * diffY)

            if diffLen > 0 then
                local maxDelta = maxAccel * dt
                if diffLen > maxDelta then
                    local scale = maxDelta / diffLen
                    diffX, diffY = diffX * scale, diffY * scale
                end

                body:applyLinearImpulse(diffX * mass, diffY * mass)
            end

            local newVX, newVY = body:getLinearVelocity()
            newVX, newVY = clamp_vector(newVX, newVY, maxSpeed)
            body:setLinearVelocity(newVX, newVY)

            if entity.weapon then
                local weapon = entity.weapon
                local maxRange = weapon.maxRange or stats.max_range or 600
                local engagementRange = ai.engagementRange or maxRange
                local canFire = distance <= engagementRange

                weapon.firing = canFire
                weapon.targetX = canFire and tx or nil
                weapon.targetY = canFire and ty or nil
            end
        end,
    }
end
