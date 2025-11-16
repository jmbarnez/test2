--- Input Mapper
-- Processes raw input events and translates them to intents
-- Handles context-aware input (respects UI capture)

local Intent = require("src.input.intent")
local Bindings = require("src.input.bindings")

local Mapper = {}

-- Process a key press and update intents accordingly
-- Returns true if the key was handled (mapped to an intent), false otherwise
function Mapper.processKey(state, key)
    if not (state and key) then
        return false
    end
    
    -- Get intents for this key
    local intentNames = Bindings.getIntentsForKey(key)
    if not intentNames or #intentNames == 0 then
        return false
    end
    
    -- Get or create the intent container
    local intent = Intent.ensure(state, "player")
    if not intent then
        return false
    end
    
    -- Check for weapon slot intents (special case)
    for _, intentName in ipairs(intentNames) do
        if intentName:match("^weaponSlot") then
            local slotNumber = nil
            
            if intentName == "weaponSlot0" then
                slotNumber = 10
            else
                local digit = intentName:match("weaponSlot(%d)")
                if digit then
                    slotNumber = tonumber(digit)
                end
            end
            
            if slotNumber then
                Intent.setWeaponSlot(intent, slotNumber)
                return true
            end
        end
    end
    
    -- Set all matched intents to true
    for _, intentName in ipairs(intentNames) do
        Intent.setIntent(intent, intentName, true)
    end
    
    return #intentNames > 0
end

-- Check if an intent is active and should be processed
-- Respects UI capture contexts
function Mapper.shouldProcessIntent(state, intentName)
    if not (state and intentName) then
        return false
    end
    
    local uiInput = state.uiInput
    
    -- Gameplay intents should not fire when keyboard is captured by UI
    local gameplayIntents = {
        interact = true,
        toggleCargo = true,
        toggleMap = true,
        toggleSkills = true,
        quickSave = true,
        quickLoad = true,
        showSeed = true,
        dumpWorld = true,
    }
    
    if gameplayIntents[intentName] and uiInput and uiInput.keyboardCaptured then
        return false
    end
    
    -- Weapon slots should not process when keyboard is captured
    if intentName == "weaponSlot" and uiInput and uiInput.keyboardCaptured then
        return false
    end
    
    -- Allow system intents (pause, debug, etc.) to always work
    -- These are typically menu toggles that need to work regardless of context
    return true
end

-- Get an active intent from the state
function Mapper.getIntent(state, playerId)
    return Intent.get(state, playerId or "player")
end

-- Reset intents for next frame
function Mapper.resetIntents(state, playerId)
    local intent = Intent.get(state, playerId or "player")
    if intent then
        Intent.reset(intent)
    end
end

return Mapper
