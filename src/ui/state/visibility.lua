-- Visibility Management
-- Coordinates window visibility, input capture, and pause state

local core = require("src.ui.state.core")
local Quests = require("src.ui.state.quests")

local resolve_state_pair = core.resolve_state_pair
local set_state_field = core.set_state_field
local any_modal_visible = core.any_modal_visible
local capture_input = core.capture_input
local release_input = core.release_input
local create_visibility_handlers = core.create_visibility_handlers

---@diagnostic disable-next-line: undefined-global
local love = love

local Visibility = {}

local function is_primary_mouse_down()
    return love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
end

-- ============================================================================
-- Cargo UI
-- ============================================================================

local cargoVisibilityController = create_visibility_handlers("cargoUI", {
    afterSet = function(state, window_state, visible)
        window_state.dragging = false
        window_state._was_mouse_down = is_primary_mouse_down()

        if visible then
            capture_input(state)
        else
            release_input(state, true)
        end
    end,
})

function Visibility.showCargoUI(state)
    cargoVisibilityController.show(state)
end

function Visibility.hideCargoUI(state)
    cargoVisibilityController.hide(state)
end

function Visibility.toggleCargoUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.cargoUI) then
        return
    end

    if resolved.cargoUI.visible then
        Visibility.hideCargoUI(resolved)
    else
        Visibility.showCargoUI(resolved)
    end
end

function Visibility.isCargoUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.cargoUI and state.cargoUI.visible
end

-- ============================================================================
-- Death UI
-- ============================================================================

function Visibility.showDeathUI(state)
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
    deathUI._was_mouse_down = is_primary_mouse_down()

    if Visibility.isPauseUIVisible(state) then
        Visibility.hidePauseUI(state)
    end

    if state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end
end

function Visibility.hideDeathUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.deathUI) then
        return
    end

    state = resolved
    local deathUI = state.deathUI
    deathUI.visible = false
    deathUI._was_mouse_down = is_primary_mouse_down()
    deathUI.buttonHovered = false
    deathUI.respawnHovered = false
    deathUI.exitHovered = false

    if state.uiInput then
        state.uiInput.mouseCaptured = false
        state.uiInput.keyboardCaptured = false
    end
end

function Visibility.isDeathUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.deathUI and state.deathUI.visible
end

-- ============================================================================
-- Pause UI
-- ============================================================================

local pauseVisibilityController = create_visibility_handlers("pauseUI", {
    beforeSet = function(state, window_state, visible)
        if visible and Visibility.isDeathUIVisible(state) then
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

function Visibility.showPauseUI(state)
    pauseVisibilityController.show(state)
end

function Visibility.hidePauseUI(state)
    pauseVisibilityController.hide(state)
end

function Visibility.togglePauseUI(state)
    pauseVisibilityController.toggle(state)
end

function Visibility.isPauseUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.pauseUI and state.pauseUI.visible
end

function Visibility.isPaused(state)
    state = resolve_state_pair(state)
    return state and state.isPaused == true
end

-- ============================================================================
-- Options UI
-- ============================================================================

function Visibility.showOptionsUI(state, source)
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
    optionsUI._was_mouse_down = is_primary_mouse_down()

    if source == "pause" and state.pauseUI and state.pauseUI.visible then
        state.pauseUI.visible = false
    end

    if state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end

    set_state_field(state, proxy, "isPaused", true)
end

function Visibility.hideOptionsUI(state)
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
        Visibility.showPauseUI(state)
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

function Visibility.isOptionsUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.optionsUI and state.optionsUI.visible
end

-- ============================================================================
-- Map UI
-- ============================================================================

local mapVisibilityController = create_visibility_handlers("mapUI", {
    afterSet = function(state, window_state, visible)
        window_state.dragging = false
        window_state._just_opened = visible

        if visible then
            if state.uiInput then
                state.uiInput.mouseCaptured = true
            end
        else
            window_state._was_mouse_down = is_primary_mouse_down()
            release_input(state, true)
        end
    end,
})

function Visibility.showMapUI(state)
    mapVisibilityController.show(state)
end

function Visibility.hideMapUI(state)
    mapVisibilityController.hide(state)
end

function Visibility.toggleMapUI(state)
    mapVisibilityController.toggle(state)
end

function Visibility.isMapUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.mapUI and state.mapUI.visible
end

-- ============================================================================
-- Skills UI
-- ============================================================================

local skillsVisibilityController = create_visibility_handlers("skillsUI", {
    afterSet = function(state, window_state, visible)
        window_state.dragging = false

        if not visible then
            window_state._was_mouse_down = is_primary_mouse_down()
        end
    end,
})

function Visibility.showSkillsUI(state)
    skillsVisibilityController.show(state)
end

function Visibility.hideSkillsUI(state)
    skillsVisibilityController.hide(state)
end

function Visibility.toggleSkillsUI(state)
    skillsVisibilityController.toggle(state)
end

function Visibility.isSkillsUIVisible(state)
    return state and state.skillsUI and state.skillsUI.visible
end

-- ============================================================================
-- Debug UI
-- ============================================================================

local debugVisibilityController = create_visibility_handlers("debugUI", {
    afterSet = function(state, window_state, visible)
        window_state.dragging = false
    end,
})

function Visibility.showDebugUI(state)
    debugVisibilityController.show(state)
end

function Visibility.hideDebugUI(state)
    debugVisibilityController.hide(state)
end

function Visibility.toggleDebugUI(state)
    debugVisibilityController.toggle(state)
end

function Visibility.isDebugUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.debugUI and state.debugUI.visible
end

-- ============================================================================
-- Station UI
-- ============================================================================

function Visibility.showStationUI(state)
    local resolved, proxy = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        return
    end

    state = resolved
    local stationUI = state.stationUI
    stationUI.visible = true
    stationUI._was_mouse_down = is_primary_mouse_down()

    Quests.ensure(state)

    if state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end
end

function Visibility.hideStationUI(state)
    local resolved, proxy = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        return
    end

    state = resolved
    local stationUI = state.stationUI
    stationUI.visible = false
    stationUI.dragging = false

    if state.uiInput then
        local keepCaptured = any_modal_visible(state)
        state.uiInput.mouseCaptured = not not keepCaptured
        state.uiInput.keyboardCaptured = not not keepCaptured
    end
end

function Visibility.toggleStationUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        return
    end

    if resolved.stationUI.visible then
        Visibility.hideStationUI(state)
    else
        Visibility.showStationUI(state)
    end
end

function Visibility.isStationUIVisible(state)
    state = resolve_state_pair(state)
    return state and state.stationUI and state.stationUI.visible
end

-- ============================================================================
-- General Visibility
-- ============================================================================

function Visibility.isAnyUIVisible(state)
    return any_modal_visible(state)
end

return Visibility
