--- Quest Tracker: Manages active quest progress and completion
local PlayerManager = require("src.player.manager")
local notifications = require("src.ui.notifications")

local QuestTracker = {}

--- Gets the active quest from state
---@param state table
---@return table|nil
local function get_active_quest(state)
    if not (state and state.stationUI and state.stationUI.activeQuestId) then
        return nil
    end

    local active_id = state.stationUI.activeQuestId
    local quests = state.stationUI.quests or {}

    for i = 1, #quests do
        local quest = quests[i]
        if quest and quest.id == active_id then
            return quest
        end
    end

    return nil
end

--- Increments quest progress for a specific quest type
---@param state table
---@param quest_type string "mining" or "hunting"
---@param amount number
local function increment_progress(state, quest_type, amount)
    local quest = get_active_quest(state)
    if not quest then
        return
    end

    if quest.type ~= quest_type then
        return
    end

    quest.progress = (quest.progress or 0) + (amount or 1)

    -- Check for completion
    if quest.progress >= quest.target then
        QuestTracker.complete(state, quest)
    end
end

--- Called when an asteroid is destroyed by the player
---@param state table
function QuestTracker.onAsteroidDestroyed(state)
    increment_progress(state, "mining", 1)
end

--- Called when an enemy is destroyed by the player
---@param state table
function QuestTracker.onEnemyDestroyed(state)
    increment_progress(state, "hunting", 1)
end

--- Completes a quest and awards the reward
---@param state table
---@param quest table
function QuestTracker.complete(state, quest)
    if not (state and quest) then
        return
    end

    local credits = quest.rewardCredits or 0
    if credits > 0 then
        PlayerManager.adjustCurrency(state, credits)
    end

    notifications.push(state, {
        text = string.format("Quest Complete: %s (+%d credits)", quest.title, credits),
        icon = "quest",
        accent = { 0.3, 0.78, 0.46, 1 },
        duration = 3.5,
    })

    -- Clear active quest
    if state.stationUI then
        state.stationUI.activeQuestId = nil
    end
end

return QuestTracker
