-- Keybindings: Hotkey configuration UI and key binding management
-- Handles rebinding keys, displaying current bindings, and static hotkey info

local theme = require("src.ui.theme")

---@diagnostic disable-next-line: undefined-global
local love = love

local Keybindings = {}

-- Actions that can be rebound
local BINDING_ACTIONS = {
    { id = "moveLeft", label = "Move Left" },
    { id = "moveRight", label = "Move Right" },
    { id = "moveUp", label = "Move Up" },
    { id = "moveDown", label = "Move Down" },
    { id = "cycleWeaponPrev", label = "Cycle Weapon (Previous)" },
    { id = "cycleWeaponNext", label = "Cycle Weapon (Next)" },
    { id = "toggleCargo", label = "Toggle Cargo" },
    { id = "toggleMap", label = "Toggle Map" },
    { id = "toggleSkills", label = "Toggle Skills" },
    { id = "pause", label = "Pause / Back" },
}

-- Static hotkeys (not rebindable)
local STATIC_HOTKEYS = {
    { key = "F11", description = "Enable Fullscreen" },
}

--- Gets the binding text for display
---@param binding table|nil The binding keys array
---@return string The formatted binding text
local function get_binding_text(binding)
    if not binding or #binding == 0 then
        return "Unassigned"
    end
    return table.concat(binding, ", ")
end

--- Checks if a point is inside a rectangle
---@param x number Point X
---@param y number Point Y
---@param rect table Rectangle {x, y, w, h}
---@return boolean Whether the point is inside
local function point_in_rect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

--- Renders the keybinding configuration section
---@param params table {fonts, settings, state, viewportX, viewportY, cursorY, columnWidth, mouseX, mouseY, bindingButtons}
---@return number The updated cursorY position
function Keybindings.render(params)
    local fonts = params.fonts
    local settings = params.settings
    local state = params.state
    local viewportX = params.viewportX
    local viewportY = params.viewportY
    local cursorY = params.cursorY
    local columnWidth = params.columnWidth
    local mouseX = params.mouseX
    local mouseY = params.mouseY
    local bindingButtons = params.bindingButtons

    local windowColors = theme.colors.window or {}
    local headingColor = windowColors.title_text or { 0.9, 0.92, 0.96, 1 }
    local textColor = windowColors.text or { 0.85, 0.85, 0.9, 1 }

    -- Heading
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(headingColor)
    love.graphics.print("Hotkey Configuration", viewportX, viewportY + cursorY)
    cursorY = cursorY + fonts.title:getHeight() + 12

    -- Awaiting bind prompt
    if state.awaitingBindAction and state.awaitingBindActionLabel then
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(windowColors.accent or { 0.2, 0.55, 0.95, 1 })
        local prompt = string.format("Press a key for %s (Backspace to clear, Esc to cancel)", state.awaitingBindActionLabel)
        love.graphics.printf(prompt, viewportX, viewportY + cursorY, columnWidth, "left")
        love.graphics.setColor(textColor)
        cursorY = cursorY + fonts.small:getHeight() + 12
    end

    -- Binding actions
    local bindingButtonWidth = 110
    for _, action in ipairs(BINDING_ACTIONS) do
        local labelY = cursorY
        local bindings = settings.keybindings[action.id]
        local bindingText = get_binding_text(bindings)
        local isAwaiting = state.awaitingBindAction == action.id

        love.graphics.setFont(fonts.body)
        love.graphics.setColor(isAwaiting and (windowColors.accent or { 0.2, 0.55, 0.95, 1 }) or textColor)
        love.graphics.print(action.label, viewportX, viewportY + labelY)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(windowColors.muted or { 0.5, 0.55, 0.6, 1 })
        love.graphics.print(bindingText, viewportX + 220, viewportY + labelY + 4)

        local rect = {
            x = viewportX + columnWidth - bindingButtonWidth,
            y = viewportY + labelY - 2,
            w = bindingButtonWidth,
            h = 28,
            action = action,
        }

        local hovered = point_in_rect(mouseX, mouseY, rect)
        love.graphics.setColor(hovered and (windowColors.button_hover or { 0.18, 0.24, 0.32, 1 }) or (windowColors.button or { 0.12, 0.16, 0.22, 1 }))
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 5, 5)

        love.graphics.setColor(windowColors.border or { 0.12, 0.18, 0.28, 0.9 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1, 5, 5)

        love.graphics.setFont(fonts.small)
        love.graphics.setColor(windowColors.title_text or textColor)
        love.graphics.printf(isAwaiting and "Press..." or "Rebind", rect.x, rect.y + (rect.h - fonts.small:getHeight()) * 0.5, rect.w, "center")

        bindingButtons[#bindingButtons + 1] = rect

        cursorY = cursorY + fonts.body:getHeight() + 18
    end

    -- Static hotkeys section
    if #STATIC_HOTKEYS > 0 then
        cursorY = cursorY + 4
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(windowColors.muted or { 0.5, 0.55, 0.6, 1 })
        love.graphics.print("Additional Hotkeys", viewportX, viewportY + cursorY)
        love.graphics.setColor(textColor)
        cursorY = cursorY + fonts.small:getHeight() + 6

        local keyColumnWidth = 80
        local rowSpacing = 12
        for _, entry in ipairs(STATIC_HOTKEYS) do
            love.graphics.setFont(fonts.body)
            love.graphics.setColor(windowColors.title_text or textColor)
            love.graphics.print(entry.key, viewportX, viewportY + cursorY)

            love.graphics.setColor(textColor)
            love.graphics.print(entry.description, viewportX + keyColumnWidth, viewportY + cursorY)
            cursorY = cursorY + fonts.body:getHeight() + rowSpacing
        end
    end

    return cursorY
end

--- Handles mouse interaction for keybinding buttons
---@param state table The options UI state
---@param mouseX number Mouse X position
---@param mouseY number Mouse Y position
---@param justPressed boolean Whether mouse was just pressed
---@return boolean Whether anything was handled
function Keybindings.handleInteraction(state, mouseX, mouseY, justPressed)
    if not (justPressed and state._bindingButtons) then
        return false
    end

    for _, rect in ipairs(state._bindingButtons) do
        if point_in_rect(mouseX, mouseY, rect) then
            state.awaitingBindAction = rect.action.id
            state.awaitingBindActionLabel = rect.action.label
            return true
        end
    end

    return false
end

--- Handles keypresses for binding configuration
---@param state table The options UI state
---@param settings table The settings table
---@param key string The key that was pressed
---@return boolean Whether the key was handled
function Keybindings.handleKeypress(state, settings, key)
    if not state.awaitingBindAction then
        return false
    end

    if key == "escape" then
        state.awaitingBindAction = nil
        state.awaitingBindActionLabel = nil
        return true
    end

    settings.keybindings[state.awaitingBindAction] = {}
    if key ~= "backspace" then
        settings.keybindings[state.awaitingBindAction][1] = key
    end

    state.awaitingBindAction = nil
    state.awaitingBindActionLabel = nil
    return true
end

--- Gets the binding actions list
---@return table The binding actions
function Keybindings.getActions()
    return BINDING_ACTIONS
end

--- Gets the static hotkeys list
---@return table The static hotkeys
function Keybindings.getStaticHotkeys()
    return STATIC_HOTKEYS
end

return Keybindings
