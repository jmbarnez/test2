local UIStateManager = {}

---@diagnostic disable-next-line: undefined-global
local love = love

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

local function createPauseUIState()
    return {
        visible = false,
        title = "Paused",
        message = "Take a breather while the galaxy waits.",
        hint = "Press Esc or Enter to resume",
        buttonLabel = "Resume",
        resumeHovered = false,
        _was_mouse_down = false,
    }
end

local function createChatUIState()
    return {
        visible = true,
        inputActive = false,
        inputBuffer = "",
        messages = {},
        playerColors = {},
        maxVisible = 6,
        maxHistory = 50,
    }
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
    state.multiplayerUI = state.multiplayerUI or createMultiplayerUIState()
    state.pauseUI = state.pauseUI or createPauseUIState()
    state.chatUI = state.chatUI or createChatUIState()
    
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
    state.multiplayerUI = nil
    state.chatUI = nil
    state.pauseUI = nil
    state.uiInput = nil
    state.respawnRequested = nil
    state.isPaused = nil
end

function UIStateManager.addChatMessage(state, playerId, text)
    if not (state and state.chatUI) then
        return
    end

    local chat = state.chatUI
    chat.messages = chat.messages or {}
    chat.playerColors = chat.playerColors or {}

    local colorKey = tostring(playerId or "unknown")
    local playerColor = chat.playerColors[colorKey]
    if not playerColor then
        playerColor = generatePlayerColor(playerId)
        chat.playerColors[colorKey] = playerColor
    end

    local message = {
        playerId = playerId,
        text = text,
        color = playerColor,
    }

    if love and love.timer and love.timer.getTime then
        message.timestamp = love.timer.getTime()
    end

    table.insert(chat.messages, message)

    local maxHistory = chat.maxHistory or 50
    while #chat.messages > maxHistory do
        table.remove(chat.messages, 1)
    end
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

local function setPauseVisibility(state, visible)
    if not (state and state.pauseUI) then
        return
    end

    local pauseUI = state.pauseUI
    if pauseUI.visible == visible then
        state.isPaused = pauseUI.visible
        return
    end

    pauseUI.visible = visible
    pauseUI.resumeHovered = false
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

function UIStateManager.isPauseUIVisible(state)
    return state and state.pauseUI and state.pauseUI.visible
end

function UIStateManager.isPaused(state)
    return state and state.isPaused
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
