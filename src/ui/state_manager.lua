local UIStateManager = {}

local core = require("src.ui.state.core")
local factories = require("src.ui.state.factories")
local Events = require("src.ui.state.events")
local Visibility = require("src.ui.state.visibility")
local Quests = require("src.ui.state.quests")

---@diagnostic disable-next-line: undefined-global
local love = love

-- Import core helpers
local resolve_state_pair = core.resolve_state_pair
local set_state_field = core.set_state_field
local any_modal_visible = core.any_modal_visible
local capture_input = core.capture_input
local release_input = core.release_input
local create_visibility_handlers = core.create_visibility_handlers

-- Import factory functions
local createCargoUIState = factories.createCargoUIState
local createDebugUIState = factories.createDebugUIState
local createSkillsUIState = factories.createSkillsUIState
local createStationUIState = factories.createStationUIState
local createDeathUIState = factories.createDeathUIState
local createPauseUIState = factories.createPauseUIState
local createOptionsUIState = factories.createOptionsUIState
local createMapUIState = factories.createMapUIState
local reset_window_geometry = factories.resetWindowGeometry

function UIStateManager.handleWheelMoved(state, x, y)
    return Events.handleWheelMoved(UIStateManager, state, x, y)
end

function UIStateManager.handleKeyPressed(state, key, scancode, isrepeat)
    return Events.handleKeyPressed(UIStateManager, state, key, scancode, isrepeat)
end

function UIStateManager.handleTextInput(state, text)
    return Events.handleTextInput(UIStateManager, state, text)
end

function UIStateManager.handleMousePressed(state, x, y, button, istouch, presses)
    return Events.handleMousePressed(UIStateManager, state, x, y, button, istouch, presses)
end

function UIStateManager.handleMouseReleased(state, x, y, button, istouch, presses)
    return Events.handleMouseReleased(UIStateManager, state, x, y, button, istouch, presses)
end

function UIStateManager.toggleFullscreen(state)
    return Events.toggleFullscreen(state)
end

-- ============================================================================
-- Quest Management (Delegated)
-- ============================================================================

function UIStateManager.refreshStationQuests(state)
    Quests.refresh(state)
end

-- ============================================================================
-- Visibility Management (Delegated)
-- ============================================================================

function UIStateManager.showCargoUI(state)
    Visibility.showCargoUI(state)
end

function UIStateManager.hideCargoUI(state)
    Visibility.hideCargoUI(state)
end

function UIStateManager.toggleCargoUI(state)
    Visibility.toggleCargoUI(state)
end

function UIStateManager.isCargoUIVisible(state)
    return Visibility.isCargoUIVisible(state)
end

function UIStateManager.initialize(state)
    local resolved, proxy = resolve_state_pair(state)
    if not resolved then
        return
    end

    state = resolved

    -- Initialize UI states
    state.cargoUI = state.cargoUI or createCargoUIState()
    state.deathUI = state.deathUI or createDeathUIState()
    state.pauseUI = state.pauseUI or createPauseUIState()
    state.optionsUI = state.optionsUI or createOptionsUIState()
    state.mapUI = state.mapUI or createMapUIState()
    state.skillsUI = state.skillsUI or createSkillsUIState()
    state.debugUI = state.debugUI or createDebugUIState()
    state.stationUI = state.stationUI or createStationUIState()
    
    -- Initialize input state
    state.uiInput = state.uiInput or {
        mouseCaptured = false,
        keyboardCaptured = false,
    }
    
    -- Initialize respawn state
    if state.respawnRequested == nil then
        state.respawnRequested = false
    end

    set_state_field(state, proxy, "isPaused", state.pauseUI and state.pauseUI.visible or false)
end

function UIStateManager.cleanup(state)
    local resolved, proxy = resolve_state_pair(state)
    if not resolved then
        return
    end

    state = resolved

    state.cargoUI = nil
    state.deathUI = nil
    state.pauseUI = nil
    state.optionsUI = nil
    state.mapUI = nil
    state.skillsUI = nil
    state.debugUI = nil
    state.stationUI = nil
    state.uiInput = nil
    state.respawnRequested = nil
    set_state_field(state, proxy, "isPaused", nil)
end

function UIStateManager.showDeathUI(state)
    Visibility.showDeathUI(state)
end

