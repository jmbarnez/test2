local UIStateManager = {}

local window = require("src.ui.components.window")
local dropdown = require("src.ui.components.dropdown")

---@diagnostic disable-next-line: undefined-global
local love = love

-- Create default UI state configurations
local function createCargoUIState()
    return {
        visible = false,
        dragging = false,
    }
end

local function createDebugUIState()
    return {
        visible = false,
        dragging = false,
        width = nil,
        height = nil,
        x = nil,
        y = nil,
        _was_mouse_down = false,
        _just_opened = false,
        scrollOffset = 0,
        _contentRect = nil,
    }
end

local function createSkillsUIState()
    return {
        visible = false,
        dragging = false,
        _was_mouse_down = false,
    }
end

local function any_modal_visible(state)
    return (state.pauseUI and state.pauseUI.visible)
        or (state.deathUI and state.deathUI.visible)
        or (state.cargoUI and state.cargoUI.visible)
        or (state.optionsUI and state.optionsUI.visible)
        or (state.mapUI and state.mapUI.visible)
        or (state.skillsUI and state.skillsUI.visible)
end

local function createDeathUIState()
    return {
        visible = false,
        title = "Ship Destroyed",
        message = "Your ship has been destroyed. Respawn to re-enter the fight.",
        buttonLabel = "Respawn",
        hint = "Press Enter to respawn",
        buttonHovered = false,
        _was_mouse_down = false,
    }
end

local function createPauseUIState()
    return {
        visible = false,
        title = "Paused",
        message = "Take a breather while the galaxy waits.",
        hint = "Press Esc or Enter to resume",
        buttonLabel = "Resume",
        buttonHovered = false,
        _was_mouse_down = false,
    }
end

local function createOptionsUIState()
    return {
        visible = false,
        title = "Options",
        message = "Adjust the experience to your liking.",
        returnTo = nil,
        _was_mouse_down = false,
        syncPending = false,
        resolutionDropdown = dropdown.create_state and dropdown.create_state() or nil,
        fpsDropdown = dropdown.create_state and dropdown.create_state() or nil,
    }
end

local function createMapUIState()
    return {
        visible = false,
        zoom = 1,
        min_zoom = 0.35,
        max_zoom = 6,
        centerX = nil,
        centerY = nil,
        dragging = false,
        _was_mouse_down = false,
        _just_opened = false,
    }
end

local function reset_window_geometry(windowState)
    if type(windowState) ~= "table" then
        return
    end

    windowState.x = nil
    windowState.y = nil
    windowState.width = nil
    windowState.height = nil
    windowState.dragging = false
    if windowState.resolutionDropdown and windowState.resolutionDropdown.open then
        windowState.resolutionDropdown.open = false
    end
    if windowState.fpsDropdown and windowState.fpsDropdown.open then
        windowState.fpsDropdown.open = false
    end
end

local function hash_string(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 33 + str:byte(i)) % 4294967296
    end
    return hash
end

local function hsv_to_rgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    
    if i == 0 then return { v, t, p, 1 } end
    if i == 1 then return { q, v, p, 1 } end
    if i == 2 then return { p, v, t, 1 } end
    if i == 3 then return { p, q, v, 1 } end
    if i == 4 then return { t, p, v, 1 } end
    return { v, p, q, 1 }
end

local function generatePlayerColor(playerId)
    local key = tostring(playerId or "unknown")
    local hash = hash_string(key)

    local golden_ratio_conjugate = 0.61803398875
    local hue = (hash / 4294967296 + golden_ratio_conjugate) % 1
    local sat = math.min(0.75 + ((hash % 97) / 96) * 0.2, 1)
    local value = math.min(0.88 + ((hash % 53) / 52) * 0.12, 1)

    return hsv_to_rgb(hue, sat, value)
end

function UIStateManager.initialize(state)
    if not state then
        return
    end

    -- Initialize UI states
    state.cargoUI = state.cargoUI or createCargoUIState()
    state.deathUI = state.deathUI or createDeathUIState()
    state.pauseUI = state.pauseUI or createPauseUIState()
    state.optionsUI = state.optionsUI or createOptionsUIState()
    state.mapUI = state.mapUI or createMapUIState()
    state.skillsUI = state.skillsUI or createSkillsUIState()
    state.debugUI = state.debugUI or createDebugUIState()
    
    -- Initialize input state
    state.uiInput = state.uiInput or {
        mouseCaptured = false,
        keyboardCaptured = false,
    }
    
    -- Initialize respawn state
    if state.respawnRequested == nil then
        state.respawnRequested = false
    end

    state.isPaused = state.pauseUI.visible
