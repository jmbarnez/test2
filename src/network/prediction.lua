-- Client-side prediction and server reconciliation system
-- Implements industry-standard netcode for perfect sync with only connection lag

local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")

local Prediction = {}

-- Input history for rollback
local inputHistory = {}
local stateHistory = {}
local maxHistoryFrames = constants.network.max_rollback_frames or 30

-- Current frame counter
local currentFrame = 0

-- Prediction state
local predictionEnabled = constants.network.prediction_enabled
local reconciliationEnabled = constants.network.reconciliation_enabled
local positionTolerance = constants.network.position_tolerance or 5.0

function Prediction.initialize(state)
    if not state then return end
    
    state.prediction = {
        enabled = predictionEnabled,
        currentFrame = 0,
        inputHistory = {},
        stateHistory = {},
        lastServerFrame = 0,
        pendingInputs = {},
    }
end

-- Store input for this frame
function Prediction.recordInput(state, input)
    if not (state and state.prediction and predictionEnabled) then
        return
    end
    
    local pred = state.prediction
    pred.currentFrame = pred.currentFrame + 1
    
    -- Store input with frame number
    local inputRecord = {
        frame = pred.currentFrame,
        timestamp = love.timer.getTime(),
        input = {
            moveX = input.moveX or 0,
            moveY = input.moveY or 0,
            aimX = input.aimX,
            aimY = input.aimY,
            hasAim = input.hasAim,
            firePrimary = input.firePrimary,
            fireSecondary = input.fireSecondary,
        }
    }
    
    -- Add to history
    table.insert(pred.inputHistory, inputRecord)
    
    -- Trim history
    while #pred.inputHistory > maxHistoryFrames do
        table.remove(pred.inputHistory, 1)
    end
    
    -- Add to pending inputs (waiting for server confirmation)
    table.insert(pred.pendingInputs, inputRecord)
end

-- Store state snapshot for rollback
function Prediction.recordState(state)
    if not (state and state.prediction and predictionEnabled) then
        return
    end
    
    local localPlayer = PlayerManager.getCurrentShip(state)
    if not localPlayer then return end
    
    local pred = state.prediction
    
    local stateRecord = {
        frame = pred.currentFrame,
        timestamp = love.timer.getTime(),
        position = {
            x = localPlayer.position.x,
            y = localPlayer.position.y
        },
        rotation = localPlayer.rotation,
        velocity = localPlayer.velocity and {
            x = localPlayer.velocity.x,
            y = localPlayer.velocity.y
        } or {x = 0, y = 0}
    }
    
    table.insert(pred.stateHistory, stateRecord)
    
    -- Trim history
    while #pred.stateHistory > maxHistoryFrames do
        table.remove(pred.stateHistory, 1)
    end
end

-- Server reconciliation when snapshot arrives
function Prediction.reconcile(state, serverSnapshot, serverFrame)
    if not (state and state.prediction and reconciliationEnabled) then
        return
    end
    
    local localPlayer = PlayerManager.getCurrentShip(state)
    if not localPlayer then return end
    
    local pred = state.prediction
    pred.lastServerFrame = serverFrame
    
    -- Find the state record for this server frame
    local stateRecord = nil
    for i = #pred.stateHistory, 1, -1 do
        local record = pred.stateHistory[i]
        if record.frame <= serverFrame then
            stateRecord = record
            break
        end
    end
    
    if not stateRecord then return end
    
    -- Check if server position differs significantly from our prediction
    local serverPos = serverSnapshot.position
    if not serverPos then return end
    
    local dx = serverPos.x - stateRecord.position.x
    local dy = serverPos.y - stateRecord.position.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > positionTolerance then
        print(string.format("[PREDICTION] Reconciling: server=(%.1f,%.1f) client=(%.1f,%.1f) diff=%.1f", 
            serverPos.x, serverPos.y, 
            stateRecord.position.x, stateRecord.position.y, 
            distance))
        
        -- Rollback to server state
        localPlayer.position.x = serverPos.x
        localPlayer.position.y = serverPos.y
        if serverSnapshot.rotation ~= nil then
            localPlayer.rotation = serverSnapshot.rotation
        end
        if serverSnapshot.velocity then
            localPlayer.velocity = localPlayer.velocity or {}
            localPlayer.velocity.x = serverSnapshot.velocity.x
            localPlayer.velocity.y = serverSnapshot.velocity.y
        end
        
        -- Update physics body if it exists
        if localPlayer.body and not localPlayer.body:isDestroyed() then
            localPlayer.body:setPosition(serverPos.x, serverPos.y)
            if serverSnapshot.rotation ~= nil then
                localPlayer.body:setAngle(serverSnapshot.rotation)
            end
            if serverSnapshot.velocity then
                localPlayer.body:setLinearVelocity(serverSnapshot.velocity.x, serverSnapshot.velocity.y)
            end
        end
        
        -- Re-apply inputs that happened after this server frame
        Prediction.replayInputs(state, serverFrame)
    end
    
    -- Remove confirmed inputs from pending list
    local confirmedInputs = {}
    for i = #pred.pendingInputs, 1, -1 do
        local input = pred.pendingInputs[i]
        if input.frame <= serverFrame then
            table.remove(pred.pendingInputs, i)
        end
    end
