---@diagnostic disable: undefined-global

---Unified weapon system that delegates to behavior plugins
local tiny = require("libs.tiny")
local BehaviorRegistry = require("src.weapons.behavior_registry")
local vector = require("src.util.vector")
local weapon_common = require("src.util.weapon_common")
local weapon_beam = require("src.util.weapon_beam")

local love = love

---@class WeaponUnifiedContext
---@field world table|nil The ECS world
---@field physicsWorld love.World|nil The physics world
---@field damageEntity fun(target:table, amount:number, source:table, context:table)|nil Damage function
---@field camera table|nil The camera
---@field intentHolder table|nil Intent holder
---@field state table|nil The game state
---@field uiInput table|nil UI input state

local function resolve_gameplay_state(systemContext)
    if systemContext and type(systemContext.resolveState) == "function" then
        local ok, state = pcall(systemContext.resolveState, systemContext)
        if ok and state then
            return state
        end
    end
    return systemContext and systemContext.state or nil
end

local function resolve_local_player(intentHolder)
    if not intentHolder then
        return nil, nil
    end
    return intentHolder.localPlayerId, intentHolder.player or intentHolder.playerShip
end

local function is_control_held()
    if not (love and love.keyboard and love.keyboard.isDown) then
        return false
    end
    return love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
end

return function(systemContext)
    systemContext = systemContext or {}

    local system = tiny.processingSystem {
        filter = tiny.requireAll("weapon", "position"),

        process = function(self, entity, dt)
            local weapon = entity.weapon
            if not weapon then
                return
            end

            -- Get the behavior plugin for this weapon
            local behavior = BehaviorRegistry:resolve(weapon)
            if not behavior then
                -- No behavior registered, skip
                return
            end

            -- Update shared weapon state (aiming, cooldowns, inputs)
            weapon_common.update_all_weapon_cooldowns(entity, dt)

            local angle = entity.rotation or 0
            local forwardX = math.cos(angle - math.pi * 0.5)
            local forwardY = math.sin(angle - math.pi * 0.5)
            local startX, startY = weapon_common.compute_muzzle_origin(entity)

            local gameplayState = resolve_gameplay_state(systemContext)
            local cam = systemContext.camera
            local intentHolder = systemContext.intentHolder or systemContext.state or systemContext
            local uiInput = systemContext.uiInput or (gameplayState and gameplayState.uiInput)
            local mouseCaptured = false
            if uiInput and uiInput.mouseCaptured then
                mouseCaptured = true
            elseif gameplayState and gameplayState.uiInput and gameplayState.uiInput.mouseCaptured then
                mouseCaptured = true
            end

            local localPlayerId, localPlayerEntity = resolve_local_player(intentHolder)

            local fire = false
            local targetX, targetY = weapon.targetX, weapon.targetY
            local activeTarget
            local isLocalPlayer = false

            if entity.player then
                if localPlayerId then
                    isLocalPlayer = entity.playerId == localPlayerId
                elseif localPlayerEntity then
                    isLocalPlayer = entity == localPlayerEntity
                end

                if not isLocalPlayer then
                    fire = weapon.firing or weapon.alwaysFire
                    if weapon.fireMode == "hitscan" and weapon.beamTimer and weapon.beamTimer > 0 then
                        fire = true
                    end
                end
            else
                fire = weapon.firing or weapon.alwaysFire
            end

            if isLocalPlayer and love and love.mouse and love.mouse.getPosition and not mouseCaptured then
                local mx, my = love.mouse.getPosition()
                if cam then
                    local zoom = cam.zoom or 1
                    if zoom ~= 0 then
                        mx = mx / zoom + (cam.x or 0)
                        my = my / zoom + (cam.y or 0)
                    else
                        mx = cam.x or 0
                        my = cam.y or 0
                    end
                end
                targetX = mx
                targetY = my
            end

            if isLocalPlayer and not fire and love and love.mouse and love.mouse.isDown and not mouseCaptured then
                if not is_control_held() then
                    fire = love.mouse.isDown(1)
                end
            end

            if weapon.lockOnTarget and gameplayState then
                local candidate = gameplayState.activeTarget
                if candidate and not candidate.pendingDestroy then
                    local tx, ty = weapon_beam.resolve_entity_position(candidate)
                    if tx and ty then
                        activeTarget = candidate
                        targetX = tx
                        targetY = ty
                    end
                end
            end

            weapon.targetX = targetX
            weapon.targetY = targetY

            if weapon.travelToCursor and targetX and targetY and isLocalPlayer then
                local indicator = weapon._pendingTravelIndicator or {}
                indicator.x = targetX
                indicator.y = targetY
                indicator.radius = weapon.travelIndicatorRadius
                    or weapon.impactRadius
                    or (weapon.projectileSize and weapon.projectileSize * 3.2)
                    or 32
                indicator.outlineColor = indicator.outlineColor or weapon.travelIndicatorColor or weapon.glowColor or weapon.color
                indicator.innerColor = indicator.innerColor or weapon.travelIndicatorInnerColor
                weapon._pendingTravelIndicator = indicator
            else
                weapon._pendingTravelIndicator = nil
            end

            local dirX, dirY
            local hasTarget = targetX and targetY
            local preferForwardLaunch = weapon.preferForwardLaunch
            if preferForwardLaunch == nil then
                if weapon.projectileHoming or weapon.homing then
                    preferForwardLaunch = true
                else
                    preferForwardLaunch = false
                end
            end
            local launchForward = preferForwardLaunch and hasTarget and activeTarget
            if hasTarget and not launchForward then
                dirX = targetX - startX
                dirY = targetY - startY
            else
                dirX = forwardX
                dirY = forwardY
            end

            local normDirX, normDirY, dirLen = vector.normalize(dirX, dirY)
            if dirLen <= vector.EPSILON then
                dirX = forwardX
                dirY = forwardY
            else
                dirX = normDirX
                dirY = normDirY
            end

            weapon._muzzleX = startX
            weapon._muzzleY = startY
            weapon._fireDirX = dirX
            weapon._fireDirY = dirY
            weapon._fireRequested = fire
            weapon._activeTarget = activeTarget
            weapon._isLocalPlayer = isLocalPlayer

            -- Prepare context for behavior while reusing the same table to reduce GC churn
            local behaviorContext = self.behaviorContext
            for key in pairs(behaviorContext) do
                behaviorContext[key] = nil
            end
            behaviorContext.world = self.world
            behaviorContext.physicsWorld = systemContext.physicsWorld
            behaviorContext.damageEntity = systemContext.damageEntity
            behaviorContext.camera = cam
            behaviorContext.intentHolder = intentHolder
            behaviorContext.state = systemContext.state
            behaviorContext.uiInput = uiInput
            behaviorContext.gameplayState = gameplayState

            -- Call update if behavior has it
            if behavior.update then
                behavior.update(entity, weapon, dt, behaviorContext)
            end

            -- Call onFireRequested if fire is requested and behavior has it
            if weapon._fireRequested and behavior.onFireRequested then
                behavior.onFireRequested(entity, weapon, behaviorContext)
            end
        end,
    }

    system.behaviorContext = {}

    return system
end
