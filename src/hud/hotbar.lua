local theme = require("src.ui.theme")
local PlayerWeapons = require("src.player.weapons")

---@diagnostic disable-next-line: undefined-global
local love = love

local Hotbar = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color
local HOTBAR_SLOTS = 10
local SELECTED_OUTLINE_COLOR = { 0.2, 0.85, 0.95, 1 }

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

function Hotbar.draw(context, player)
    if not player then return end

    context = context or {}
    local state = context.state or context

    local slots = PlayerWeapons.getSlots(player, { refresh = true })
    if not (slots and slots.list and #slots.list > 0) then return end

    local total = #slots.list
    local selectedIndex = slots.selectedIndex or 1
    if selectedIndex < 1 or selectedIndex > total then
        selectedIndex = 1
    end

    local fonts = theme.get_fonts()
    local selectedEntry = slots.list[selectedIndex]
    local selectedWeaponInstance = selectedEntry and selectedEntry.weaponInstance
    local selectedWeaponComponent = (selectedWeaponInstance and selectedWeaponInstance.weapon) or player.weapon
    if type(selectedWeaponComponent) ~= "table" then
        selectedWeaponComponent = nil
    end

    local cooldownFractions = {}
    local maxVisible = math.min(total, HOTBAR_SLOTS)

    for i = 1, maxVisible do
        local entry = slots.list[i]
        local weaponInstance = entry.weaponInstance
        local weaponComponent = weaponInstance and weaponInstance.weapon

        if i == selectedIndex and not weaponComponent and selectedWeaponComponent then
            weaponComponent = selectedWeaponComponent
        end

        local fraction = 0
        local hasCooldown = false
        local fireRate = weaponComponent and weaponComponent.fireRate
        if weaponComponent and type(fireRate) == "number" and fireRate > 0 then
            local remaining = math.max(weaponComponent.cooldown or 0, 0)
            fraction = math.min(remaining / fireRate, 1)
            hasCooldown = true
        end

        cooldownFractions[i] = {
            value = fraction,
            has = hasCooldown,
        }
    end

    local name = nil
    if selectedEntry then
        name = selectedEntry.name or (selectedEntry.blueprintId and selectedEntry.blueprintId:gsub("_", " ")) or "Weapon"
    end

    local slotsForLayout = HOTBAR_SLOTS
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local slotSize = (theme_spacing and theme_spacing.slot_size) or 48
    local padding = 8
    local gap = 6

    local barWidth = slotsForLayout * slotSize + (slotsForLayout - 1) * gap + padding * 2
    local titleHeight = 0
    if fonts.body and name then
        titleHeight = fonts.body:getHeight() + padding
        local nameWidth = fonts.body:getWidth(name)
        if barWidth < nameWidth + padding * 2 then
            barWidth = nameWidth + padding * 2
        end
    end

    local barHeight = slotSize + padding * 2 + titleHeight
    local x = (screenWidth - barWidth) * 0.5
    local y = screenHeight - barHeight - 20

    -- Background
    set_color(window_colors.shadow or { 0, 0, 0, 0.4 })
    love.graphics.rectangle("fill", x, y + 2, barWidth, barHeight, 4, 4)
    set_color(window_colors.background or { 0.02, 0.02, 0.04, 0.9 })
    love.graphics.rectangle("fill", x, y, barWidth, barHeight, 4, 4)

    local statusBarHeight = math.max(16, math.floor(slotSize * 0.35))
    local statusBarGap = 6
    local statusBarY = y - statusBarGap - statusBarHeight

    set_color(window_colors.shadow or { 0, 0, 0, 0.35 })
    love.graphics.rectangle("fill", x, statusBarY + 2, barWidth, statusBarHeight, 4, 4)
    set_color(window_colors.surface or window_colors.background or { 0.05, 0.07, 0.10, 0.95 })
    love.graphics.rectangle("fill", x, statusBarY, barWidth, statusBarHeight, 4, 4)

    local statusEffects = (player and player.statusEffects) or (player and player.status_effects)
    if type(statusEffects) == "table" and next(statusEffects) ~= nil then
        local icons = {}
        local count = 0
        for _, effect in pairs(statusEffects) do
            count = count + 1
            icons[count] = effect
            if count >= 8 then
                break
            end
        end

        if count > 0 then
            local iconSize = math.min(statusBarHeight - 8, slotSize * 0.5)
            local totalWidth = count * iconSize + (count - 1) * 4
            local startX = x + (barWidth - totalWidth) * 0.5
            local iconY = statusBarY + (statusBarHeight - iconSize) * 0.5

            for i = 1, count do
                local effect = icons[i]
                local iconX = startX + (i - 1) * (iconSize + 4)
                set_color(window_colors.surface_subtle or { 0.03, 0.04, 0.07, 0.9 })
                love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 3, 3)

                local icon = effect.icon
                if icon then
                    draw_item_icon(icon, iconX + 2, iconY + 2, iconSize - 4)
                end
            end
        end
    end

    local contentY = y + padding

    -- Text
    if fonts.body and name then
        local textX = x + padding
        love.graphics.setFont(fonts.body)
        set_color(window_colors.text or { 0.8, 0.8, 0.85, 1 })
        love.graphics.print(name, textX, contentY)
        contentY = contentY + fonts.body:getHeight() + padding * 0.5
    end

    local slotStartX = x + padding
    local slotY = contentY

    local selectedDisplayIndex = math.min(selectedIndex, HOTBAR_SLOTS)

    local mouseX, mouseY
    if love.mouse and love.mouse.getPosition then
        mouseX, mouseY = love.mouse.getPosition()
    end

    local uiInput = context.uiInput
    local hotbarState
    if type(state) == "table" then
        state.hotbarUI = state.hotbarUI or {}
        hotbarState = state.hotbarUI
    else
        Hotbar._fallbackState = Hotbar._fallbackState or {}
        hotbarState = Hotbar._fallbackState
    end

    local isMouseDown = false
    if love.mouse and love.mouse.isDown then
        isMouseDown = love.mouse.isDown(1) or false
    end

    local wasMouseDown = hotbarState and hotbarState.wasMouseDown or false
    local justPressed = isMouseDown and not wasMouseDown

    local hoveredIndex = nil

    -- Icon
    for i = 1, HOTBAR_SLOTS do
        local entry = slots.list[i]
        local slotX = slotStartX + (i - 1) * (slotSize + gap)

        local isHovered = false
        if mouseX and mouseY then
            isHovered = mouseX >= slotX and mouseX <= slotX + slotSize and mouseY >= slotY and mouseY <= slotY + slotSize
            if isHovered then
                hoveredIndex = i
                if uiInput and (isMouseDown or justPressed) then
                    uiInput.mouseCaptured = true
                end
            end
        end

        if justPressed and isHovered and i <= total then
            local selectedResult = PlayerWeapons.selectByIndex(player, i, { skipRefresh = true })
            if selectedResult then
                selectedIndex = i
                selectedEntry = selectedResult
                selectedWeaponInstance = selectedResult.weaponInstance
                selectedWeaponComponent = (selectedWeaponInstance and selectedWeaponInstance.weapon) or player.weapon
                selectedDisplayIndex = math.min(selectedIndex, HOTBAR_SLOTS)
            end
        end

        local isSelected = (i == selectedDisplayIndex)
        if isSelected then
            set_color(window_colors.surface or window_colors.background or { 0.05, 0.07, 0.10, 0.95 })
        else
            set_color(window_colors.surface_subtle or { 0.03, 0.04, 0.07, 0.9 })
        end
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 3, 3)

        if isSelected then
            love.graphics.push("all")
            set_color(SELECTED_OUTLINE_COLOR)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slotX + 1, slotY + 1, slotSize - 2, slotSize - 2, 3, 3)
            love.graphics.pop()
        end

        if entry then
            local iconDrawn = draw_item_icon(entry.icon, slotX + 4, slotY + 4, slotSize - 8)

            if not iconDrawn then
                set_color(window_colors.muted or { 0.5, 0.5, 0.55, 0.7 })
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", slotX + slotSize * 0.5, slotY + slotSize * 0.5, slotSize * 0.3)
            end

            local cd = cooldownFractions[i]
            if cd and cd.has and cd.value and cd.value > 0 then
                local barPadding = 4
                local barWidth = slotSize - barPadding * 2
                local barHeight = 5
                local barX = slotX + barPadding
                local barY = slotY + slotSize - barPadding - barHeight

                love.graphics.push("all")
                set_color(window_colors.progress_background or window_colors.surface_subtle or { 0.08, 0.09, 0.12, 0.9 })
                love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
                set_color(window_colors.progress_fill or window_colors.accent or { 0.3, 0.6, 0.8, 1 })
                love.graphics.rectangle("fill", barX, barY, barWidth * cd.value, barHeight)
                set_color(window_colors.border or { 0.22, 0.28, 0.36, 0.88 })
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
                love.graphics.pop()
            end
        end

        if fonts.small then
            love.graphics.setFont(fonts.small)
            if entry then
                if isSelected then
                    set_color(window_colors.accent or { 0.3, 0.6, 0.8, 1 })
                else
                    set_color(window_colors.muted or { 0.6, 0.6, 0.65, 1 })
                end
            else
                set_color(window_colors.surface_subtle or { 0.25, 0.25, 0.3, 0.8 })
            end

            local label
            if i == 10 then
                label = "0"
            else
                label = tostring(i)
            end
            love.graphics.print(label, slotX + 4, slotY + slotSize - fonts.small:getHeight() - 2)
        end
    end

    if fonts.small then
        love.graphics.setFont(fonts.small)
        set_color(window_colors.muted or { 0.6, 0.6, 0.65, 1 })

        local countText = string.format("%d/%d", selectedIndex, total)
        local countWidth = fonts.small:getWidth(countText)
        local countX = x + barWidth - padding - countWidth
        local countY = y + padding
        love.graphics.print(countText, countX, countY)
    end

    if hotbarState then
        hotbarState.wasMouseDown = isMouseDown
    end

    if hoveredIndex and hoveredIndex >= 1 and hoveredIndex <= total and state and not state.hudTooltipRequest then
        local entry = slots.list[hoveredIndex]
        local item = entry and entry.item
        if item then
            local heading = item.name or entry.name or (entry.blueprintId and entry.blueprintId:gsub("_", " ")) or "Weapon"
            local body = {}

            local item_type = item.type or "weapon"
            body[#body + 1] = string.format("Type: %s", tostring(item_type))

            if item.installed ~= nil then
                body[#body + 1] = string.format("Installed: %s", item.installed and "Yes" or "No")
            end

            if entry.blueprintId then
                body[#body + 1] = string.format("Blueprint: %s", entry.blueprintId)
            end

            state.hudTooltipRequest = {
                heading = heading,
                body = body,
                description = item.description,
            }
        end
    end
end

return Hotbar
