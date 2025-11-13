local UIStateManager = {}

local window = require("src.ui.components.window")
local dropdown = require("src.ui.components.dropdown")

---@diagnostic disable-next-line: undefined-global
local love = love

local function resolve_state_pair(state)
    if not state then
        return nil, nil
    end

    if type(state.resolveState) == "function" then
        local ok, resolved = pcall(state.resolveState, state)
        if ok and type(resolved) == "table" and resolved ~= state then
            return resolved, state
        end
    end

    if type(state.state) == "table" and state.state ~= state then
        return state.state, state
    end

    return state, nil
end

local function set_state_field(primary, secondary, key, value)
    if primary then
        primary[key] = value
    end

    if secondary and secondary ~= primary then
        secondary[key] = value
    end
end

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

local function createStationUIState()
    return {
        visible = false,
        dragging = false,
        x = nil,
        y = nil,
        width = nil,
        height = nil,
        _was_mouse_down = false,
    }
end

local function any_modal_visible(state)
    state = resolve_state_pair(state)
    if not state then
        return false
    end

    return (state.pauseUI and state.pauseUI.visible)
        or (state.deathUI and state.deathUI.visible)
        or (state.cargoUI and state.cargoUI.visible)
        or (state.optionsUI and state.optionsUI.visible)
        or (state.mapUI and state.mapUI.visible)
        or (state.skillsUI and state.skillsUI.visible)
        or (state.stationUI and state.stationUI.visible)
end

local function capture_input(state)
    state = resolve_state_pair(state)
    if state and state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end
end

local function release_input(state, respect_modals)
    state = resolve_state_pair(state)
    if not (state and state.uiInput) then
        return
    end

    if respect_modals then
        local keepCaptured = any_modal_visible(state)
        state.uiInput.mouseCaptured = not not keepCaptured
        state.uiInput.keyboardCaptured = not not keepCaptured
    else
        state.uiInput.mouseCaptured = false
        state.uiInput.keyboardCaptured = false
    end
end

local function is_primary_mouse_down()
    return love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
end

local function create_visibility_handlers(windowKey, config)
    config = config or {}

    local function set_visibility(state, visible)
        local resolved, proxy = resolve_state_pair(state)
        if not resolved then
            return
        end

        state = resolved
        if not (state and state[windowKey]) then
            return
        end

        local window_state = state[windowKey]

        if config.beforeSet and config.beforeSet(state, window_state, visible, proxy) == false then
            return
        end

        if window_state.visible == visible then
            if config.onUnchanged then
                config.onUnchanged(state, window_state, visible, proxy)
            end
            return
        end

        window_state.visible = visible

        if config.afterSet then
            config.afterSet(state, window_state, visible, proxy)
        end
    end

    return {
        set = set_visibility,
        show = function(state)
            set_visibility(state, true)
        end,
        hide = function(state)
            set_visibility(state, false)
        end,
        toggle = function(state)
            if not (state and state[windowKey]) then
                return
            end

            set_visibility(state, not state[windowKey].visible)
        end,
    }
end

local function createDeathUIState()
    return {
        visible = false,
        title = "Ship Destroyed",
        message = "Your ship has been destroyed. Respawn to re-enter the fight.",
        buttonLabel = "Respawn",
        exitButtonLabel = "Exit to Menu",
        hint = "Press Enter to respawn",
        buttonHovered = false,
        respawnHovered = false,
        exitHovered = false,
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
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.deathUI) then
        return
    end

    state = resolved
    local deathUI = state.deathUI
    deathUI.visible = true
    deathUI.buttonHovered = false
    deathUI.respawnHovered = false
    deathUI.exitHovered = false
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
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.deathUI) then
        return
    end

    state = resolved
    local deathUI = state.deathUI
    deathUI.visible = false
    deathUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
    deathUI.buttonHovered = false
    deathUI.respawnHovered = false
    deathUI.exitHovered = false

    if state.uiInput then
        state.uiInput.mouseCaptured = false
        state.uiInput.keyboardCaptured = false
    end
end

function UIStateManager.toggleCargoUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.cargoUI) then
        return
    end

    state = resolved
    state.cargoUI.visible = not state.cargoUI.visible
end

local skillsVisibilityController = create_visibility_handlers("skillsUI", {
    afterSet = function(state, window_state, visible)
        window_state.dragging = false

        if not visible then
            window_state._was_mouse_down = is_primary_mouse_down()
        end
    end,
})

local function setSkillsVisibility(state, visible)
    skillsVisibilityController.set(state, visible)
end

function UIStateManager.showSkillsUI(state)
    skillsVisibilityController.show(state)
end

function UIStateManager.hideSkillsUI(state)
    skillsVisibilityController.hide(state)
