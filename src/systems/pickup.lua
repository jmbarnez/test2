local tiny = require("libs.tiny")
local PlayerManager = require("src.player.manager")
local ShipCargo = require("src.ships.cargo")
local vector = require("src.util.vector")

---@diagnostic disable-next-line: undefined-global
local love = love
local math = math

return function(context)
    context = context or {}

    local state = context.state
    local defaultDamping = context.damping or 2.5
    local defaultCollectRadius = context.collectRadius or 48
    local defaultBobSpeed = context.bobSpeed or 2.1
    local defaultMagnetStrength = context.magnetStrength or 150
    local defaultMagnetFalloff = context.magnetFalloff or 1
    local collectorBuffer = context.collectorBuffer or {}
    local collectorSeen = context.collectorSeen or {}
    context.collectorBuffer = collectorBuffer
    context.collectorSeen = collectorSeen

    local function gather_collectors(current_state)
        local count = 0
        if not current_state then
            return count
        end

        for key in pairs(collectorSeen) do
            collectorSeen[key] = nil
        end

        local function add_collector(entity)
            if entity and entity.position and entity.cargo and not collectorSeen[entity] then
                count = count + 1
                collectorBuffer[count] = entity
                collectorSeen[entity] = true
            end
        end

        local players = PlayerManager.collectAllPlayers(current_state)
        for _, entity in pairs(players) do
            add_collector(entity)
        end

        local world = current_state.world
        if world and world.entities then
            for i = 1, #world.entities do
                add_collector(world.entities[i])
            end
        end

        for i = count + 1, #collectorBuffer do
            collectorBuffer[i] = nil
        end

        return count
    end

    return tiny.processingSystem {
        filter = tiny.requireAll("pickup", "position"),

        process = function(self, entity, dt)
            local pickup = entity.pickup
            if not pickup then
                return
            end

            pickup.age = (pickup.age or 0) + dt
            if pickup.lifetime and pickup.lifetime > 0 and pickup.age >= pickup.lifetime then
                entity.pendingDestroy = true
                return
            end

            local pos = entity.position
            local vel = entity.velocity
            if pos and not vel then
                vel = { x = 0, y = 0 }
                entity.velocity = vel
            end
            if pos and vel then
                local vx = vel.x or 0
                local vy = vel.y or 0
                pos.x = pos.x + vx * dt
                pos.y = pos.y + vy * dt

                local damping = pickup.damping or defaultDamping
                if damping and damping > 0 then
                    local decay = math.max(0, 1 - damping * dt)
                    vel.x = vx * decay
                    vel.y = vy * decay
                end
            end

            if pickup.spinSpeed and pickup.spinSpeed ~= 0 then
                entity.rotation = (entity.rotation or 0) + pickup.spinSpeed * dt
            end

            if entity.drawable then
                entity.drawable.bobSpeed = entity.drawable.bobSpeed or pickup.bobSpeed or defaultBobSpeed
            end

            if not (state and pos and pickup.item) then
                return
            end

            local collectorCount = gather_collectors(state)
            local baseCollectRadius = pickup.collectRadius or defaultCollectRadius

            for index = 1, collectorCount do
                local ship = collectorBuffer[index]
                if ship and ship.position then
                    local dx = (ship.position.x or 0) - pos.x
                    local dy = (ship.position.y or 0) - pos.y
                    local distSq = vector.length_squared(dx, dy)

                    local magnet = ship.magnet
                    if magnet and magnet.radius and magnet.radius > 0 and vel then
                        local magnetRadius = magnet.radius
                        local magnetRadiusSq = magnetRadius * magnetRadius
                        if distSq <= magnetRadiusSq then
                            local dirX, dirY, dist = vector.normalize(dx, dy)
                            local falloff = magnet.falloff or defaultMagnetFalloff
                            local strength = magnet.strength or defaultMagnetStrength
                            local normalized = 1 - math.min(1, dist / magnetRadius)
                            local influence = normalized > 0 and (normalized ^ falloff) or 0
                            if influence > 0 then
                                vel.x = (vel.x or 0) + dirX * strength * influence * dt
                                vel.y = (vel.y or 0) + dirY * strength * influence * dt
                            end
                        end
                    end

                    local collectRadius = baseCollectRadius
                    if magnet and magnet.collectRadius and magnet.collectRadius > 0 then
                        collectRadius = magnet.collectRadius
                    end
                    if collectRadius <= 0 then
                        collectRadius = baseCollectRadius
                    end
                    local collectRadiusSq = collectRadius * collectRadius

                    if ship.cargo and distSq <= collectRadiusSq then
                        local cargoComponent = ship.cargo
                        local tryAdd = cargoComponent.tryAddItem
                            or (cargoComponent.try_add_item and function(component, descriptor, quantity)
                                return cargoComponent:try_add_item(descriptor, quantity)
                            end)
                            or ShipCargo.try_add_item
                        local ok = false
                        if tryAdd then
                            ok = select(1, tryAdd(cargoComponent, pickup.item, pickup.quantity))
                        end

                        if ok then
                            cargoComponent.dirty = true
                            pickup.collected = true
                            pickup.collectedBy = ship
                            if context.onCollected then
                                context.onCollected(pickup, ship, entity, state)
                            end
                            entity.pendingDestroy = true
                            return
                        end
                    end
                end
            end
        end,
    }
end
