local UIStateManager = {}

-- Create default UI state configurations
local function createCargoUIState()
    return {
        visible = false,
        dragging = false,
    }
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

local function createMultiplayerUIState()
    return {
        visible = false,
        dragging = false,
        inputActive = false,
        addressInput = "",
        status = "",
        _hostRequested = false,
        _joinRequested = false,
        _was_mouse_down = false,
    }
end

function UIStateManager.initialize(state)
    if not state then
        return
    end

    -- Initialize UI states
    state.cargoUI = createCargoUIState()
    state.deathUI = createDeathUIState()
    state.multiplayerUI = createMultiplayerUIState()
    
    -- Initialize input state
    state.uiInput = {
        mouseCaptured = false,
        keyboardCaptured = false,
    }
    
    -- Initialize respawn state
    state.respawnRequested = false
end

function UIStateManager.cleanup(state)
    if not state then
        return
    end

    state.cargoUI = nil
    state.deathUI = nil
    state.multiplayerUI = nil
    state.uiInput = nil
    state.respawnRequested = nil
end

function UIStateManager.showDeathUI(state)
    if not (state and state.deathUI) then
        return
    end

    local deathUI = state.deathUI
    deathUI.visible = true
    deathUI.buttonHovered = false
    deathUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

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

return UIStateManager