end

function UIStateManager.toggleSkillsUI(state)
    skillsVisibilityController.toggle(state)
end

function UIStateManager.isSkillsUIVisible(state)
    return state and state.skillsUI and state.skillsUI.visible
end

local pauseVisibilityController = create_visibility_handlers("pauseUI", {
    beforeSet = function(state, window_state, visible)
        if visible and UIStateManager.isDeathUIVisible(state) then
            state.isPaused = window_state.visible
            return false
        end
    end,
    onUnchanged = function(state, window_state)
        state.isPaused = window_state.visible
    end,
    afterSet = function(state, window_state, visible)
        window_state.buttonHovered = false
        window_state._was_mouse_down = is_primary_mouse_down()

        if state.uiInput then
            state.uiInput.mouseCaptured = visible
            state.uiInput.keyboardCaptured = visible
        end

        state.isPaused = visible
    end,
})

function UIStateManager.showPauseUI(state)
    pauseVisibilityController.show(state)
end

function UIStateManager.hidePauseUI(state)
    pauseVisibilityController.hide(state)
end

function UIStateManager.togglePauseUI(state)
    pauseVisibilityController.toggle(state)
end

function UIStateManager.isPauseUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.pauseUI and state.pauseUI.visible
end

local mapVisibilityController = create_visibility_handlers("mapUI", {
    afterSet = function(state, window_state, visible)
        window_state.dragging = false
        window_state._just_opened = visible

        if not visible then
            window_state._was_mouse_down = is_primary_mouse_down()
        end
    end,
})

local function setMapVisibility(state, visible)
    mapVisibilityController.set(state, visible)
end

function UIStateManager.showMapUI(state)
    mapVisibilityController.show(state)
end

function UIStateManager.hideMapUI(state)
    mapVisibilityController.hide(state)
end

function UIStateManager.toggleMapUI(state)
    mapVisibilityController.toggle(state)
end

function UIStateManager.showOptionsUI(state, source)
    local resolved, proxy = resolve_state_pair(state)
    if not (resolved and resolved.optionsUI) then
        return
    end

    state = resolved
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

    set_state_field(state, proxy, "isPaused", true)
end

function UIStateManager.hideOptionsUI(state)
    local resolved, proxy = resolve_state_pair(state)
    if not (resolved and resolved.optionsUI) then
        return
    end

    state = resolved
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
        set_state_field(state, proxy, "isPaused", false)
    end
end

function UIStateManager.isOptionsUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.optionsUI and state.optionsUI.visible
end

function UIStateManager.isMapUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.mapUI and state.mapUI.visible
end

function UIStateManager.isPaused(state)
    state = resolve_state_pair(state)
    return state and state.isPaused == true
end

function UIStateManager.isAnyUIVisible(state)
    return any_modal_visible(state)
end

local debugVisibilityController = create_visibility_handlers("debugUI", {
    afterSet = function(state, window_state, visible)
        window_state.dragging = false
    end,
})

local function setDebugVisibility(state, visible)
    debugVisibilityController.set(state, visible)
end

function UIStateManager.toggleDebugUI(state)
    debugVisibilityController.toggle(state)
end

function UIStateManager.showDebugUI(state)
    debugVisibilityController.show(state)
end

function UIStateManager.hideDebugUI(state)
    debugVisibilityController.hide(state)
end

function UIStateManager.isDebugUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.debugUI and state.debugUI.visible
end

function UIStateManager.isDeathUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.deathUI and state.deathUI.visible
end

function UIStateManager.isCargoUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.cargoUI and state.cargoUI.visible
end

function UIStateManager.isStationUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.stationUI and state.stationUI.visible
end

function UIStateManager.showStationUI(state)
    local resolved, proxy = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        print("[UI] showStationUI: no stationUI on state", resolved)
        return
    end

    state = resolved
    local stationUI = state.stationUI
    stationUI.visible = true
    stationUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

    print("[UI] showStationUI: stationUI.visible set to true")

    if state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end
end

function UIStateManager.hideStationUI(state)
    local resolved, proxy = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        print("[UI] hideStationUI: no stationUI on state", resolved)
        return
    end

    state = resolved
    local stationUI = state.stationUI
    stationUI.visible = false
    stationUI.dragging = false

    print("[UI] hideStationUI: stationUI.visible set to false")

    if state.uiInput then
        local keepCaptured = any_modal_visible(state)
        state.uiInput.mouseCaptured = not not keepCaptured
        state.uiInput.keyboardCaptured = not not keepCaptured
    end
end

function UIStateManager.toggleStationUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        return
    end
    
    state = resolved
    state.stationUI.visible = not state.stationUI.visible
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
