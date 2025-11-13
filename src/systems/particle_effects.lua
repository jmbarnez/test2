-- Particle Effects Rendering System
-- Draws particle effects (impact sparks, explosions, etc.) on top of entities
-- This system should be added AFTER the main render system to ensure particles
-- appear in front of ships, stations, and other game objects

local tiny = require("libs.tiny")
local explosion_renderer = require("src.renderers.explosion")

---@diagnostic disable-next-line: undefined-global
local love = love
local lg = love.graphics

return function(context)
    -- Get reference to projectile system for its particles
    local projectileSystem = context and context.projectileSystem
    local weaponFireSystem = context and context.weaponFireSystem
    
    return tiny.system {
        draw = function(self)
            -- Draw projectile impact particles
            if projectileSystem then
                local impactParticles = projectileSystem.impactParticles
                if impactParticles and #impactParticles > 0 then
                    lg.push("all")
                    lg.setBlendMode("add")
                    
                    for i = 1, #impactParticles do
                        local p = impactParticles[i]
                        local alpha = p.color and p.color[4]
                        if alpha and alpha > 0 and p.size and p.size > 0 then
                            lg.setColor(p.color)
                            lg.setPointSize(math.max(1, p.size))
                            lg.points(p.x, p.y)
                        end
                    end
                    
                    lg.pop()
                end

                local explosions = projectileSystem.explosions
                if explosions and #explosions > 0 then
                    explosion_renderer.draw(explosions)
                end
            end
            
            -- Draw laser beam impact sparks
            if weaponFireSystem then
                local beamImpacts = weaponFireSystem.beamImpacts
                if beamImpacts and #beamImpacts > 0 then
                    lg.push("all")
                    
                    for i = 1, #beamImpacts do
                        local spark = beamImpacts[i]
                        lg.setColor(spark.color)
                        lg.circle("fill", spark.x, spark.y, spark.size)
                    end
                    
                    lg.pop()
                end
            end
        end,
    }
end
