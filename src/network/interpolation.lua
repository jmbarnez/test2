-- Drift correction system for remote entity synchronization
-- Monitors client physics vs server snapshots and corrects when drift exceeds thresholds

local constants = require("src.constants.game")

local Interpolation = {}

-- Update a single entity's interpolation
-- Only applies corrections when entity has drifted significantly from server position
function Interpolation.updateEntity(entity, dt)
    if not entity or not entity.netInterp or not entity.netInterp.initialized then
        return
    end
    
    if not entity.body or entity.body:isDestroyed() then
        return
    end
    
    local interp = entity.netInterp
    
    -- Get current physics position
    local currentX, currentY = entity.body:getPosition()
    local currentAngle = entity.body:getAngle()
    
    -- Check for significant position drift
    if interp.targetX and interp.targetY then
        local dx = interp.targetX - currentX
        local dy = interp.targetY - currentY
        local distance = math.sqrt(dx * dx + dy * dy)

        local SNAP_THRESHOLD = constants.network.interpolation_snap_threshold
        local BLEND_THRESHOLD = constants.network.interpolation_blend_threshold
        local CORRECTION_SPEED = constants.network.interpolation_correction_speed

        if distance > SNAP_THRESHOLD then
            -- Large drift - snap immediately
            currentX, currentY = interp.targetX, interp.targetY
            entity.body:setPosition(currentX, currentY)
            if entity.velocity then
                entity.body:setLinearVelocity(entity.velocity.x or 0, entity.velocity.y or 0)
            end
        elseif distance > BLEND_THRESHOLD then
            -- Blend toward server position to reduce visible teleporting
            local correction = math.min(dt * CORRECTION_SPEED, 1)
            currentX = currentX + dx * correction
            currentY = currentY + dy * correction
            entity.body:setPosition(currentX, currentY)
            if entity.velocity then
                entity.body:setLinearVelocity(entity.velocity.x or 0, entity.velocity.y or 0)
            end
        end

        -- Update cached position to the body value
        entity.position = entity.position or {}
        entity.position.x, entity.position.y = entity.body:getPosition()
    end
    
    -- Check for rotation drift
    if interp.targetRotation then
        local targetAngle = interp.targetRotation
        local angleDiff = targetAngle - currentAngle
        
        -- Normalize angle difference
        if angleDiff > math.pi then
            angleDiff = angleDiff - 2 * math.pi
        elseif angleDiff < -math.pi then
            angleDiff = angleDiff + 2 * math.pi
        end
        
        -- Correction threshold for rotation
        if math.abs(angleDiff) > constants.network.interpolation_rotation_threshold then
            entity.body:setAngle(interp.targetRotation)
        end
        
        entity.rotation = entity.body:getAngle()
    end
end

-- Update all entities in a world with interpolation
function Interpolation.updateWorld(world, dt)
    if not world or not world.entities then
        return
    end
    
    -- Only process entities that have interpolation data (much faster than checking all)
    for i = 1, #world.entities do
        local entity = world.entities[i]
        if entity and entity.netInterp and entity.netInterp.initialized then
            Interpolation.updateEntity(entity, dt)
        end
    end
end

return Interpolation
