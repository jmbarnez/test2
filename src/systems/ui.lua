local tiny = require("libs.tiny")
local constants = require("src.constants.game")
---@diagnostic disable-next-line: undefined-global
local love = love

local cargo_colors = {
    shadow = { 0, 0, 0, 0.5 },
    background = { 0.15, 0.15, 0.15, 0.95 },
    border = { 0.3, 0.3, 0.3, 1 },
    topBar = { 0.1, 0.1, 0.1, 1 },
    bottomBar = { 0.1, 0.1, 0.1, 1 },
    titleText = { 0.9, 0.9, 0.9, 1 },
    text = { 0.85, 0.85, 0.85, 1 },
    muted = { 0.6, 0.6, 0.6, 1 },
    rowAlt = { 0.18, 0.18, 0.18, 0.8 },
    rowHover = { 0.25, 0.25, 0.35, 0.6 },
    progressBg = { 0.2, 0.2, 0.2, 1 },
    progressFill = { 0.3, 0.7, 0.3, 1 },
    warning = { 0.8, 0.3, 0.3, 1 },
    accent = { 0.4, 0.6, 0.9, 1 },
    button = { 0.2, 0.2, 0.2, 1 },
    buttonHover = { 0.3, 0.3, 0.3, 1 },
    iconBg = { 0.25, 0.25, 0.25, 1 },
    iconBorder = { 0.4, 0.4, 0.4, 1 },
    slotBg = { 0.2, 0.2, 0.2, 1 },
    slotBorder = { 0.35, 0.35, 0.35, 1 },
    closeButton = { 0.7, 0.7, 0.7, 1 },
    closeButtonHover = { 0.9, 0.4, 0.4, 1 },
}

local function ensure_cargo_fonts(ui)
    if ui.fonts then
        return ui.fonts
    end

    local fontPath = constants.render and constants.render.fonts and constants.render.fonts.primary

    local function loadFont(size)
        if fontPath then
            local ok, font = pcall(love.graphics.newFont, fontPath, size)
            if ok and font then
                return font
            end
        end
        return love.graphics.newFont(size)
    end

    ui.fonts = {
        title = loadFont(18),
        body = loadFont(14),
        small = loadFont(12),
        tiny = loadFont(10),
    }
    return ui.fonts
end

