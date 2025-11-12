local PlayerWeapons = require("src.player.weapons")
local constants = require("src.constants.game")
local table_util = require("src.util.table")
local deep_copy = table_util.deep_copy

---@diagnostic disable-next-line: undefined-global
local love = love

local STARTING_CURRENCY = (constants.player and constants.player.starting_currency) or 0

local PlayerManager = {}

local DEFAULT_SKILLS = {
    industry = {
        order = 30,
        label = "Industry",
        skills = {
            mining = {
                order = 10,
                label = "Mining",
                level = 1,
                xp = 0,
                xpRequired = 120,
                xpRate = 0,
                description = "Improves resource extraction yield and mining laser efficiency.",
                nextUnlock = "Level 2: +10% ore yield",
            },
            salvaging = {
                order = 20,
                label = "Salvaging",
                level = 1,
                xp = 0,
                xpRequired = 140,
                xpRate = 0,
                description = "Speeds up recovery of wreckage and boosts rare component chances.",
                nextUnlock = "Level 2: +12% salvage speed",
            },
        },
    },
}

local function normalize_level(levelData)
    if type(levelData) == "number" then
        return { current = levelData }
    elseif type(levelData) == "table" then
        local clone = deep_copy(levelData)
        if clone.current == nil then
            clone.current = 1
        end
        return clone
    end

    return nil
end

local function extract_currency_from_entity(entity)
    if not entity then
        return nil
    end

    local wallet = entity.wallet
    if type(wallet) == "table" then
        if type(wallet.balance) == "number" then
            return wallet.balance
        end
    elseif type(wallet) == "number" then
        return wallet
    end

    return nil
end

local function apply_currency_to_entity(state, entity)
    if not (state and entity) then
        return
    end

    local currency = state.playerCurrency

    local wallet = entity.wallet
    if type(wallet) ~= "table" then
        wallet = {}
        entity.wallet = wallet
    end

    wallet.balance = currency
end

local function ensure_player_currency(state, entity, defaultValue)
    if not state then
        return
    end

    if state.playerCurrency == nil then
        local derived = extract_currency_from_entity(entity)
            or defaultValue
        if derived == nil then
            derived = STARTING_CURRENCY
        end
        state.playerCurrency = derived
    end

    if entity then
        apply_currency_to_entity(state, entity)
    end
end

local function resolve_state_reference(context)
    if not context then
        return nil
    end

    if type(context.state) == "table" then
        return context.state
    end

    return context
end

function PlayerManager.getCurrency(context)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    if state.playerCurrency == nil then
        local ship = PlayerManager.getCurrentShip(state)
        if ship then
            ensure_player_currency(state, ship, nil)
        end
    end

    return state.playerCurrency
end

function PlayerManager.setCurrency(context, amount)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    local numericAmount = tonumber(amount)
    if not numericAmount then
        return state.playerCurrency
    end

    state.playerCurrency = numericAmount
    apply_currency_to_entity(state, PlayerManager.getCurrentShip(state))

    return numericAmount
end

function PlayerManager.adjustCurrency(context, delta)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    local change = tonumber(delta)
    if not change then
        return state.playerCurrency
    end

    local current = state.playerCurrency or 0
    return PlayerManager.setCurrency(state, current + change)
end

function PlayerManager.syncCurrency(context)
    local state = resolve_state_reference(context)
    if not state then
        return nil
    end

    ensure_player_currency(state, PlayerManager.getCurrentShip(state), nil)
    return state.playerCurrency
end