end

function UIStateManager.cleanup(state)
    if not state then
        return
    end

    state.cargoUI = nil
    state.deathUI = nil
    state.pauseUI = nil
    state.optionsUI = nil
    state.mapUI = nil
    state.skillsUI = nil
    state.debugUI = nil
    state.uiInput = nil
    state.respawnRequested = nil
    state.isPaused = nil
end

function UIStateManager.showDeathUI(state)
    if not (state and state.deathUI) then
        return
    end

    local deathUI = state.deathUI
    deathUI.visible = true
    deathUI.buttonHovered = false
    deathUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

    if UIStateManager.isPauseUIVisible(state) then
        UIStateManager.hidePauseUI(state)
    end

    if state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end
end

function UIStateManager.hideDeathUI(state)
    if not (state and state.deathUI) then
        return
    end

    local deathUI = state.deathUI
    deathUI.visible = false
    deathUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

    if state.uiInput then
        state.uiInput.mouseCaptured = false
        state.uiInput.keyboardCaptured = false
    end
end

function UIStateManager.toggleCargoUI(state)
    if not (state and state.cargoUI) then
        return
    end

    state.cargoUI.visible = not state.cargoUI.visible
end

local function setSkillsVisibility(state, visible)
    if not (state and state.skillsUI) then
        return
    end

    local skillsUI = state.skillsUI
    if skillsUI.visible == visible then
        return
    end

    skillsUI.visible = visible
    skillsUI.dragging = false

    if not visible then
        skillsUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    end

    if state.uiInput then
        if visible then
            state.uiInput.mouseCaptured = true
            state.uiInput.keyboardCaptured = true
        else
            local keepCaptured = any_modal_visible(state)
            state.uiInput.mouseCaptured = not not keepCaptured
            state.uiInput.keyboardCaptured = not not keepCaptured
        end
    end
end

function UIStateManager.showSkillsUI(state)
    setSkillsVisibility(state, true)
end

function UIStateManager.hideSkillsUI(state)
    setSkillsVisibility(state, false)
end

function UIStateManager.toggleSkillsUI(state)
    if not (state and state.skillsUI) then
        return
    end

    setSkillsVisibility(state, not state.skillsUI.visible)
end

function UIStateManager.isSkillsUIVisible(state)
    return state and state.skillsUI and state.skillsUI.visible
end

local function setPauseVisibility(state, visible)
    if not (state and state.pauseUI) then
        return
    end

    local pauseUI = state.pauseUI

    if visible and UIStateManager.isDeathUIVisible(state) then
        state.isPaused = pauseUI.visible
        return
    end

    if pauseUI.visible == visible then
        state.isPaused = pauseUI.visible
        return
    end

    pauseUI.visible = visible
    pauseUI.buttonHovered = false
    pauseUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

    if state.uiInput then
        state.uiInput.mouseCaptured = visible
        state.uiInput.keyboardCaptured = visible
    end

    state.isPaused = visible
end

function UIStateManager.showPauseUI(state)
    setPauseVisibility(state, true)
end

function UIStateManager.hidePauseUI(state)
    setPauseVisibility(state, false)
end

function UIStateManager.togglePauseUI(state)
    if not (state and state.pauseUI) then
        return
    end

    setPauseVisibility(state, not state.pauseUI.visible)
end

local function setMapVisibility(state, visible)
    if not (state and state.mapUI) then
        return
    end

    local mapUI = state.mapUI
    if mapUI.visible == visible then
        return
    end

    mapUI.visible = visible
    mapUI.dragging = false
    mapUI._just_opened = visible

    if not visible then
        mapUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    end

    if state.uiInput then
        state.uiInput.mouseCaptured = visible
        state.uiInput.keyboardCaptured = visible
    end
end

function UIStateManager.showMapUI(state)
    setMapVisibility(state, true)
end

function UIStateManager.hideMapUI(state)
    setMapVisibility(state, false)
end

function UIStateManager.toggleMapUI(state)
    if not (state and state.mapUI) then
        return
    end

    setMapVisibility(state, not state.mapUI.visible)
end

