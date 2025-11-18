local dropdown = require("src.ui.components.dropdown")

local factories = {}

function factories.createCargoUIState()
    return {
        visible = false,
        dragging = false,
        _was_mouse_down = false,
    }
end

function factories.createDebugUIState()
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

function factories.createSkillsUIState()
    return {
        visible = false,
        dragging = false,
        _was_mouse_down = false,
    }
end

function factories.createStationUIState()
    return {
        visible = false,
        dragging = false,
        x = nil,
        y = nil,
        width = nil,
        height = nil,
        _was_mouse_down = false,
        quests = nil,
        selectedQuestId = nil,
        activeQuestId = nil,
        activeQuestIds = {},
        _lastStationSignature = nil,
    }
end

function factories.createDeathUIState()
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

function factories.createPauseUIState()
    return {
        visible = false,
        title = "Paused",
        message = "Take a breather while the galaxy waits.",
        hint = "Press Esc or Enter to resume",
        buttonLabel = "Resume",
        buttonHovered = false,
        saveStatus = nil,
        saveStatusColor = nil,
        progress = {
            visible = false,
            current = 0,
            total = 0,
            label = nil,
            completedAt = nil,
            isSaving = false,
            error = false,
        },
        _was_mouse_down = false,
    }
end

function factories.createOptionsUIState()
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

function factories.createMapUIState()
    return {
        visible = false,
        mode = "sector",
        title = "Sector Map",
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

function factories.resetWindowGeometry(windowState)
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

return factories