function UIStateManager.hideDeathUI(state)
    Visibility.hideDeathUI(state)
end

function UIStateManager.isDeathUIVisible(state)
    return Visibility.isDeathUIVisible(state)
end

function UIStateManager.showPauseUI(state)
    Visibility.showPauseUI(state)
end

function UIStateManager.hidePauseUI(state)
    Visibility.hidePauseUI(state)
end

function UIStateManager.togglePauseUI(state)
    Visibility.togglePauseUI(state)
end

function UIStateManager.isPauseUIVisible(state)
    return Visibility.isPauseUIVisible(state)
end

function UIStateManager.isPaused(state)
    return Visibility.isPaused(state)
end

function UIStateManager.showOptionsUI(state, source)
    Visibility.showOptionsUI(state, source)
end

function UIStateManager.hideOptionsUI(state)
    Visibility.hideOptionsUI(state)
end

function UIStateManager.isOptionsUIVisible(state)
    return Visibility.isOptionsUIVisible(state)
end

function UIStateManager.showMapUI(state)
    Visibility.showMapUI(state)
end

function UIStateManager.hideMapUI(state)
    Visibility.hideMapUI(state)
end

function UIStateManager.toggleMapUI(state)
    Visibility.toggleMapUI(state)
end

function UIStateManager.isMapUIVisible(state)
    return Visibility.isMapUIVisible(state)
end

function UIStateManager.showSkillsUI(state)
    Visibility.showSkillsUI(state)
end

function UIStateManager.hideSkillsUI(state)
    Visibility.hideSkillsUI(state)
end

function UIStateManager.toggleSkillsUI(state)
    Visibility.toggleSkillsUI(state)
end

function UIStateManager.isSkillsUIVisible(state)
    return Visibility.isSkillsUIVisible(state)
end

function UIStateManager.showDebugUI(state)
    Visibility.showDebugUI(state)
end

function UIStateManager.hideDebugUI(state)
    Visibility.hideDebugUI(state)
end

function UIStateManager.toggleDebugUI(state)
    Visibility.toggleDebugUI(state)
end

function UIStateManager.isDebugUIVisible(state)
    return Visibility.isDebugUIVisible(state)
end

function UIStateManager.showStationUI(state)
    Visibility.showStationUI(state)
end

function UIStateManager.hideStationUI(state)
    Visibility.hideStationUI(state)
end

function UIStateManager.toggleStationUI(state)
    Visibility.toggleStationUI(state)
end

function UIStateManager.isStationUIVisible(state)
    return Visibility.isStationUIVisible(state)
end

function UIStateManager.isAnyUIVisible(state)
    return Visibility.isAnyUIVisible(state)
end

function UIStateManager.requestRespawn(state)
    local resolved, proxy = resolve_state_pair(state)
    if not resolved then
        return
    end

    set_state_field(resolved, proxy, "respawnRequested", true)
end

function UIStateManager.isRespawnRequested(state)
    state = resolve_state_pair(state)
    return state and state.respawnRequested
end

function UIStateManager.clearRespawnRequest(state)
    local resolved, proxy = resolve_state_pair(state)
    if resolved then
        set_state_field(resolved, proxy, "respawnRequested", false)
    end
end

function UIStateManager.onResize(state, width, height)
    local resolved = resolve_state_pair(state)
    if not resolved then
        return
    end

    state = resolved

    reset_window_geometry(state.cargoUI)
    reset_window_geometry(state.pauseUI)
    reset_window_geometry(state.optionsUI)
    reset_window_geometry(state.skillsUI)
    reset_window_geometry(state.deathUI)
    reset_window_geometry(state.debugUI)
    reset_window_geometry(state.stationUI)

    if type(state.mapUI) == "table" then
        reset_window_geometry(state.mapUI)
        state.mapUI.mapDragging = false
        state.mapUI._just_opened = true
    end

    if type(state.debugUI) == "table" then
        state.debugUI._contentRect = nil
    end

    if type(state.uiInput) == "table" then
        release_input(state, true)
    end

    state._viewport = state._viewport or {}
    state._viewport.width = width or (love.graphics and love.graphics.getWidth()) or state._viewport.width
    state._viewport.height = height or (love.graphics and love.graphics.getHeight()) or state._viewport.height

    if type(state.updateCamera) == "function" then
        state:updateCamera()
    end
end

return UIStateManager