end

-- Replay inputs after rollback
function Prediction.replayInputs(state, fromFrame)
    if not (state and state.prediction) then
        return
    end
    
    local pred = state.prediction
    local localPlayer = PlayerManager.getCurrentShip(state)
    if not localPlayer then return end
    
    -- Find inputs that happened after the server frame
    local inputsToReplay = {}
    for _, input in ipairs(pred.inputHistory) do
        if input.frame > fromFrame then
            table.insert(inputsToReplay, input)
        end
    end
    
    local body = localPlayer.body
    local stats = localPlayer.stats or {}
    local dt = 1 / 60

    -- Re-apply each input using the same thrust/acceleration logic as the player control system
    for _, inputRecord in ipairs(inputsToReplay) do
        local input = inputRecord.input
        local moveX = (input.moveX or 0) * (input.moveMagnitude or 0)
        local moveY = (input.moveY or 0) * (input.moveMagnitude or 0)

        -- Aim/rotation replay
        if input.hasAim and input.aimX and input.aimY then
            local toAimX = input.aimX - localPlayer.position.x
            local toAimY = input.aimY - localPlayer.position.y
            if (toAimX ~= 0 or toAimY ~= 0) then
                local desiredAngle = math.atan2(toAimY, toAimX) + math.pi * 0.5
                localPlayer.rotation = desiredAngle
                if body and not body:isDestroyed() then
                    body:setAngle(desiredAngle)
                    body:setAngularVelocity(0)
                end
            end
        end

        local applyingThrust = moveX ~= 0 or moveY ~= 0
        localPlayer.isThrusting = applyingThrust

        local thrust = stats.main_thrust or stats.thrust_force or 0
        local mass = stats.mass
        if not mass and body and not body:isDestroyed() then
            mass = body:getMass()
        end
        mass = mass or 1

        local maxAccel = stats.max_acceleration
        local maxSpeed = stats.max_speed or localPlayer.max_speed

        local forceX, forceY = 0, 0
        if applyingThrust and thrust > 0 then
            local magnitude = math.sqrt(moveX * moveX + moveY * moveY)
            if magnitude > 1e-6 then
                moveX, moveY = moveX / magnitude, moveY / magnitude
            end

            forceX = moveX * thrust
            forceY = moveY * thrust

            if maxAccel and maxAccel > 0 then
                local maxForce = maxAccel * mass
                local currentForceMag = math.sqrt(forceX * forceX + forceY * forceY)
                if currentForceMag > maxForce then
                    local scale = maxForce / currentForceMag
                    forceX = forceX * scale
                    forceY = forceY * scale
                end
            end

            localPlayer.currentThrust = math.sqrt(forceX * forceX + forceY * forceY)
            if stats.main_thrust then
                localPlayer.maxThrust = stats.main_thrust
            end
        else
            localPlayer.currentThrust = 0
        end

        -- Update velocity using simple Newtonian integration
        local velocity = localPlayer.velocity or { x = 0, y = 0 }
        local accelX = forceX / mass
        local accelY = forceY / mass
        velocity.x = velocity.x + accelX * dt
        velocity.y = velocity.y + accelY * dt

        if maxSpeed and maxSpeed > 0 then
            local velMag = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
            if velMag > maxSpeed then
                local scale = maxSpeed / velMag
                velocity.x = velocity.x * scale
                velocity.y = velocity.y * scale
            end
        end

        localPlayer.velocity = velocity

        -- Integrate position
        localPlayer.position.x = localPlayer.position.x + velocity.x * dt
        localPlayer.position.y = localPlayer.position.y + velocity.y * dt

        if body and not body:isDestroyed() then
            body:setLinearVelocity(velocity.x, velocity.y)
            body:setPosition(localPlayer.position.x, localPlayer.position.y)
        end
    end

    -- After replay, ensure position/velocity are reflected on body if it exists
    if body and not body:isDestroyed() then
        body:setLinearVelocity(localPlayer.velocity.x or 0, localPlayer.velocity.y or 0)
        body:setPosition(localPlayer.position.x, localPlayer.position.y)
    end
end

-- Check if we should apply server correction for local player
function Prediction.shouldApplyServerCorrection(state, playerId)
    if not (state and state.prediction and reconciliationEnabled) then
        return true -- Always apply if prediction disabled
    end
    
    local localPlayer = PlayerManager.getCurrentShip(state)
    if not localPlayer then return true end
    
    -- Don't apply direct server corrections to local player - use reconciliation instead
    return localPlayer.playerId ~= playerId
end

return Prediction
