local tiny = require("libs.tiny")
local theme = require("src.ui.theme")
local vector = require("src.util.vector")
local PlayerManager = require("src.player.manager")
local PlayerWeapons = require("src.player.weapons")
---@diagnostic disable-next-line: undefined-global
local love = love

local window_colors = theme.colors.window
local hud_colors = theme.colors.hud
local theme_spacing = theme.spacing

local function set_color(color)
    if type(color) == "table" then
        love.graphics.setColor(
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            color[4] or 1
        )
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function draw_icon_layer(icon, layer, size)
    love.graphics.push()

    local color = layer.color or icon.detail or icon.color or icon.accent
    set_color(color)

    local offsetX = (layer.offsetX or 0) * size
    local offsetY = (layer.offsetY or 0) * size
    love.graphics.translate(offsetX, offsetY)

    if layer.rotation then
        love.graphics.rotate(layer.rotation)
    end

    local shape = layer.shape or "circle"
    local halfSize = size * 0.5

    if shape == "circle" then
        local radius = (layer.radius or 0.5) * halfSize
        love.graphics.circle("fill", 0, 0, radius)
    elseif shape == "ring" then
        local radius = (layer.radius or 0.5) * halfSize
        local thickness = (layer.thickness or 0.1) * halfSize
        love.graphics.setLineWidth(thickness)
        love.graphics.circle("line", 0, 0, radius)
    elseif shape == "rectangle" then
        local width = (layer.width or 0.6) * size
        local height = (layer.height or 0.2) * size
        love.graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height)
    elseif shape == "rounded_rect" then
        local width = (layer.width or 0.6) * size
        local height = (layer.height or 0.2) * size
        local radius = (layer.radius or 0.1) * size
        love.graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height, radius, radius)
    elseif shape == "triangle" then
        local width = (layer.width or 0.5) * size
        local height = (layer.height or 0.5) * size
        local direction = layer.direction or "up"
        local halfWidth = width * 0.5
        if direction == "up" then
            love.graphics.polygon("fill", 0, -height * 0.5, halfWidth, height * 0.5, -halfWidth, height * 0.5)
        else
            love.graphics.polygon("fill", 0, height * 0.5, halfWidth, -height * 0.5, -halfWidth, -height * 0.5)
        end
    elseif shape == "beam" then
        local width = (layer.width or 0.2) * size
        local length = (layer.length or 0.8) * size
        love.graphics.rectangle("fill", -length * 0.5, -width * 0.5, length, width)
    else
        local radius = (layer.radius or 0.4) * halfSize
        love.graphics.circle("fill", 0, 0, radius)
    end

    love.graphics.pop()
end

local function draw_item_icon(icon, x, y, size)
    if type(icon) ~= "table" then
        return false
    end

    local layers = icon.layers
    if type(layers) ~= "table" or #layers == 0 then
        local baseColor = icon.color or icon.detail or icon.accent
        set_color(baseColor)
        local radius = size * 0.35
        love.graphics.circle("fill", x + size * 0.5, y + size * 0.5, radius)
        return true
    end

    love.graphics.push("all")
    love.graphics.translate(x + size * 0.5, y + size * 0.5)

    for i = 1, #layers do
        local layer = layers[i]
        if type(layer) == "table" then
            draw_icon_layer(icon, layer, size)
        end
    end

    love.graphics.pop()
    return true
end

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
    love.graphics.setColor(hud_colors.health_border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, top_margin, bar_width, bar_height)

    -- Health fill
    if pct > 0 then
        love.graphics.setColor(hud_colors.health_fill)
        love.graphics.rectangle("fill", x + 1, top_margin + 1, (bar_width - 2) * pct, bar_height - 2)
    end

    return top_margin + bar_height + label_padding
end

local function draw_minimap(context, player)
    local screenWidth = love.graphics.getWidth()
    local minimap_size = 120
    local margin = 20
    local x = screenWidth - minimap_size - margin
    local y = margin

    -- Minimap background
    love.graphics.setColor(hud_colors.minimap_background)
    love.graphics.rectangle("fill", x, y, minimap_size, minimap_size)
    
    -- Minimap border
    love.graphics.setColor(hud_colors.minimap_border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, minimap_size, minimap_size)

    local world = context.world
    local bounds = context.worldBounds

    if not (world and player and bounds and player.position) then
        return
    end

    local centerX = x + minimap_size / 2
    local centerY = y + minimap_size / 2
    local scale = (minimap_size * 0.8) / math.max(bounds.width, bounds.height)

    -- Draw player first (larger dot)
    love.graphics.setColor(hud_colors.minimap_player)
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