local function draw_cargo_window(context)
    local ui = context.cargoUI
    if not (ui and ui.visible) then
        return
    end

    local player = context.player
    local cargo = player and player.cargo
    if cargo and cargo.refresh then
        cargo:refresh()
    end

    local items = (cargo and cargo.items) or {}
    local capacity = cargo and cargo.capacity or 0
    local used = cargo and cargo.used or 0
    local available = cargo and cargo.available or math.max(0, capacity - used)
    local usagePct = 0
    if capacity > 0 then
        usagePct = math.max(0, math.min(used / capacity, 1))
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local margin = 40
    local padding = 20
    local topBarHeight = 32
    local bottomBarHeight = 24
    local slotSize = 64
    local slotPadding = 8
    local textHeight = 20

    -- Calculate grid dimensions
    local windowWidth = math.min(800, screenWidth - margin * 2)
    local windowHeight = math.min(600, screenHeight - margin * 2)
    
    local contentWidth = windowWidth - padding * 2
    local slotsPerRow = math.floor((contentWidth + slotPadding) / (slotSize + slotPadding))
    local gridHeight = windowHeight - topBarHeight - bottomBarHeight - padding * 3 - 60 -- space for progress bar
    local slotsPerColumn = math.floor((gridHeight + slotPadding) / (slotSize + textHeight + slotPadding))
    local totalSlots = slotsPerRow * slotsPerColumn

    local panelX = (screenWidth - windowWidth) * 0.5
    local panelY = (screenHeight - windowHeight) * 0.5
    panelX = math.max(margin, math.min(panelX, screenWidth - windowWidth - margin))
    panelY = math.max(margin, math.min(panelY, screenHeight - windowHeight - margin))

    love.graphics.push("all")
    love.graphics.origin()

    -- Drop shadow
    love.graphics.setColor(cargo_colors.shadow)
    love.graphics.rectangle("fill", panelX + 3, panelY + 3, windowWidth, windowHeight, 2, 2)

    -- Main window background
    love.graphics.setColor(cargo_colors.background)
    love.graphics.rectangle("fill", panelX, panelY, windowWidth, windowHeight, 2, 2)

    -- Window border
    love.graphics.setColor(cargo_colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 0.5, panelY + 0.5, windowWidth - 1, windowHeight - 1, 2, 2)

    -- Top bar
    love.graphics.setColor(cargo_colors.topBar)
    love.graphics.rectangle("fill", panelX + 1, panelY + 1, windowWidth - 2, topBarHeight, 2, 2)
    
    -- Top bar border
    love.graphics.setColor(cargo_colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 1, panelY + topBarHeight + 0.5, panelX + windowWidth - 1, panelY + topBarHeight + 0.5)

    local fonts = ensure_cargo_fonts(ui)
    local previousFont = love.graphics.getFont()

    -- Title text
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(cargo_colors.titleText)
    local titleTextY = panelY + (topBarHeight - fonts.title:getHeight()) * 0.5
    love.graphics.print("CARGO", panelX + padding, titleTextY)

    -- Close button (X)
    local closeButtonSize = 16
    local closeButtonX = panelX + windowWidth - padding - closeButtonSize
    local closeButtonY = panelY + (topBarHeight - closeButtonSize) * 0.5
    
    love.graphics.setColor(cargo_colors.closeButton)
    love.graphics.setLineWidth(2)
    love.graphics.line(closeButtonX, closeButtonY, closeButtonX + closeButtonSize, closeButtonY + closeButtonSize)
    love.graphics.line(closeButtonX, closeButtonY + closeButtonSize, closeButtonX + closeButtonSize, closeButtonY)

    -- Content area
    local contentY = panelY + topBarHeight + padding

    -- Capacity info
    love.graphics.setFont(fonts.body)
    if capacity > 0 then
        love.graphics.setColor(cargo_colors.text)
        love.graphics.print(string.format("%.0f / %.0f units", used, capacity), panelX + padding, contentY)
        love.graphics.setColor(cargo_colors.muted)
        love.graphics.print(string.format("%.0f%% full", usagePct * 100), panelX + padding + 150, contentY)
    else
        love.graphics.setColor(cargo_colors.warning)
        love.graphics.print("No cargo bay", panelX + padding, contentY)
    end

    -- Progress bar
    local barWidth = windowWidth - padding * 2
    local barHeight = 6
    local barY = contentY + 25
    love.graphics.setColor(cargo_colors.progressBg)
    love.graphics.rectangle("fill", panelX + padding, barY, barWidth, barHeight, 1, 1)
    if usagePct > 0 then
        love.graphics.setColor(cargo_colors.progressFill)
        love.graphics.rectangle("fill", panelX + padding, barY, barWidth * usagePct, barHeight, 1, 1)
    end

    -- Items grid
    local gridStartY = barY + barHeight + 20
    local gridStartX = panelX + padding

    -- Draw only items that exist
    for i, item in ipairs(items) do
        if i > totalSlots then break end
        
        local slotIndex = i - 1
        local row = math.floor(slotIndex / slotsPerRow)
        local col = slotIndex % slotsPerRow
        local slotX = gridStartX + col * (slotSize + slotPadding)
        local slotY = gridStartY + row * (slotSize + textHeight + slotPadding)
        
        -- Draw item background
        love.graphics.setColor(cargo_colors.iconBg)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 2, 2)
        
        -- Draw item border
        love.graphics.setColor(cargo_colors.iconBorder)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", slotX + 0.5, slotY + 0.5, slotSize - 1, slotSize - 1, 2, 2)
        
        -- Draw item icon symbol
        local iconSize = slotSize - 8
        local iconX = slotX + 4
        local iconY = slotY + 4
        
        love.graphics.setColor(cargo_colors.accent)
        love.graphics.setLineWidth(2)
        local centerX = iconX + iconSize * 0.5
        local centerY = iconY + iconSize * 0.5
        love.graphics.circle("line", centerX, centerY, iconSize * 0.25)
        love.graphics.rectangle("fill", centerX - 1, centerY - 6, 2, 12)
        love.graphics.rectangle("fill", centerX - 6, centerY - 1, 12, 2)
        
        -- Draw quantity badge
        if item.quantity and item.quantity > 1 then
            local badgeSize = 14
            local badgeX = slotX + slotSize - badgeSize - 2
            local badgeY = slotY + 2
            love.graphics.setColor(cargo_colors.accent)
            love.graphics.circle("fill", badgeX + badgeSize * 0.5, badgeY + badgeSize * 0.5, badgeSize * 0.5)
            love.graphics.setFont(fonts.tiny)
            love.graphics.setColor(cargo_colors.titleText)
            local qtyText = tostring(item.quantity)
            local textWidth = fonts.tiny:getWidth(qtyText)
            love.graphics.print(qtyText, badgeX + (badgeSize - textWidth) * 0.5, badgeY + 1)
        end
        
        -- Draw item name
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(cargo_colors.text)
        local itemName = item.name or item.id or "Unknown"
        local nameWidth = fonts.small:getWidth(itemName)
        if nameWidth > slotSize then
            itemName = string.sub(itemName, 1, 8) .. "..."
            nameWidth = fonts.small:getWidth(itemName)
        end
        local nameX = slotX + (slotSize - nameWidth) * 0.5
        local nameY = slotY + slotSize + 2
        love.graphics.print(itemName, nameX, nameY)
    end

    -- Bottom bar
    local bottomBarY = panelY + windowHeight - bottomBarHeight - 1
    love.graphics.setColor(cargo_colors.bottomBar)
    love.graphics.rectangle("fill", panelX + 1, bottomBarY, windowWidth - 2, bottomBarHeight, 2, 2)
    
    -- Bottom bar border
    love.graphics.setColor(cargo_colors.border)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 1, bottomBarY - 0.5, panelX + windowWidth - 1, bottomBarY - 0.5)

    -- Show total items count if there are more than visible slots
    if #items > totalSlots then
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(cargo_colors.muted)
        local overflowText = string.format("%d of %d items", math.min(totalSlots, #items), #items)
        local textY = bottomBarY + (bottomBarHeight - fonts.small:getHeight()) * 0.5
        love.graphics.print(overflowText, panelX + padding, textY)
    end

    love.graphics.setFont(previousFont)
    love.graphics.pop()
end

return function(context)
    return tiny.system {
        draw = function()
            draw_cargo_window(context)
        end,
    }
end