local function ensure_skills(pilot)
    if type(pilot) ~= "table" then
        return
    end

    pilot.skills = pilot.skills or {}

    for categoryId, defaults in pairs(DEFAULT_SKILLS) do
        local category = pilot.skills[categoryId]
        if type(category) ~= "table" then
            category = deep_copy(defaults)
            pilot.skills[categoryId] = category
        else
            category.label = category.label or defaults.label
            category.order = category.order or defaults.order
            category.skills = category.skills or {}

            for skillId, skillDefaults in pairs(defaults.skills or {}) do
                local skill = category.skills[skillId]
                if type(skill) ~= "table" then
                    skill = deep_copy(skillDefaults)
                    category.skills[skillId] = skill
                else
                    for key, defaultValue in pairs(skillDefaults) do
                        if skill[key] == nil then
                            if type(defaultValue) == "table" then
                                skill[key] = deep_copy(defaultValue)
                            else
                                skill[key] = defaultValue
                            end
                        end
                    end
                end

                skill.label = skill.label or skill.name or skillId
                skill.order = skill.order or skillDefaults.order or 0
                if type(skill.level) ~= "number" then
                    skill.level = skillDefaults.level or 1
                end
                if skill.level < 1 then
                    skill.level = 1
                end

                if type(skill.xp) ~= "number" then
                    skill.xp = skillDefaults.xp or 0
                end
                if skill.xp < 0 then
                    skill.xp = 0
                end

                if type(skill.xpRequired) ~= "number" then
                    skill.xpRequired = skillDefaults.xpRequired or 100
                end
                if skill.xpRequired <= 0 then
                    skill.xpRequired = skillDefaults.xpRequired or 100
                end
            end
        end
    end
end

local function resolve_skill(pilot, categoryId, skillId)
    if not pilot then
        return nil
    end

    ensure_skills(pilot)

    local categories = pilot.skills or {}
    local category = categories[categoryId]
    if not category then
        return nil
    end

    if type(category.skills) ~= "table" then
        category.skills = {}
    end

    local skill = category.skills[skillId]
    if type(skill) ~= "table" then
        category.skills[skillId] = nil
        return nil
    end

    return skill
end

function PlayerManager.ensurePilot(state, playerId)
    if not state then
        return nil
    end

    local pilot = state.playerPilot
    if not pilot then
        pilot = {
            playerPilot = true,
        }
        state.playerPilot = pilot
    end

    if playerId then
        pilot.playerId = playerId
    elseif not pilot.playerId then
        pilot.playerId = "player"
    end

    if type(pilot.level) ~= "table" then
        pilot.level = { current = 1 }
    else
        pilot.level.current = pilot.level.current or 1
    end

    ensure_skills(pilot)

    return pilot
end

local function resolve_player_id(state, playerId)
    if playerId then
        return playerId
    end

    if state and state.localPlayerId then
        return state.localPlayerId
    end

    return nil
end

