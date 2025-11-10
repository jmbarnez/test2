local constants = require("src.constants.game")

local Prediction = {}

local function ensure_prediction_state(state)
    if not state then
        return nil
    end
    state.prediction = state.prediction or {}
    local pred = state.prediction
    pred.tick = pred.tick or 0
    pred.history = pred.history or {}
    pred.order = pred.order or {}
    pred.maxSize = pred.maxSize or constants.network.prediction_buffer_size or 90
    pred.lastAck = pred.lastAck or 0
    pred.lastRecordedTick = pred.lastRecordedTick or 0
    return pred
end

local function is_enabled()
    return constants.network.client_prediction_enabled
end

function Prediction.getLastRecordedTick(state)
    local pred = ensure_prediction_state(state)
    return pred and pred.lastRecordedTick or 0
end

function Prediction.initialize(state)
    return ensure_prediction_state(state)
end

local function copy_intent(intent)
    if not intent then
        return nil
    end
    return {
        moveX = intent.moveX,
        moveY = intent.moveY,
        moveMagnitude = intent.moveMagnitude,
        aimX = intent.aimX,
        aimY = intent.aimY,
        hasAim = intent.hasAim,
        firePrimary = intent.firePrimary,
        fireSecondary = intent.fireSecondary,
    }
end

function Prediction.reset(state)
    local pred = ensure_prediction_state(state)
    if not pred then
        return
    end
    pred.tick = 0
    pred.history = {}
    pred.order = {}
    pred.lastAck = 0
    pred.lastRecordedTick = 0
    pred.pendingRecordTick = nil
end

local function trim_history(pred)
    local maxSize = pred.maxSize or constants.network.prediction_buffer_size or 90
    while #pred.order > maxSize do
        local oldTick = table.remove(pred.order, 1)
        pred.history[oldTick] = nil
    end
end

function Prediction.recordInput(state, intent)
    if not is_enabled() then
        return nil
    end

    local pred = ensure_prediction_state(state)
    if not pred then
        return nil
    end

    pred.tick = pred.tick + 1
    local tick = pred.tick

    pred.history[tick] = {
        tick = tick,
        intent = copy_intent(intent),
    }
    pred.order[#pred.order + 1] = tick
    pred.pendingRecordTick = tick
    pred.lastRecordedTick = tick

    trim_history(pred)

    return tick
end

local function extract_entity_state(entity)
    if not entity then
        return nil
    end

    local px, py = 0, 0
    local vx, vy = 0, 0

    if entity.body and not entity.body:isDestroyed() then
        px, py = entity.body:getPosition()
        vx, vy = entity.body:getLinearVelocity()
    else
        if entity.position then
            px = entity.position.x or px
            py = entity.position.y or py
        end
        if entity.velocity then
            vx = entity.velocity.x or vx
            vy = entity.velocity.y or vy
        end
    end

    return {
        position = { x = px, y = py },
        velocity = { x = vx, y = vy },
    }
end

function Prediction.recordState(state, entity, tick)
    if not is_enabled() then
        return
    end

    local pred = ensure_prediction_state(state)
    if not pred then
        return
    end

    local targetTick = tick or pred.pendingRecordTick or pred.tick
    if not targetTick then
        return
    end

    local entry = pred.history[targetTick]
    if not entry then
        return
    end

    entry.predicted = extract_entity_state(entity)
    if targetTick == pred.pendingRecordTick then
        pred.pendingRecordTick = nil
    end
end

local function apply_authoritative_state(entity, snapshot)
    if not (entity and snapshot) then
        return
    end

    local position = snapshot.position
    local velocity = snapshot.velocity
    local rotation = snapshot.rotation

    if entity.body and not entity.body:isDestroyed() then
        if position then
            entity.body:setPosition(position.x or 0, position.y or 0)
        end
        if velocity then
            entity.body:setLinearVelocity(velocity.x or 0, velocity.y or 0)
        end
        if rotation ~= nil then
            entity.body:setAngle(rotation)
        end
    end

    entity.position = entity.position or {}
    if position then
        entity.position.x = position.x or entity.position.x or 0
        entity.position.y = position.y or entity.position.y or 0
    end

    if velocity then
        entity.velocity = entity.velocity or {}
        entity.velocity.x = velocity.x or 0
        entity.velocity.y = velocity.y or 0
    end

    if rotation ~= nil then
        entity.rotation = rotation
    end
end

local function exceeds_threshold(snapshot, predicted)
    if not (snapshot and predicted) then
        return true
    end

    local posThreshold = constants.network.prediction_position_threshold or 6
    local velThreshold = constants.network.prediction_velocity_threshold or 4

    local position = snapshot.position or { x = 0, y = 0 }
    local predictedPos = predicted.position or { x = 0, y = 0 }
    local dx = (position.x or 0) - (predictedPos.x or 0)
    local dy = (position.y or 0) - (predictedPos.y or 0)

    if math.abs(dx) > posThreshold or math.abs(dy) > posThreshold then
        return true
    end

    local velocity = snapshot.velocity or { x = 0, y = 0 }
    local predictedVel = predicted.velocity or { x = 0, y = 0 }
    local dvx = (velocity.x or 0) - (predictedVel.x or 0)
    local dvy = (velocity.y or 0) - (predictedVel.y or 0)

    if math.abs(dvx) > velThreshold or math.abs(dvy) > velThreshold then
        return true
    end

    return false
end

local function cleanup_history(pred, ackTick)
    if not pred or not ackTick then
        return
    end

    pred.lastAck = math.max(pred.lastAck or 0, ackTick)

    while #pred.order > 0 and pred.order[1] <= ackTick do
        local oldTick = table.remove(pred.order, 1)
        pred.history[oldTick] = nil
    end

    if pred.pendingRecordTick and pred.pendingRecordTick <= ackTick then
        pred.pendingRecordTick = nil
    end
end

function Prediction.reconcile(state, entity, snapshot)
    if not is_enabled() then
        return
    end

    local pred = ensure_prediction_state(state)
    if not pred or not snapshot then
        return
    end

    local ackTick = snapshot.lastInputTick or snapshot.last_input_tick
    if not ackTick then
        return
    end

    local entry = pred.history[ackTick]
    local corrected = false

    if entry and entry.predicted and snapshot.position then
        if exceeds_threshold(snapshot, entry.predicted) then
            apply_authoritative_state(entity, snapshot)
            corrected = true
        end
    else
        apply_authoritative_state(entity, snapshot)
        corrected = true
    end

    cleanup_history(pred, ackTick)

    return corrected, ackTick
end

return Prediction
