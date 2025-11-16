local vector = require("src.util.vector")

local Intent = {}

local function create_default_intent()
    return {
        -- Combat intents
        moveX = 0,
        moveY = 0,
        moveMagnitude = 0,
        aimX = 0,
        aimY = 0,
        hasAim = false,
        firePrimary = false,
        fireSecondary = false,
        ability1 = false,
        
        -- UI intents
        togglePause = false,
        toggleDebug = false,
        toggleFullscreen = false,
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

    -- Combat intents
    intent.moveX = 0
    intent.moveY = 0
    intent.moveMagnitude = 0
    intent.hasAim = false
    intent.firePrimary = false
    intent.fireSecondary = false
    intent.ability1 = false
    
    -- UI intents
    intent.togglePause = false
    intent.toggleDebug = false
    intent.toggleFullscreen = false
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

function Intent.setMove(intent, moveX, moveY)
    if not intent then
        return
    end

    local mx = moveX or 0
    local my = moveY or 0

    local normX, normY, length = vector.normalize(mx, my)

    if length > vector.EPSILON then
        intent.moveX = normX
        intent.moveY = normY
        intent.moveMagnitude = math.min(length, 1)
    else
        intent.moveX = 0
        intent.moveY = 0
        intent.moveMagnitude = 0
    end
end

function Intent.setAim(intent, worldX, worldY)
    if not intent then
        return
    end

    intent.aimX = worldX or 0
    intent.aimY = worldY or 0
    intent.hasAim = true
end

function Intent.setFirePrimary(intent, isDown)
    if intent then
        intent.firePrimary = not not isDown
    end
end

function Intent.setFireSecondary(intent, isDown)
    if intent then
        intent.fireSecondary = not not isDown
    end
end

function Intent.setAbility(intent, index, isDown)
    if not intent then
        return
    end

    index = index or 1
    if index == 1 then
        intent.ability1 = not not isDown
    else
        local field = "ability" .. tostring(index)
        intent[field] = not not isDown
    end
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
