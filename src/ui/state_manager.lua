local UIStateManager = {}

local core = require("src.ui.state.core")
local factories = require("src.ui.state.factories")
local Events = require("src.ui.state.events")
local QuestGenerator = require("src.stations.quest_generator")

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

local function resolve_station_signature(station)
    if not station then
        return nil
    end

    return station.id
        or station.stationId
        or station.blueprintId
        or station.stationType
        or station.name
        or station.callsign
        or tostring(station)
end

local function regenerate_station_quests(state)
    if not (state and state.stationUI) then
        return
    end

    local stationUI = state.stationUI
    local station = state.stationDockTarget
    stationUI.activeQuestIds = stationUI.activeQuestIds or {}

    local previousQuests = stationUI.quests or {}
    local previousSelected = stationUI.selectedQuestId
    local trackedId = stationUI.activeQuestId
    local activeIds = stationUI.activeQuestIds

    local preserved = {}
    if type(activeIds) == "table" then
        for i = 1, #previousQuests do
            local quest = previousQuests[i]
            local id = quest and quest.id
            if id and activeIds[id] then
                preserved[id] = quest
                quest.accepted = true
            end
        end
    end

    local generated = QuestGenerator.generate(state, station) or {}
    local result = {}
    local seen = {}

    local function pushQuest(quest)
        if not quest then
            return
        end

        local id = quest.id
        if not id or seen[id] then
            return
        end

        if activeIds and activeIds[id] then
            quest.accepted = true
            quest.progress = quest.progress or 0
        else
            quest.accepted = nil
        end

        seen[id] = true
        result[#result + 1] = quest
    end

    for i = 1, #generated do
        local quest = generated[i]
        local id = quest and quest.id
        if id and preserved[id] then
            pushQuest(preserved[id])
            preserved[id] = nil
        else
            pushQuest(quest)
        end
    end

    for _, quest in pairs(preserved) do
        pushQuest(quest)
    end

    stationUI.quests = result
    stationUI._lastStationSignature = resolve_station_signature(station)

    if type(activeIds) == "table" then
        for id in pairs(activeIds) do
            if not seen[id] then
                activeIds[id] = nil
            end
        end
    end

    if trackedId and (not activeIds or not activeIds[trackedId]) then
        trackedId = nil
    end

    if previousSelected and seen[previousSelected] then
        stationUI.selectedQuestId = previousSelected
    elseif stationUI.quests and #stationUI.quests > 0 then
        stationUI.selectedQuestId = stationUI.quests[1].id
    else
        stationUI.selectedQuestId = nil
    end

    if not trackedId and type(activeIds) == "table" then
        for i = 1, #stationUI.quests do
            local quest = stationUI.quests[i]
            local id = quest and quest.id
            if id and activeIds[id] then
                trackedId = id
                break
            end
        end
    end

    stationUI.activeQuestId = trackedId
end

function UIStateManager.refreshStationQuests(state)
    regenerate_station_quests(state)
end

local function ensure_station_quests(state)
    if not (state and state.stationUI) then
        return
    end

    local stationUI = state.stationUI
    local station = state.stationDockTarget
    local signature = resolve_station_signature(station)

    if not stationUI.quests or stationUI._lastStationSignature ~= signature then
        regenerate_station_quests(state)
    end
end

local function is_primary_mouse_down()
    return love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false
end

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

function UIStateManager.showCargoUI(state)
    cargoVisibilityController.show(state)
end

function UIStateManager.hideCargoUI(state)
    cargoVisibilityController.hide(state)
end

function UIStateManager.toggleCargoUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.cargoUI) then
        return
    end

    if resolved.cargoUI.visible then
        UIStateManager.hideCargoUI(resolved)
    else
        UIStateManager.showCargoUI(resolved)
    end
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

function UIStateManager.toggleStationUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        return
    end

    if resolved.stationUI.visible then
        UIStateManager.hideStationUI(resolved)
    else
        UIStateManager.showStationUI(resolved)
    end
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

        if visible then
            capture_input(state)
        else
            window_state._was_mouse_down = is_primary_mouse_down()
            release_input(state, true)
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
        return
    end

    state = resolved
    local stationUI = state.stationUI
    stationUI.visible = true
    stationUI._was_mouse_down = love.mouse and love.mouse.isDown and love.mouse.isDown(1) or false

    ensure_station_quests(state)

    if state.uiInput then
        state.uiInput.mouseCaptured = true
        state.uiInput.keyboardCaptured = true
    end
end

function UIStateManager.hideStationUI(state)
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

function UIStateManager.toggleStationUI(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        return
    end

    if resolved.stationUI.visible then
        UIStateManager.hideStationUI(state)
    else
        UIStateManager.showStationUI(state)
    end
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
