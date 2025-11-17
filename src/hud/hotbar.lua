local theme = require("src.ui.theme")
local PlayerWeapons = require("src.player.weapons")
local ItemIconRenderer = require("src.util.item_icon_renderer")

---@diagnostic disable-next-line: undefined-global
local love = love

local Hotbar = {}

local window_colors = theme.colors.window
local theme_spacing = theme.spacing
local set_color = theme.utils.set_color
local HOTBAR_SLOTS = 10
local SELECTED_OUTLINE_COLOR = { 0.2, 0.85, 0.95, 1 }

local function draw_item_icon(icon, x, y, size)
    return ItemIconRenderer.drawAt(icon, x, y, size, {
        set_color = set_color,
        fallbackRadius = 0.35,
    })
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
    local baseSlotSize = (theme_spacing and theme_spacing.slot_size) or 48
    local slotSize = math.max(36, math.floor(baseSlotSize * 0.9))
    local padding = 6
    local gap = 5

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
    local y = screenHeight - barHeight - 16

    -- Background
    set_color(window_colors.shadow or { 0, 0, 0, 0.4 })
    love.graphics.rectangle("fill", x, y + 2, barWidth, barHeight, 4, 4)
    set_color(window_colors.background or { 0.02, 0.02, 0.04, 0.9 })
    love.graphics.rectangle("fill", x, y, barWidth, barHeight, 4, 4)

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

    local uiInput = context.uiInput
    local allowInteraction = not (uiInput and uiInput.mouseCaptured)

    local mouseX, mouseY
    if allowInteraction and love.mouse and love.mouse.getPosition then
        mouseX, mouseY = love.mouse.getPosition()
    end
    local hotbarState
    if type(state) == "table" then
        state.hotbarUI = state.hotbarUI or {}
        hotbarState = state.hotbarUI
    else
        Hotbar._fallbackState = Hotbar._fallbackState or {}
        hotbarState = Hotbar._fallbackState
    end

    local isMouseDown = false
    if allowInteraction and love.mouse and love.mouse.isDown then
        isMouseDown = love.mouse.isDown(1) or false
    end

    local wasMouseDown = hotbarState and hotbarState.wasMouseDown or false
    local justPressed = allowInteraction and isMouseDown and not wasMouseDown

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
                if allowInteraction and uiInput and (isMouseDown or justPressed) then
                    uiInput.mouseCaptured = true
                end
            end
        end

        if allowInteraction and justPressed and isHovered and i <= total then
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
        hotbarState.wasMouseDown = allowInteraction and isMouseDown or false
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
