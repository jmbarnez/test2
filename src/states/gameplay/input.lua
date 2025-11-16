--- Input Handling Module
-- Processes keyboard, mouse, and wheel input for gameplay state

local InputMapper = require("src.input.mapper")
local PlayerManager = require("src.player.manager")
local PlayerWeapons = require("src.player.weapons")
local UIStateManager = require("src.ui.state_manager")
local SaveLoad = require("src.util.save_load")
local View = require("src.states.gameplay.view")
local Feedback = require("src.states.gameplay.feedback")
local Targeting = require("src.states.gameplay.targeting")

local love = love

local CONTROL_KEYS = { "lctrl", "rctrl" }

local Input = {}

--- Check if control modifier is active
---@return boolean True if ctrl is pressed
local function isControlModifierActive()
    if not (love and love.keyboard and love.keyboard.isDown) then
        return false
    end

    for i = 1, #CONTROL_KEYS do
        if love.keyboard.isDown(CONTROL_KEYS[i]) then
            return true
        end
    end

    return false
end

--- Handle mouse wheel scrolling
---@param state table Gameplay state
---@param x number Horizontal scroll
---@param y number Vertical scroll
function Input.wheelmoved(state, x, y)
    -- Give UI a chance to consume scroll input
    if UIStateManager.handleWheelMoved(state, x, y) then
        return
    end

    if not y or y == 0 then
        return
    end

    if state.uiInput and state.uiInput.mouseCaptured then
        return
    end

    -- Handle camera zoom
    local cam = state.camera
    if not cam then
        return
    end

    local currentZoom = cam.zoom or 1
    local zoomStep = 0.1
    local desiredZoom = currentZoom + y * zoomStep
    local clampedZoom = math.max(0.5, math.min(2, desiredZoom))

    if math.abs(clampedZoom - currentZoom) < 1e-4 then
        return
    end

    cam.zoom = clampedZoom
    View.updateCamera(state)
end

--- Handle mouse press events
---@param state table Gameplay state
---@param x number Mouse x position
---@param y number Mouse y position
---@param button number Mouse button
---@param istouch boolean Is touch input
---@param presses number Number of presses
function Input.mousepressed(state, x, y, button, istouch, presses)
    -- UI takes priority on mouse interaction
    if UIStateManager.handleMousePressed(state, x, y, button, istouch, presses) then
        return
    end

    if button ~= 1 then
        return
    end

    local uiInput = state.uiInput
    if (uiInput and uiInput.mouseCaptured) or UIStateManager.isAnyUIVisible(state) then
        return
    end

    if not isControlModifierActive() then
        return
    end

    local cache = state.targetingCache
    local hovered = cache and cache.hoveredEntity or nil

    if not hovered or not hovered.enemy then
        Targeting.clearActive(state)
        Targeting.clearLock(state)
        if cache then
            cache.entity = cache.hoveredEntity
        end
        return
    end

    -- Toggle off if clicking active target
    if hovered == state.activeTarget then
        Targeting.clearActive(state)
        Targeting.clearLock(state)
        if cache then
            cache.entity = cache.hoveredEntity
        end
        return
    end

    -- Begin lock on new target
    Targeting.beginLock(state, hovered)
end

--- Handle mouse release events
---@param state table Gameplay state
---@param x number Mouse x position
---@param y number Mouse y position
---@param button number Mouse button
---@param istouch boolean Is touch input
---@param presses number Number of presses
function Input.mousereleased(state, x, y, button, istouch, presses)
    UIStateManager.handleMouseReleased(state, x, y, button, istouch, presses)
end

--- Handle text input events
---@param state table Gameplay state
---@param text string Input text
function Input.textinput(state, text)
    UIStateManager.handleTextInput(state, text)
end

