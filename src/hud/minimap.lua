local theme = require("src.ui.theme")
local hud_colors = theme.colors.hud

---@diagnostic disable-next-line: undefined-global
local love = love

local Minimap = {}

function Minimap.draw(context, player)
    local screenWidth = love.graphics.getWidth()
    local minimap_diameter = 120
    local minimap_radius_pixels = minimap_diameter * 0.5
    local margin = 24
    local centerX = screenWidth - minimap_radius_pixels - margin
    local centerY = margin + minimap_radius_pixels

    local world = context.world
    local bounds = context.worldBounds

    if not (world and player and bounds and player.position) then
        return
    end

    local visible_radius_world = 4000
    local scale = minimap_radius_pixels / visible_radius_world

    love.graphics.setColor(hud_colors.minimap_background)
    love.graphics.circle("fill", centerX, centerY, minimap_radius_pixels)

    love.graphics.setColor(hud_colors.minimap_border)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", centerX, centerY, minimap_radius_pixels)

    love.graphics.setColor(hud_colors.minimap_player)
    love.graphics.circle("fill", centerX, centerY, 3)

    local entities = world.entities or {}
    for i = 1, #entities do
        local entity = entities[i]
        if entity ~= player and entity.position then
            local relX = entity.position.x - player.position.x
            local relY = entity.position.y - player.position.y
            local distance_sq = relX * relX + relY * relY

            if distance_sq <= visible_radius_world * visible_radius_world then
                local mapX = centerX + relX * scale
                local mapY = centerY + relY * scale

                local dx = mapX - centerX
                local dy = mapY - centerY

                if (dx * dx + dy * dy) <= (minimap_radius_pixels - 1) * (minimap_radius_pixels - 1) then
                    if entity.player then
                        love.graphics.setColor(hud_colors.minimap_teammate)
                        love.graphics.circle("fill", mapX, mapY, 2.5)
                    elseif entity.blueprint and entity.blueprint.category == "asteroids" then
                        love.graphics.setColor(hud_colors.minimap_asteroid)
                        love.graphics.circle("fill", mapX, mapY, 1.5)
                    elseif entity.blueprint and entity.blueprint.category == "ships" then
                        love.graphics.setColor(hud_colors.minimap_ship)
                        love.graphics.circle("fill", mapX, mapY, 2)
                    end
                end
            end
        end
    end
end

return Minimap