local function draw_speed_fps(context, player)
    local screenWidth = love.graphics.getWidth()
    local minimap_size = 120
    local margin = 20
    local x = screenWidth - minimap_size - margin
    local y = margin + minimap_size + 10

    local speed = 0
    if player and player.body then
        local vx, vy = player.body:getLinearVelocity()
        speed = vector.length(vx, vy)
    end

    local fps = love.timer.getFPS()

    love.graphics.setColor(hud_colors.diagnostics)
    love.graphics.setFont(love.graphics.getFont())
    love.graphics.print(string.format("Speed: %.1f", speed), x, y)
    love.graphics.print(string.format("FPS: %d", fps), x, y + 15)
end

local function draw_weapon_slot(context, player)
    if not player then
        return
    end

    local slots = PlayerWeapons.getSlots(player, { refresh = true })
    if not (slots and slots.list and #slots.list > 0) then
        return
    end

    local index = slots.selectedIndex or 1
    if index < 1 or index > #slots.list then
        index = 1
    end

    local entry = slots.list[index]
    if not entry then
        return
    end

    local total = #slots.list
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local slotSize = (theme_spacing and theme_spacing.slot_size) or 56
    local panelPadding = 12
    local textGap = 16

    local fonts = theme.get_fonts()
    local name = entry.name or (entry.blueprintId and entry.blueprintId:gsub("_", " ")) or "Weapon"
    local countText = string.format("%d / %d", index, total)
    local hintText = "Q / E to swap"

    local textWidth = 0
    if fonts.body and name then
        textWidth = math.max(textWidth, fonts.body:getWidth(name))
    end
    if fonts.small then
        textWidth = math.max(textWidth, fonts.small:getWidth(countText))
    end

    local hintFont = fonts.tiny or fonts.small
    if hintFont then
        textWidth = math.max(textWidth, hintFont:getWidth(hintText))
    end

    local panelWidth = math.max(panelPadding * 2 + slotSize + textGap + textWidth, slotSize + 210)
    local panelHeight = slotSize + 40
    local x = (screenWidth - panelWidth) * 0.5
    local y = screenHeight - panelHeight - 28

    set_color(window_colors.shadow or { 0, 0, 0, 0.6 })
    love.graphics.rectangle("fill", x, y + 4, panelWidth, panelHeight, 8, 8)

    set_color(window_colors.background or { 0.02, 0.02, 0.04, 0.95 })
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight, 8, 8)

    set_color(window_colors.border or { 0.08, 0.08, 0.12, 0.9 })
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, panelWidth - 1, panelHeight - 1, 8, 8)

    local iconX = x + panelPadding
    local iconY = y + panelPadding
    local iconDrawn = draw_item_icon(entry.icon, iconX, iconY, slotSize)

    if not iconDrawn then
        set_color(window_colors.muted or { 0.5, 0.5, 0.55, 0.9 })
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", iconX + slotSize * 0.5, iconY + slotSize * 0.5, slotSize * 0.3)
    end

    set_color(window_colors.accent or { 0.2, 0.5, 0.7, 1 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", iconX - 2, iconY - 2, slotSize + 4, slotSize + 4, 6, 6)

    love.graphics.setFont(fonts.body)
    set_color(window_colors.text or { 0.75, 0.75, 0.8, 1 })
    love.graphics.print(name, iconX + slotSize + textGap, iconY)

    love.graphics.setFont(fonts.small)
    set_color(window_colors.muted or { 0.5, 0.5, 0.55, 1 })
    love.graphics.print(countText, iconX + slotSize + textGap, iconY + 24)

    love.graphics.setFont(fonts.tiny or fonts.small)
    love.graphics.print(hintText, iconX + slotSize + textGap, iconY + slotSize - 10)

    if total > 1 then
        local indicatorSpacing = 12
        local indicatorY = y + panelHeight - 12
        local totalWidth = indicatorSpacing * (total - 1)
        local startX = x + (panelWidth - totalWidth) * 0.5

        for i = 1, total do
            if i == index then
                set_color(window_colors.accent or { 0.2, 0.5, 0.7, 1 })
            else
                set_color(window_colors.muted or { 0.5, 0.5, 0.55, 0.6 })
            end
            love.graphics.circle("fill", startX + (i - 1) * indicatorSpacing, indicatorY, 3.5)
        end
    end
end

return function(context)
    return tiny.system {
        draw = function()
            local player = PlayerManager.resolveLocalPlayer(context)

            love.graphics.push("all")
            love.graphics.origin()

            draw_player_health(player)
            draw_minimap(context, player)
            draw_speed_fps(context, player)
            draw_weapon_slot(context, player)

            love.graphics.pop()
        end,
    }
end