function UIStateManager.isPauseUIVisible(state)
    return state and state.pauseUI and state.pauseUI.visible
end

function UIStateManager.showOptionsUI(state, source)
    if not (state and state.optionsUI) then
        return
    end

    local optionsUI = state.optionsUI
    optionsUI.visible = true
    optionsUI.returnTo = source
    optionsUI.syncPending = true
    optionsUI.activeSlider = nil
    optionsUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

    if source == "pause" and state.pauseUI and state.pauseUI.visible then
        state.pauseUI.visible = false
    end

    if state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end

    state.isPaused = true
end

function UIStateManager.hideOptionsUI(state)
    if not (state and state.optionsUI) then
        return
    end

    local optionsUI = state.optionsUI
    local returnTo = optionsUI.returnTo
    optionsUI.visible = false
    optionsUI.dragging = false
    optionsUI.activeSlider = nil
    optionsUI.syncPending = false
    optionsUI.returnTo = nil

    if returnTo == "pause" then
        UIStateManager.showPauseUI(state)
    end

    if state.uiInput then
        local keepCaptured = any_modal_visible(state)
        state.uiInput.mouseCaptured = not not keepCaptured
        state.uiInput.keyboardCaptured = not not keepCaptured
    end

    if not any_modal_visible(state) then
        state.isPaused = false
    end
end

function UIStateManager.isOptionsUIVisible(state)
    return state and state.optionsUI and state.optionsUI.visible
end

function UIStateManager.isMapUIVisible(state)
    return state and state.mapUI and state.mapUI.visible
end

function UIStateManager.isPaused(state)
    return state and state.isPaused == true
end

function UIStateManager.isAnyUIVisible(state)
    return any_modal_visible(state)
end

local function setDebugVisibility(state, visible)
    if not (state and state.debugUI) then
        return
    end

    local debugUI = state.debugUI

    if debugUI.visible == visible then
        return
    end

    debugUI.visible = visible
    debugUI.dragging = false

    if state.uiInput then
        if visible then
            state.uiInput.mouseCaptured = true
            state.uiInput.keyboardCaptured = true
        else
            local keepCaptured = any_modal_visible(state)
            state.uiInput.mouseCaptured = not not keepCaptured
            state.uiInput.keyboardCaptured = not not keepCaptured
        end
    end
end

function UIStateManager.toggleDebugUI(state)
    if not (state and state.debugUI) then
        return
    end

    setDebugVisibility(state, not state.debugUI.visible)
end

function UIStateManager.showDebugUI(state)
    setDebugVisibility(state, true)
end

function UIStateManager.hideDebugUI(state)
    setDebugVisibility(state, false)
end

function UIStateManager.isDebugUIVisible(state)
    return state and state.debugUI and state.debugUI.visible
end

function UIStateManager.isDeathUIVisible(state)
    return state and state.deathUI and state.deathUI.visible
end

function UIStateManager.isCargoUIVisible(state)
    return state and state.cargoUI and state.cargoUI.visible
end

function UIStateManager.requestRespawn(state)
    if not state then
        return
    end

    state.respawnRequested = true
end

function UIStateManager.isRespawnRequested(state)
    return state and state.respawnRequested
end

function UIStateManager.clearRespawnRequest(state)
    if state then
        state.respawnRequested = false
    end
end

function UIStateManager.onResize(state, width, height)
    if not state then
        return
    end

    reset_window_geometry(state.cargoUI)
    reset_window_geometry(state.pauseUI)
    reset_window_geometry(state.optionsUI)
    reset_window_geometry(state.skillsUI)
    reset_window_geometry(state.deathUI)
    reset_window_geometry(state.debugUI)

    if type(state.mapUI) == "table" then
        reset_window_geometry(state.mapUI)
        state.mapUI.mapDragging = false
        state.mapUI._just_opened = true
    end

    if type(state.debugUI) == "table" then
        state.debugUI._contentRect = nil
    end

    if type(state.uiInput) == "table" then
        state.uiInput.mouseCaptured = false
        state.uiInput.keyboardCaptured = false
    end

    state._viewport = state._viewport or {}
    state._viewport.width = width or (love.graphics and love.graphics.getWidth()) or state._viewport.width
    state._viewport.height = height or (love.graphics and love.graphics.getHeight()) or state._viewport.height

    if type(state.updateCamera) == "function" then
        state:updateCamera()
    end
end

return UIStateManager