function PlayerManager.addSkillXP(state, categoryId, skillId, amount, playerId)
    amount = tonumber(amount) or 0
    if not (state and categoryId and skillId) or amount <= 0 then
        return false
    end

    local resolvedPlayerId = resolve_player_id(state, playerId)
    local pilot = PlayerManager.ensurePilot(state, resolvedPlayerId)
    if not pilot then
        return false
    end

    local skill = resolve_skill(pilot, categoryId, skillId)
    if not skill then
        return false
    end

    local xpBefore = math.max(0, skill.xp or 0)
    local xpRequiredBefore = math.max(1, skill.xpRequired or 100)
    local levelBefore = math.max(1, skill.level or 1)

    skill.xp = math.max(0, xpBefore + amount)

    local leveledUp = false
    local level = levelBefore
    local xpRequired = xpRequiredBefore
    local levelsGained = 0

    while skill.xp >= xpRequired do
        skill.xp = skill.xp - xpRequired
        level = level + 1
        levelsGained = levelsGained + 1
        xpRequired = math.max(xpRequired + 50, math.floor(xpRequired * 1.25 + 0.5))
        leveledUp = true
    end

    skill.level = level
    skill.xpRequired = xpRequired

    local loveTimer = love and love.timer
    local timestamp = loveTimer and loveTimer.getTime and loveTimer.getTime() or os.time()

    if leveledUp then
        skill.lastLevelUpTime = timestamp
    end

    local levelData = pilot.level
    if type(levelData) ~= "table" then
        levelData = { current = level }
        pilot.level = levelData
    end

    levelData.current = math.max(1, level)
    levelData.experience = skill.xp
    levelData.max_experience = xpRequired
    levelData.next_level = xpRequired
    levelData.skill = skillId
    levelData.category = categoryId

    local progressBefore = 0
    if xpRequiredBefore > 0 then
        progressBefore = math.max(0, math.min(1, xpBefore / xpRequiredBefore))
    end

    local progressAfter = 0
    if xpRequired > 0 then
        progressAfter = math.max(0, math.min(1, skill.xp / xpRequired))
    end

    local progressTarget = progressAfter
    if levelsGained > 0 then
        progressTarget = levelsGained + progressAfter
    end

    local progressStartFinal = leveledUp and 0 or progressBefore

    local existingGain = type(levelData.lastGain) == "table" and levelData.lastGain or nil
    local now = timestamp
    local activeGain = nil
    if existingGain then
        local existingExpires = tonumber(existingGain.expiresAt or 0)
        if not existingExpires or existingExpires <= 0 then
            local baseTimestamp = tonumber(existingGain.timestamp or 0) or 0
            local baseDuration = tonumber(existingGain.duration or 0) or 0
            if baseTimestamp > 0 and baseDuration > 0 then
                existingExpires = baseTimestamp + baseDuration
            else
                existingExpires = nil
            end
        end

        if existingExpires and existingExpires > now then
            activeGain = existingGain
        end
    end

    local gain = activeGain or {}
    if gain ~= existingGain then
        levelData.lastGain = gain
    end

    local visibleDuration = leveledUp and 4.2 or 3.0
    local animationDuration = leveledUp and 1.6 or 1.05

    local createdAt = tonumber(gain.createdAt or gain.timestamp or 0) or 0
    if not activeGain or createdAt <= 0 then
        createdAt = now
        gain.sequence = 0
    else
        gain.sequence = (gain.sequence or 0) + 1
        createdAt = now
    end

    local expiresAt = now + visibleDuration

    gain.amount = amount
    gain.leveledUp = leveledUp
    gain.levelsGained = levelsGained
    gain.levelFrom = levelBefore
    gain.levelTo = level
    gain.progressFrom = progressBefore
    gain.progressTo = progressTarget
    gain.progressStart = progressStartFinal
    gain.progressEnd = progressAfter
    gain.xpBefore = xpBefore
    gain.xpAfter = skill.xp
    gain.xpRequiredBefore = xpRequiredBefore
    gain.xpRequiredAfter = xpRequired
    gain.skill = skill.label or skill.name or skillId
    gain.category = categoryId
    gain.createdAt = createdAt
    gain.animStart = now
    gain.animDuration = animationDuration
    gain.visibleDuration = visibleDuration
    gain.expiresAt = expiresAt
    gain.timestamp = createdAt
    gain.duration = visibleDuration
    gain.lastUpdate = now

    return true, leveledUp
end

function PlayerManager.applyLevel(state, levelData, playerId)
    local pilot = PlayerManager.ensurePilot(state, playerId)
    if not pilot then
        return nil
    end

    local normalized = normalize_level(levelData)
    if normalized then
        pilot.level = normalized
    elseif type(pilot.level) ~= "table" then
        pilot.level = { current = 1 }
    else
        pilot.level.current = pilot.level.current or 1
    end

    ensure_skills(pilot)

    return pilot
end

function PlayerManager.attachShip(state, shipEntity, levelData, playerId)
    if not (state and shipEntity) then
        return shipEntity
    end

    state.players = state.players or {}

    local resolvedPlayerId = playerId
        or shipEntity.playerId
        or state.localPlayerId
        or "player"

    shipEntity.playerId = resolvedPlayerId

    for id, entity in pairs(state.players) do
        if entity == shipEntity and id ~= resolvedPlayerId then
            state.players[id] = nil
        end
    end
    state.players[resolvedPlayerId] = shipEntity

    local existingLocalShip = PlayerManager.getCurrentShip(state)
    local hasLocalId = state.localPlayerId ~= nil
    local isLocalPlayer = (existingLocalShip == shipEntity)
        or (hasLocalId and state.localPlayerId == resolvedPlayerId)
        or (not hasLocalId and existingLocalShip == nil)

    shipEntity.player = true

    if isLocalPlayer then
        state.localPlayerId = resolvedPlayerId

        local pilot = PlayerManager.applyLevel(state, levelData, resolvedPlayerId)
        shipEntity.level = nil
        shipEntity.pilot = pilot

        if pilot then
            pilot.playerId = resolvedPlayerId
            pilot.currentShip = shipEntity
        end

        state.playerShip = shipEntity
        state.player = shipEntity

        ensure_player_currency(state, shipEntity, STARTING_CURRENCY)
    else
        shipEntity.pilot = nil
        if levelData then
            shipEntity.level = deep_copy(levelData)
        end
    end

    if shipEntity then
        PlayerWeapons.initialize(shipEntity)
    end

    return shipEntity
