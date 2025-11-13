local theme = require("src.ui.theme")
local PlayerWeapons = require("src.player.weapons")

---@diagnostic disable-next-line: undefined-global
local love = love

local WeaponPanel = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color

local function draw_icon_layer(icon, layer, size)
    love.graphics.push()
    set_color(layer.color or icon.detail or icon.color or icon.accent)
    
    local offsetX = (layer.offsetX or 0) * size
    local offsetY = (layer.offsetY or 0) * size
    love.graphics.translate(offsetX, offsetY)
    
    if layer.rotation then love.graphics.rotate(layer.rotation) end
    
    local shape = layer.shape or "circle"
    local halfSize = size * 0.5
    
    if shape == "circle" then
        love.graphics.circle("fill", 0, 0, (layer.radius or 0.5) * halfSize)
    elseif shape == "ring" then
        local radius = (layer.radius or 0.5) * halfSize
        love.graphics.setLineWidth((layer.thickness or 0.1) * halfSize)
        love.graphics.circle("line", 0, 0, radius)
    elseif shape == "rectangle" then
        local width, height = (layer.width or 0.6) * size, (layer.height or 0.2) * size
        love.graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height)
    elseif shape == "rounded_rect" then
        local width, height = (layer.width or 0.6) * size, (layer.height or 0.2) * size
        local radius = (layer.radius or 0.1) * size
        love.graphics.rectangle("fill", -width * 0.5, -height * 0.5, width, height, radius, radius)
    elseif shape == "triangle" then
        local width, height = (layer.width or 0.5) * size, (layer.height or 0.5) * size
        local halfWidth = width * 0.5
        if (layer.direction or "up") == "up" then
            love.graphics.polygon("fill", 0, -height * 0.5, halfWidth, height * 0.5, -halfWidth, height * 0.5)
        else
            love.graphics.polygon("fill", 0, height * 0.5, halfWidth, -height * 0.5, -halfWidth, -height * 0.5)
        end
    elseif shape == "beam" then
        local width, length = (layer.width or 0.2) * size, (layer.length or 0.8) * size
        love.graphics.rectangle("fill", -length * 0.5, -width * 0.5, length, width)
    else
        love.graphics.circle("fill", 0, 0, (layer.radius or 0.4) * halfSize)
    end
    
    love.graphics.pop()
end

local function draw_item_icon(icon, x, y, size)
    if type(icon) ~= "table" then return false end
    
    local layers = icon.layers
    if type(layers) ~= "table" or #layers == 0 then
        set_color(icon.color or icon.detail or icon.accent)
        love.graphics.circle("fill", x + size * 0.5, y + size * 0.5, size * 0.35)
        return true
    end
    
    love.graphics.push("all")
    love.graphics.translate(x + size * 0.5, y + size * 0.5)
    
    for i = 1, #layers do
        if type(layers[i]) == "table" then
            draw_icon_layer(icon, layers[i], size)
        end
    end
    
    love.graphics.pop()
    return true
end

function WeaponPanel.draw(context, player)
    if not player then return end
    
    local slots = PlayerWeapons.getSlots(player, { refresh = true })
    if not (slots and slots.list and #slots.list > 0) then return end
    
    local index = math.max(1, math.min(slots.selectedIndex or 1, #slots.list))
    local entry = slots.list[index]
    if not entry then return end
    
    local total = #slots.list
    local weaponInstance = entry.weaponInstance
    local weaponComponent = (weaponInstance and weaponInstance.weapon) or player.weapon
    if type(weaponComponent) ~= "table" then
        weaponComponent = nil
    end

    local cooldownFraction = 0
    local hasCooldown = false
    local fireRate = weaponComponent and weaponComponent.fireRate
    if weaponComponent and type(fireRate) == "number" and fireRate > 0 then
        local remaining = math.max(weaponComponent.cooldown or 0, 0)
        cooldownFraction = math.min(remaining / fireRate, 1)
        hasCooldown = true
    end

    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local slotSize = (theme_spacing and theme_spacing.slot_size) or 48
    local padding = 8
    
    local fonts = theme.get_fonts()
    local name = entry.name or (entry.blueprintId and entry.blueprintId:gsub("_", " ")) or "Weapon"
    local countText = string.format("%d/%d", index, total)
    
    local swapText = nil
    if total > 1 then
        swapText = "[C] Prev   [V] Next"
    end

    local textWidth = 0
    if fonts.body then textWidth = math.max(textWidth, fonts.body:getWidth(name)) end
    if fonts.small then
        textWidth = math.max(textWidth, fonts.small:getWidth(countText))
        if swapText then
            textWidth = math.max(textWidth, fonts.small:getWidth(swapText))
        end
    end
    
    local panelWidth = math.max(slotSize + textWidth + padding * 3, 180)
    local panelHeight = slotSize + padding * 2
    local x = (screenWidth - panelWidth) * 0.5
    local y = screenHeight - panelHeight - 20
    
    -- Background
    set_color(window_colors.shadow or { 0, 0, 0, 0.4 })
    love.graphics.rectangle("fill", x, y + 2, panelWidth, panelHeight, 4, 4)
    set_color(window_colors.background or { 0.02, 0.02, 0.04, 0.9 })
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight, 4, 4)
    
    -- Icon
    local iconX, iconY = x + padding, y + padding
    local iconDrawn = draw_item_icon(entry.icon, iconX, iconY, slotSize)
    
    if not iconDrawn then
        set_color(window_colors.muted or { 0.5, 0.5, 0.55, 0.7 })
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", iconX + slotSize * 0.5, iconY + slotSize * 0.5, slotSize * 0.3)
    end
    
    -- Text
    local textX = iconX + slotSize + padding
    if fonts.body then love.graphics.setFont(fonts.body) end
    set_color(window_colors.text or { 0.8, 0.8, 0.85, 1 })
    love.graphics.print(name, textX, iconY + 2)


    if hasCooldown then
        local barX = textX
        local barY = iconY + 28
        local barWidth = math.max(panelWidth - (barX - x) - padding, 0)
        local barHeight = 6
        if barWidth > 0 then
            love.graphics.push("all")
            set_color(window_colors.progress_background or window_colors.surface_subtle or { 0.08, 0.09, 0.12, 0.9 })
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            if cooldownFraction > 0 then
                set_color(window_colors.progress_fill or window_colors.accent or { 0.3, 0.6, 0.8, 1 })
                love.graphics.rectangle("fill", barX, barY, barWidth * cooldownFraction, barHeight)
            end
            set_color(window_colors.border or { 0.22, 0.28, 0.36, 0.88 })
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
            love.graphics.pop()
        end
    end

    love.graphics.setFont(fonts.small)
    set_color(window_colors.muted or { 0.6, 0.6, 0.65, 1 })
    if swapText then
        love.graphics.print(swapText, textX, iconY + slotSize - 30)
    end
    love.graphics.print(countText, textX, iconY + slotSize - 16)
    
    -- Indicators
    if total > 1 then
        local indicatorY = y + panelHeight + 6
        local spacing = 8
        local totalWidth = spacing * (total - 1)
        local startX = x + (panelWidth - totalWidth) * 0.5
        
        for i = 1, total do
            set_color(i == index and (window_colors.accent or { 0.3, 0.6, 0.8, 1 }) or { 0.4, 0.4, 0.45, 0.5 })
            love.graphics.circle("fill", startX + (i - 1) * spacing, indicatorY, 2)
        end
    end
end

return WeaponPanel
