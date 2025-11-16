--- Target Locking System
-- Manages timed target acquisition for missiles and weapons

local PlayerManager = require("src.player.manager")

local Targeting = {}

--- Initialize target lock on an entity
---@param state table Gameplay state
---@param target table Target entity
function Targeting.beginLock(state, target)
    if not (state and target) then
        return
    end

    local player = PlayerManager.getCurrentShip(state)
    local targetingTime
    if player and player.stats and player.stats.targetingTime then
        targetingTime = player.stats.targetingTime
    end
    targetingTime = targetingTime or 0.6

    state.targetLockTarget = target
    state.targetLockTimer = targetingTime
    state.targetLockDuration = targetingTime
    state.activeTarget = nil

    local cache = state.targetingCache
    if cache then
        cache.activeEntity = nil
        cache.entity = target
        cache.lockCandidate = target
        cache.lockProgress = 0
        cache.lockDuration = targetingTime
    end
end

--- Clear target lock
---@param state table Gameplay state
function Targeting.clearLock(state)
    if not state then
        return
    end

    state.targetLockTarget = nil
    state.targetLockTimer = nil
    state.targetLockDuration = nil
    
    local cache = state.targetingCache
    if cache then
        cache.lockCandidate = nil
        cache.lockProgress = nil
        cache.lockDuration = nil
    end
end

--- Clear active target
---@param state table Gameplay state
function Targeting.clearActive(state)
    if not state then
        return
    end

    state.activeTarget = nil
    
    local cache = state.targetingCache
    if cache then
        cache.activeEntity = nil
        cache.entity = cache.hoveredEntity
    end
end

--- Update target lock progress
---@param state table Gameplay state
---@param dt number Delta time
function Targeting.update(state, dt)
    if not (state and state.targetLockTarget) then
        return
    end

    local target = state.targetLockTarget
    local cache = state.targetingCache

    -- Check if target is still valid
    local invalid = not target
        or target.pendingDestroy
        or (target.health and target.health.current and target.health.current <= 0)

    if invalid then
        Targeting.clearLock(state)
        if cache then
            cache.activeEntity = state.activeTarget
            cache.entity = state.activeTarget or cache.hoveredEntity
        end
        return
    end

    -- Update cache with current lock candidate
    if cache and cache.lockCandidate ~= target then
        cache.lockCandidate = target
        cache.lockProgress = 0
        cache.lockDuration = state.targetLockDuration or state.targetLockTimer or 0
    end

    -- Update lock timer
    if state.targetLockTimer then
        state.targetLockTimer = state.targetLockTimer - dt
        
        if cache and cache.lockDuration and cache.lockDuration > 0 then
            local progress = 1 - (state.targetLockTimer or 0) / cache.lockDuration
            cache.lockProgress = math.max(0, math.min(1, progress))
        end
    end

    -- Check if lock is complete
    if not state.targetLockTimer or state.targetLockTimer <= 0 then
        state.activeTarget = target
        state.targetLockTarget = nil
        state.targetLockTimer = nil
        state.targetLockDuration = nil
        
        if cache then
            cache.activeEntity = target
            cache.entity = target
            cache.lockCandidate = nil
            cache.lockProgress = nil
            cache.lockDuration = nil
        end
    end
end

return Targeting
