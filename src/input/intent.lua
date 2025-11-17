local Intent = {}

local function create_default_intent()
    return {
        -- UI intents
        togglePause = false,
        toggleDebug = false,
        confirm = false,
        
        -- Gameplay intents
        interact = false,
        toggleCargo = false,
        toggleMap = false,
        toggleSkills = false,
        
        -- Save/Load intents
        quickSave = false,
        quickLoad = false,
        
        -- Debug intents
        showSeed = false,
        dumpWorld = false,
        
        -- Weapon selection (special case)
        weaponSlot = nil, -- number 1-10 or nil
    }
end

function Intent.ensureContainer(holder)
    if not holder then
        return nil
    end

    holder.playerIntents = holder.playerIntents or {}
    return holder.playerIntents
end

function Intent.ensure(holder, playerId)
    local container = Intent.ensureContainer(holder)
    if not container then
        return nil
    end

    playerId = playerId or "player"
    local intent = container[playerId]
    if not intent then
        intent = create_default_intent()
        container[playerId] = intent
    end

    return intent
end

function Intent.get(holder, playerId)
    local container = holder and holder.playerIntents
    if not container then
        return nil
    end

    return container[playerId or "player"]
end

function Intent.reset(intent)
    if not intent then
        return
    end

    -- UI intents
    intent.togglePause = false
    intent.toggleDebug = false
    intent.confirm = false
    
    -- Gameplay intents
    intent.interact = false
    intent.toggleCargo = false
    intent.toggleMap = false
    intent.toggleSkills = false
    
    -- Save/Load intents
    intent.quickSave = false
    intent.quickLoad = false
    
    -- Debug intents
    intent.showSeed = false
    intent.dumpWorld = false
    
    -- Weapon selection
    intent.weaponSlot = nil
end

-- Generic setter for boolean intents (toggles, actions, etc.)
function Intent.setIntent(intent, intentName, isActive)
    if intent and intentName then
        intent[intentName] = not not isActive
    end
end

-- Set weapon slot selection
function Intent.setWeaponSlot(intent, slotIndex)
    if intent then
        intent.weaponSlot = slotIndex
    end
end

return Intent
