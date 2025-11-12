-- Particle Effects Rendering System
-- Draws particle effects (impact sparks, explosions, etc.) on top of entities
-- This system should be added AFTER the main render system to ensure particles
-- appear in front of ships, stations, and other game objects

local tiny = require("libs.tiny")

---@diagnostic disable-next-line: undefined-global
local love = love
local lg = love.graphics

return function(context)
    -- Get reference to projectile system for its particles
    local projectileSystem = context and context.projectileSystem
    
    return tiny.system {
        draw = function(self)
            if not projectileSystem then
                return
            end
            
            -- Draw projectile impact particles
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
        end,
    }
end
