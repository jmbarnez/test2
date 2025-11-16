---Plasma thrower weapon behavior
---Cloud/stream weapon with damage-over-time puffs
local base_cloud = require("src.weapons.behaviors.base_cloud")
local weapon_common = require("src.util.weapon_common")

local function update_puffs(weapon, world, entity, dt, damageEntity)
    local puffs = weapon._cloudPuffs
    if not puffs then
        return
    end
    
    local multiplier = weapon_common.resolve_damage_multiplier(entity)
    local worldEntities = world.entities or {}
    
    -- Update and damage with puffs
    for index = #puffs, 1, -1 do
        local puff = puffs[index]
        puff.lifetime = (puff.lifetime or 0) - dt
        if not (puff.lifetime and puff.lifetime > 0) then
            -- Remove expired puff
            table.remove(puffs, index)
        else
            -- Update puff physics
            puff.x = (puff.x or 0) + (puff.vx or 0) * dt
            puff.y = (puff.y or 0) + (puff.vy or 0) * dt
            
            -- Grow radius
            if puff.radius < puff.targetRadius then
                puff.radius = math.min(puff.targetRadius, puff.radius + (puff.radiusGrowth or 0) * dt)
            end
            
            -- Apply damage to entities in range
            local puffDamage = (puff.damagePerSecond or 0) * dt * multiplier
            if puffDamage > 0 then
                local radiusSq = (puff.radius or 0) * (puff.radius or 0)
                for _, target in ipairs(worldEntities) do
                    if base_cloud.shouldDamage(entity, target) then
                        local tx = (target.position and target.position.x) or 0
                        local ty = (target.position and target.position.y) or 0
                        local dx = tx - (puff.x or 0)
                        local dy = ty - (puff.y or 0)
                        local distSq = dx * dx + dy * dy
                        
                        if distSq <= radiusSq then
                            if damageEntity then
                                damageEntity(target, puffDamage, entity, { x = puff.x, y = puff.y })
                            end
                        end
                    end
                end
            end
        end
    end
end

return {
    update = function(entity, weapon, dt, context)
        -- Call base update to spawn puffs
        base_cloud.update(entity, weapon, dt, context)
        
        -- Update existing puffs and apply damage
        local world = context.world
        if world then
            update_puffs(weapon, world, entity, dt, context.damageEntity)
        end
    end,
    
    onFireRequested = base_cloud.onFireRequested,
}
