local tiny = require("libs.tiny")
local PlayerManager = require("src.player.manager")
local ShipCargo = require("src.ships.cargo")
local vector = require("src.util.vector")
local AudioManager = require("src.audio.manager")

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
    local overflowRepelStrength = context.overflowRepelStrength or 120
    local collectorBuffer = context.collectorBuffer or {}
    local collectorSeen = context.collectorSeen or {}
    context.collectorBuffer = collectorBuffer
    context.collectorSeen = collectorSeen

    local function gather_collectors(current_state)
        if not current_state then
            return 0
        end

        for key in pairs(collectorSeen) do
            collectorSeen[key] = nil
        end

        local count = 0
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

    local function calculate_required_volume(pickup)
        if not pickup.item then return 0 end
        local quantity = pickup.quantity or pickup.item.quantity or 1
        local perVolume = pickup.item.volume or pickup.item.unitVolume or 0
        return math.max(0, perVolume * quantity)
    end

    local function can_collect_item(cargo, requiredVolume)
        if not cargo or requiredVolume <= 0 then return true end
        if not cargo.canFit then return true end
        return cargo:canFit(requiredVolume)
    end

    local function apply_magnet_force(vel, dx, dy, magnet, cargoFull, dt)
        if not magnet or not magnet.radius or magnet.radius <= 0 then return end

        local dist = vector.length(dx, dy)
        if dist > magnet.radius then return end

        local dirX, dirY = dx / dist, dy / dist
        local falloff = magnet.falloff or defaultMagnetFalloff
        local strength = magnet.strength or defaultMagnetStrength
        local normalized = 1 - (dist / magnet.radius)
        local influence = normalized ^ falloff

        if cargoFull then
            vel.x = vel.x - dirX * overflowRepelStrength * dt
            vel.y = vel.y - dirY * overflowRepelStrength * dt
        else
            vel.x = vel.x + dirX * strength * influence * dt
            vel.y = vel.y + dirY * strength * influence * dt
        end
    end

    local function try_collect_item(ship, pickup, entity)
        local cargo = ship.cargo
        local tryAdd = cargo.tryAddItem
            or (cargo.try_add_item and function(c, desc, qty)
                return c:try_add_item(desc, qty)
            end)
            or ShipCargo.try_add_item

        if not tryAdd then return false end

        local ok = select(1, tryAdd(cargo, pickup.item, pickup.quantity))
        if ok then
            cargo.dirty = true
            pickup.collected = true
            pickup.collectedBy = ship
            if context.onCollected then
                context.onCollected(pickup, ship, entity, state)
            end
            AudioManager.play_sfx("sfx:item_pickup")
            return true
        end
        return false
    end

    return tiny.processingSystem {
        filter = tiny.requireAll("pickup", "position"),

        process = function(self, entity, dt)
            local pickup = entity.pickup
            if not pickup then return end

            -- Handle lifetime
            pickup.age = (pickup.age or 0) + dt
            if pickup.lifetime and pickup.lifetime > 0 and pickup.age >= pickup.lifetime then
                entity.pendingDestroy = true
                return
            end

            -- Update position and velocity
            local pos = entity.position
            local vel = entity.velocity or { x = 0, y = 0 }
            entity.velocity = vel

            pos.x = pos.x + vel.x * dt
            pos.y = pos.y + vel.y * dt

            -- Apply damping
            local damping = pickup.damping or defaultDamping
            if damping > 0 then
                local decay = math.max(0, 1 - damping * dt)
                vel.x = vel.x * decay
                vel.y = vel.y * decay
            end

            -- Handle rotation
            if pickup.spinSpeed and pickup.spinSpeed ~= 0 then
                entity.rotation = (entity.rotation or 0) + pickup.spinSpeed * dt
            end

            -- Update drawable bob speed
            if entity.drawable then
                entity.drawable.bobSpeed = entity.drawable.bobSpeed or pickup.bobSpeed or defaultBobSpeed
            end

            if not (state and pickup.item) then return end

            -- Process collection
            local collectorCount = gather_collectors(state)
            local baseCollectRadius = pickup.collectRadius or defaultCollectRadius
            local requiredVolume = calculate_required_volume(pickup)

            for index = 1, collectorCount do
                local ship = collectorBuffer[index]
                if ship and ship.position then
                    local dx = ship.position.x - pos.x
                    local dy = ship.position.y - pos.y
                    local distSq = dx * dx + dy * dy

                    local canCollect = can_collect_item(ship.cargo, requiredVolume)

                    -- Apply magnet force
                    if ship.magnet then
                        apply_magnet_force(vel, dx, dy, ship.magnet, not canCollect, dt)
                    end

                    -- Determine collection radius
                    local collectRadius = (ship.magnet and ship.magnet.collectRadius and ship.magnet.collectRadius > 0)
                        and ship.magnet.collectRadius or baseCollectRadius
                    local collectRadiusSq = collectRadius * collectRadius

                    -- Try to collect
                    if distSq <= collectRadiusSq then
                        if not canCollect then
                            local dist = math.sqrt(distSq)
                            local dirX, dirY = dx / dist, dy / dist
                            vel.x = vel.x - dirX * overflowRepelStrength * dt
                            vel.y = vel.y - dirY * overflowRepelStrength * dt
                        elseif ship.cargo and try_collect_item(ship, pickup, entity) then
                            entity.pendingDestroy = true
                            return
                        end
                    end
                end
            end
        end,
    }
end
