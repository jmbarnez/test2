local tiny = require("libs.tiny")
---@diagnostic disable-next-line: undefined-global
local love = love

local function draw_player_health(player)
    local top_margin = 20
    local bar_width = 200
    local bar_height = 12
    local label_padding = 6
    local x = 20

    local health = player and player.health
    if not (health and health.max and health.max > 0) then
        return top_margin + bar_height + label_padding
    end

    local current = math.max(0, health.current or 0)
    local max_value = math.max(1, health.max)
    local pct = math.max(0, math.min(1, current / max_value))

    -- Black border
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, top_margin, bar_width, bar_height)

    -- Health fill
    if pct > 0 then
        love.graphics.setColor(0.2, 0.8, 0.4, 0.95)
        love.graphics.rectangle("fill", x + 1, top_margin + 1, (bar_width - 2) * pct, bar_height - 2)
    end

    return top_margin + bar_height + label_padding
end

local function draw_minimap(context)
    local screenWidth = love.graphics.getWidth()
    local minimap_size = 120
    local margin = 20
    local x = screenWidth - minimap_size - margin
    local y = margin

    -- Minimap background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, minimap_size, minimap_size)
    
    -- Minimap border
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, minimap_size, minimap_size)

    local world = context.world
    local player = context.player
    local bounds = context.worldBounds

    if not (world and player and bounds and player.position) then
        return
    end

    local centerX = x + minimap_size / 2
    local centerY = y + minimap_size / 2
    local scale = (minimap_size * 0.8) / math.max(bounds.width, bounds.height)

    -- Draw player first (larger dot)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.circle("fill", centerX, centerY, 3)

    -- Draw other entities relative to player
    local entities = world.entities or {}
    for i = 1, #entities do
        local entity = entities[i]
        if entity ~= player and entity.position then
            local relX = entity.position.x - player.position.x
            local relY = entity.position.y - player.position.y
            local mapX = centerX + relX * scale
            local mapY = centerY + relY * scale
            
            -- Only draw if within minimap bounds
            if mapX >= x and mapX <= x + minimap_size and mapY >= y and mapY <= y + minimap_size then
                if entity.blueprint and entity.blueprint.category == "asteroids" then
                    love.graphics.setColor(0.6, 0.5, 0.4, 0.8)
                    love.graphics.circle("fill", mapX, mapY, 1.5)
                elseif entity.blueprint and entity.blueprint.category == "ships" then
                    love.graphics.setColor(1, 0.3, 0.3, 1)
                    love.graphics.circle("fill", mapX, mapY, 2)
                end
            end
        end
    end
end

local function draw_speed_fps(context)
    local screenWidth = love.graphics.getWidth()
    local minimap_size = 120
    local margin = 20
    local x = screenWidth - minimap_size - margin
    local y = margin + minimap_size + 10

    local player = context.player
    local speed = 0
    if player and player.body then
        local vx, vy = player.body:getLinearVelocity()
        speed = math.sqrt(vx * vx + vy * vy)
    end

    local fps = love.timer.getFPS()

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(love.graphics.getFont())
    love.graphics.print(string.format("Speed: %.1f", speed), x, y)
    love.graphics.print(string.format("FPS: %d", fps), x, y + 15)
end

return function(context)
    return tiny.system {
        draw = function()
            local player = context.player

            love.graphics.push("all")
            love.graphics.origin()

            draw_player_health(player)
            draw_minimap(context)
            draw_speed_fps(context)

            love.graphics.pop()
        end,
    }
end
