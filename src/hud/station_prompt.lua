-- Station Interaction Prompt
-- Displays a prompt when the player is within station influence range

local theme = require("src.ui.theme")

---@diagnostic disable-next-line: undefined-global
local love = love

local StationPrompt = {}

local set_color = theme.utils.set_color

--- Gets the station name from the station entity
---@param station table The station entity
---@return string The station name
local function get_station_name(station)
    if not station then
        return "Station"
    end
    
    if station.name then
        return station.name
    end
    
    if station.stationName then
        return station.stationName
    end
    
    return "Station"
end

--- Draws the station interaction prompt
---@param context table The game context
---@param player table The player entity
function StationPrompt.draw(context, player)
    if not (context and player) then
        return
    end
    
    -- Check if player is near a station
    local station = context.stationDockTarget
    if not station then
        return
    end
    
    -- Don't show if station window is already open
    if context.stationUI and context.stationUI.visible then
        return
    end
    
    -- Don't show if any UI is visible
    local UIStateManager = require("src.ui.state_manager")
    if UIStateManager.isAnyUIVisible(context) then
        return
    end
    
    local fonts = (theme.get_fonts and theme.get_fonts()) or theme.fonts or {}
    local defaultFont = fonts.body or fonts.small or love.graphics.getFont()
    if not defaultFont then
        return
    end
    local vw = love.graphics.getWidth()
    local vh = love.graphics.getHeight()
    
    -- Position at bottom center of screen
    local promptY = vh - 120
    local promptX = vw / 2
    
    -- Draw background panel
    local panelWidth = 280
    local panelHeight = 70
    local panelX = promptX - panelWidth / 2
    local panelY = promptY - panelHeight / 2
    
    -- Background with transparency
    set_color({ 0.05, 0.06, 0.09, 0.85 })
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)
    
    -- Border
    set_color({ 0.2, 0.4, 0.7, 0.6 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX + 1, panelY + 1, panelWidth - 2, panelHeight - 2, 6, 6)
    
    -- Station name
    love.graphics.setFont(fonts.small_bold or fonts.small or defaultFont)
    set_color({ 0.7, 0.85, 1.0, 1.0 })
    local stationName = get_station_name(station)
    local nameWidth = (fonts.small_bold or fonts.small or fonts.body):getWidth(stationName)
    love.graphics.print(stationName, promptX - nameWidth / 2, panelY + 12)
    
    -- Interaction prompt
    love.graphics.setFont(defaultFont)
    set_color({ 0.85, 0.9, 1.0, 1.0 })
    
    local promptText = "Press [E] to dock"
    local promptWidth = defaultFont:getWidth(promptText)
    love.graphics.print(promptText, promptX - promptWidth / 2, panelY + 38)
    
    -- Subtle glow effect on the key indicator
    local keyText = "[E]"
    local keyX = promptX - promptWidth / 2 + defaultFont:getWidth("Press ")
    local keyY = panelY + 38
    local keyWidth = defaultFont:getWidth(keyText)
    
    -- Animated pulse effect
    local time = love.timer.getTime()
    local pulse = 0.5 + 0.5 * math.sin(time * 3)
    
    set_color({ 0.4, 0.7, 1.0, 0.3 * pulse })
    love.graphics.rectangle("fill", keyX - 2, keyY - 2, keyWidth + 4, defaultFont:getHeight() + 4, 3, 3)
end

return StationPrompt