--- Handle key press events
---@param state table Gameplay state
---@param key string Key name
---@param scancode string Scan code
---@param isrepeat boolean Is key repeat
function Input.keypressed(state, key, scancode, isrepeat)
    -- Allow UI windows to process keyboard input first
    if UIStateManager.handleKeyPressed(state, key, scancode, isrepeat) then
        return
    end

    -- Process key through intent system
    InputMapper.processKey(state, key)
    local intent = InputMapper.getIntent(state)
    
    if not intent then
        return
    end

    -- Debug toggle
    if intent.toggleDebug then
        if UIStateManager.isDebugUIVisible(state) then
            UIStateManager.hideDebugUI(state)
        else
            UIStateManager.showDebugUI(state)
        end
        InputMapper.resetIntents(state)
        return
    end

    -- Fullscreen toggle
    if key == "f11" then
        UIStateManager.toggleFullscreen(state)
        return
    end

    -- Pause menu handling
    if UIStateManager.isPauseUIVisible(state) then
        if intent.togglePause or intent.confirm then
            UIStateManager.hidePauseUI(state)
        end
        InputMapper.resetIntents(state)
        return
    end

    -- Death screen handling
    if UIStateManager.isDeathUIVisible(state) then
        if intent.confirm then
            UIStateManager.requestRespawn(state)
        end
        InputMapper.resetIntents(state)
        return
    end

    -- Pause toggle
    if intent.togglePause then
        UIStateManager.showPauseUI(state)
        InputMapper.resetIntents(state)
        return
    end

    -- Weapon slot selection
    if intent.weaponSlot and InputMapper.shouldProcessIntent(state, "weaponSlot") then
        local player = PlayerManager.getCurrentShip(state)
        if player then
            local slots = PlayerWeapons.getSlots(player, { refresh = true })
            if slots and slots.list and #slots.list > 0 then
                local count = #slots.list
                local index = intent.weaponSlot
                if index >= 1 and index <= count then
                    PlayerWeapons.selectByIndex(player, index)
                end
            end
        end
        InputMapper.resetIntents(state)
        return
    end

    -- Interact with stations
    if intent.interact and InputMapper.shouldProcessIntent(state, "interact") then
        if state.stationDockTarget then
            UIStateManager.showStationUI(state)
        end
        InputMapper.resetIntents(state)
        return
    end

    -- UI toggles
    if intent.toggleCargo then
        UIStateManager.toggleCargoUI(state)
        InputMapper.resetIntents(state)
        return
    end

    if intent.toggleMap then
        UIStateManager.toggleMapUI(state)
        InputMapper.resetIntents(state)
        return
    end

    if intent.toggleSkills then
        UIStateManager.toggleSkillsUI(state)
        InputMapper.resetIntents(state)
        return
    end

    -- Save/Load
    if intent.quickSave and InputMapper.shouldProcessIntent(state, "quickSave") then
        local success, err = SaveLoad.saveGame(state)
        if success then
            Feedback.showToast(state, "Game Saved", { 0.4, 1.0, 0.4, 1.0 })
        else
            Feedback.showToast(state, "Save Failed: " .. tostring(err), { 1.0, 0.4, 0.4, 1.0 })
            print("[SaveLoad] Save error: " .. tostring(err))
        end
        InputMapper.resetIntents(state)
        return
    end

    -- Debug helpers
    if intent.showSeed and InputMapper.shouldProcessIntent(state, "showSeed") then
        local seedLabel = tostring(state.universeSeed or "<none>")
        Feedback.showToast(state, "Seed: " .. seedLabel, { 0.65, 0.85, 1.0, 1.0 })
        print("[Gameplay] Current universe seed: " .. seedLabel)
        InputMapper.resetIntents(state)
        return
    end

    if intent.dumpWorld and InputMapper.shouldProcessIntent(state, "dumpWorld") then
        local ok, err = SaveLoad.debugDumpWorld(state)
        if ok then
            Feedback.showToast(state, "World dump written", { 0.6, 1.0, 0.6, 1.0 })
        else
            Feedback.showToast(state, "Dump failed: " .. tostring(err), { 1.0, 0.5, 0.5, 1.0 })
            print("[SaveLoad] World dump error: " .. tostring(err))
        end
        InputMapper.resetIntents(state)
        return
    end

    if intent.quickLoad and InputMapper.shouldProcessIntent(state, "quickLoad") then
        local success, err = SaveLoad.loadGame(state)
        if success then
            Feedback.showToast(state, "Game Loaded", { 0.4, 1.0, 0.4, 1.0 })
        else
            Feedback.showToast(state, "Load Failed: " .. tostring(err), { 1.0, 0.4, 0.4, 1.0 })
            print("[SaveLoad] Load error: " .. tostring(err))
        end
        InputMapper.resetIntents(state)
        return
    end
    
    -- Clean up intents for next frame
    InputMapper.resetIntents(state)
end

return Input