end

function PlayerManager.getPilot(state)
    if not state then
        return nil
    end
    return state.playerPilot
end

function PlayerManager.getCurrentShip(state)
    if not state then
        return nil
    end

    local pilot = state.playerPilot
    if pilot and pilot.currentShip then
        return pilot.currentShip
    end

    return state.playerShip or state.player
end

function PlayerManager.clearShip(state, shipEntity)
    if not state then
        return
    end

    local pilot = state.playerPilot
    local currentShip = pilot and pilot.currentShip or state.playerShip or state.player

    local target = shipEntity or currentShip
    if pilot and (not shipEntity or pilot.currentShip == shipEntity) then
        pilot.currentShip = nil
    end

    if target then
        if target.pilot == pilot then
            target.pilot = nil
        end
        if state.playerShip == target then
            state.playerShip = nil
        end
        if state.player == target then
            state.player = nil
        end
        if state.players then
            for id, entity in pairs(state.players) do
                if entity == target then
                    state.players[id] = nil
                end
            end
        end
    else
        state.playerShip = nil
        state.player = nil
        state.players = nil
    end
end

-- Consolidated player resolution methods

function PlayerManager.getLocalPlayer(state)
    if not state then
        return nil
    end

    -- Primary: Use PlayerManager's current ship
    local ship = PlayerManager.getCurrentShip(state)
    if ship then
        -- Ensure state.player is synchronized
        state.player = ship
        return ship
    end

    -- Fallback 1: Check players table with localPlayerId
    if state.players and state.localPlayerId then
        local localPlayer = state.players[state.localPlayerId]
        if localPlayer then
            PlayerManager.attachShip(state, localPlayer)
            return localPlayer
        end
    end

    -- Fallback 2: Find any player in players table
    if state.players then
        for _, entity in pairs(state.players) do
            if entity then
                PlayerManager.attachShip(state, entity)
                return entity
            end
        end
    end

    return nil
end

function PlayerManager.resolveLocalPlayer(context)
    if not context then
        return nil
    end

    -- Direct player reference
    if context.player then
        return context.player
    end

    -- Context has getLocalPlayer method (like gameplay state)
    if type(context.getLocalPlayer) == "function" then
        return context:getLocalPlayer()
    end

    -- Context has a state property
    local state = context.state or context
    if state then
        return PlayerManager.getLocalPlayer(state)
    end

    return nil
end

function PlayerManager.collectAllPlayers(state)
    local players = {}
    
    if not state then
        return players
    end

    -- Collect from players table
    if state.players then
        for playerId, entity in pairs(state.players) do
            if entity and entity.playerId then
                players[playerId] = entity
            end
        end
    end

    -- Ensure local player is included
    local localShip = PlayerManager.getCurrentShip(state)
    if localShip and localShip.playerId then
        players[localShip.playerId] = localShip
    elseif state.player and state.player.playerId then
        players[state.player.playerId] = state.player
    end

    return players
end

function PlayerManager.getPlayerById(state, playerId)
    if not (state and playerId) then
        return nil
    end

    -- Check players table first
    if state.players and state.players[playerId] then
        return state.players[playerId]
    end

    -- Check if it's the local player
    local localPlayer = PlayerManager.getLocalPlayer(state)
    if localPlayer and localPlayer.playerId == playerId then
        return localPlayer
    end

    return nil
end

return PlayerManager
