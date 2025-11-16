--- Input Bindings Configuration
-- Maps raw keyboard/mouse inputs to abstract intents
-- Designed for easy key rebinding and context-aware input handling

local Bindings = {}

-- Default key bindings
-- Format: [intent_name] = { keys = {...}, mouse = {...}, context = "..." }
Bindings.defaults = {
    -- UI Navigation & System
    togglePause = { keys = { "escape" } },
    toggleDebug = { keys = { "f1" } },
    toggleFullscreen = { keys = { "f11" } },
    confirm = { keys = { "return", "kpenter", "space" } },
    
    -- Gameplay UI
    interact = { keys = { "e" } },
    toggleCargo = { keys = { "tab" } },
    toggleMap = { keys = { "m" } },
    toggleSkills = { keys = { "k" } },
    
    -- Save/Load
    quickSave = { keys = { "f5" } },
    quickLoad = { keys = { "f9" } },
    
    -- Debug
    showSeed = { keys = { "f6" } },
    dumpWorld = { keys = { "f7" } },
    
    -- Weapon Slots (special case, handled separately)
    weaponSlot1 = { keys = { "1" } },
    weaponSlot2 = { keys = { "2" } },
    weaponSlot3 = { keys = { "3" } },
    weaponSlot4 = { keys = { "4" } },
    weaponSlot5 = { keys = { "5" } },
    weaponSlot6 = { keys = { "6" } },
    weaponSlot7 = { keys = { "7" } },
    weaponSlot8 = { keys = { "8" } },
    weaponSlot9 = { keys = { "9" } },
    weaponSlot0 = { keys = { "0" } },
}

-- Create a reverse lookup table: key -> intent names
local function buildKeyToIntentMap(bindings)
    local keyMap = {}
    
    for intentName, binding in pairs(bindings) do
        if binding.keys then
            for _, key in ipairs(binding.keys) do
                keyMap[key] = keyMap[key] or {}
                table.insert(keyMap[key], intentName)
            end
        end
    end
    
    return keyMap
end

-- Initialize bindings system
function Bindings.initialize()
    Bindings.current = Bindings.current or {}
    
    -- Copy defaults
    for intentName, binding in pairs(Bindings.defaults) do
        Bindings.current[intentName] = Bindings.current[intentName] or {}
        local current = Bindings.current[intentName]
        
        current.keys = current.keys or {}
        if binding.keys then
            for i, key in ipairs(binding.keys) do
                current.keys[i] = key
            end
        end
    end
    
    -- Build reverse lookup
    Bindings.keyToIntent = buildKeyToIntentMap(Bindings.current)
end

-- Get all intents triggered by a key press
function Bindings.getIntentsForKey(key)
    if not Bindings.keyToIntent then
        Bindings.initialize()
    end
    
    return Bindings.keyToIntent[key] or {}
end

-- Check if a key is bound to an intent
function Bindings.isKeyBoundTo(key, intentName)
    local intents = Bindings.getIntentsForKey(key)
    
    for _, intent in ipairs(intents) do
        if intent == intentName then
            return true
        end
    end
    
    return false
end

-- Get primary key for an intent (first key in the list)
function Bindings.getPrimaryKey(intentName)
    if not Bindings.current then
        Bindings.initialize()
    end
    
    local binding = Bindings.current[intentName]
    if binding and binding.keys and #binding.keys > 0 then
        return binding.keys[1]
    end
    
    return nil
end

-- Rebind a key to an intent (for future key rebinding UI)
function Bindings.rebind(intentName, newKey)
    if not Bindings.current then
        Bindings.initialize()
    end
    
    -- Remove old binding for this key
    for intent, binding in pairs(Bindings.current) do
        if binding.keys then
            for i = #binding.keys, 1, -1 do
                if binding.keys[i] == newKey then
                    table.remove(binding.keys, i)
                end
            end
        end
    end
    
    -- Add new binding
    Bindings.current[intentName] = Bindings.current[intentName] or {}
    Bindings.current[intentName].keys = Bindings.current[intentName].keys or {}
    table.insert(Bindings.current[intentName].keys, 1, newKey)
    
    -- Rebuild lookup
    Bindings.keyToIntent = buildKeyToIntentMap(Bindings.current)
end

-- Reset to defaults
function Bindings.reset()
    Bindings.current = nil
    Bindings.keyToIntent = nil
    Bindings.initialize()
end

-- Initialize on load
Bindings.initialize()

return Bindings
