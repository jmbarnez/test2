---@diagnostic disable: undefined-global

local tiny = require("libs.tiny")
local vector = require("src.util.vector")
local Intent = require("src.input.intent")
local weapon_common = require("src.util.weapon_common")
local weapon_beam = require("src.util.weapon_beam")

local love = love

---@class WeaponLogicSystemContext
---@field camera table|nil
---@field intentHolder table|nil
---@field state table|nil
---@field resolveState fun(self:table):table|nil

local function resolve_gameplay_state(context)
    if context and type(context.resolveState) == "function" then
        local ok, state = pcall(context.resolveState, context)
        if ok and state then
            return state
        end
    end
    return context and context.state or nil
end

local function resolve_local_player(intentHolder)
    if not intentHolder then
        return nil, nil
    end
    return intentHolder.localPlayerId, intentHolder.player or intentHolder.playerShip
end

return function(context)
    context = context or {}

    return tiny.processingSystem {
        filter = tiny.requireAll("weapon", "position"),

        process = function(self, entity, dt)
            local weapon = entity.weapon
            if not weapon then
                return
            end

            -- Compute muzzle origin and forward direction
            local angle = entity.rotation or 0
            local forwardX = math.cos(angle - math.pi * 0.5)
            local forwardY = math.sin(angle - math.pi * 0.5)
            local startX, startY = weapon_common.compute_muzzle_origin(entity)

            weapon_common.update_all_weapon_cooldowns(entity, dt)

            local gameplayState = resolve_gameplay_state(context)
            local cam = context.camera
            local intentHolder = context.intentHolder or context.state or context
            local uiInput = context.uiInput or (gameplayState and gameplayState.uiInput)
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

            local intent = Intent.get(intentHolder, entity.playerId)

            if entity.player then
                if localPlayerId then
                    isLocalPlayer = entity.playerId == localPlayerId
                elseif localPlayerEntity then
                    isLocalPlayer = entity == localPlayerEntity
                end

                if intent then
                    fire = not not intent.firePrimary
                    targetX = intent.aimX or targetX
                    targetY = intent.aimY or targetY
                elseif not isLocalPlayer then
                    fire = weapon.firing or weapon.alwaysFire
                    if weapon.fireMode == "hitscan" and weapon.beamTimer and weapon.beamTimer > 0 then
                        fire = true
                    end
                end
            else
                fire = weapon.firing or weapon.alwaysFire
            end

            if (not targetX or not targetY)
                and isLocalPlayer
                and love and love.mouse and love.mouse.getPosition
                and not mouseCaptured
            then
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
                targetX = targetX or mx
                targetY = targetY or my
            end

            if isLocalPlayer and not fire and love and love.mouse and love.mouse.isDown then
                if not mouseCaptured then
                    local isControlHeld = love.keyboard and love.keyboard.isDown
                        and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl"))
                    if not isControlHeld then
                        fire = love.mouse.isDown(1)
                    end
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
            if targetX and targetY then
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
        end,
    }
end
