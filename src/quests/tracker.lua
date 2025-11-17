local constants = require("src.constants.game")
local PlayerManager = require("src.player.manager")
local notifications = require("src.ui.notifications")
local table_util = require("src.util.table")

local QuestTracker = {}

local function ensure_active_map(state)
    if not (state and state.stationUI) then
        return nil
    end

    local ui = state.stationUI
    if type(ui.activeQuestIds) ~= "table" then
        ui.activeQuestIds = {}
    end

    return ui.activeQuestIds
end

local function iter_active_quests(state)
    if not (state and state.stationUI) then
        return {}
    end

    local quests = state.stationUI.quests or {}
    local activeIds = ensure_active_map(state)

    if not activeIds then
        return {}
    end

    local active = {}
    for i = 1, #quests do
        local quest = quests[i]
        local id = quest and quest.id
        if id and activeIds[id] then
            quest.accepted = true
            quest.progress = quest.progress or 0
            active[#active + 1] = quest
        end
    end

    return active
end

--- Increments quest progress for a specific quest type
---@param state table
---@param quest_type string "mining" or "hunting"
---@param amount number
local function increment_progress(state, quest_type, amount)
    local active = iter_active_quests(state)
    if #active == 0 then
        return
    end

    local delta = amount or 1
    local completed = nil

    for i = 1, #active do
        local quest = active[i]
        if quest and quest.type == quest_type then
            quest.progress = (quest.progress or 0) + delta
            if quest.progress >= quest.target then
                completed = completed or {}
                completed[#completed + 1] = quest
            end
        end
    end

    if completed then
        for i = 1, #completed do
            QuestTracker.complete(state, completed[i])
        end
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

    local ui_constants = (constants.ui and constants.ui.notifications and constants.ui.notifications.quest_complete) or {}
    notifications.push(state, {
        text = string.format("Quest Complete: %s (+%d credits)", quest.title, credits),
        icon = "quest",
        accent = ui_constants.accent or { 0.3, 0.78, 0.46, 1 },
        duration = ui_constants.duration or 3.5,
    })
    local ui = state.stationUI
    if ui then
        local activeIds = ensure_active_map(state)
        if activeIds and quest.id then
            activeIds[quest.id] = nil
        end

        if type(ui.quests) == "table" then
            for i = #ui.quests, 1, -1 do
                local entry = ui.quests[i]
                if entry and entry.id == quest.id then
                    table.remove(ui.quests, i)
                    break
                end
            end

            if ui.selectedQuestId == quest.id then
                ui.selectedQuestId = ui.quests[1] and ui.quests[1].id or nil
            end
        end
    end
end

function QuestTracker.serialize(state)
    local ui = state and state.stationUI
    if not ui then
        return nil
    end

    local snapshot = {
        quests = ui.quests and table_util.deep_copy(ui.quests) or nil,
        selectedQuestId = ui.selectedQuestId,
        activeQuestId = ui.activeQuestId,
        activeQuestIds = ui.activeQuestIds and table_util.deep_copy(ui.activeQuestIds) or nil,
    }

    local hasData = (snapshot.quests and #snapshot.quests > 0)
        or snapshot.selectedQuestId ~= nil
        or snapshot.activeQuestId ~= nil
        or (snapshot.activeQuestIds and next(snapshot.activeQuestIds) ~= nil)

    if not hasData then
        return nil
    end

    return snapshot
end

function QuestTracker.restore(state, data)
    if not (state and data and type(data) == "table") then
        return
    end

    state.stationUI = state.stationUI or {}
    local ui = state.stationUI
    ui.quests = table_util.deep_copy(data.quests or {})
    ui.selectedQuestId = data.selectedQuestId
    ui.activeQuestIds = table_util.deep_copy(data.activeQuestIds or {})
    if type(ui.activeQuestIds) ~= "table" then
        ui.activeQuestIds = {}
    end
    ui.activeQuestId = data.activeQuestId

    local function pick_fallback_tracked()
        if type(ui.activeQuestIds) ~= "table" then
            ui.activeQuestId = nil
            return
        end

        for i = 1, #ui.quests do
            local quest = ui.quests[i]
            local id = quest and quest.id
            if id and ui.activeQuestIds[id] then
                ui.activeQuestId = id
                return
            end
        end

        ui.activeQuestId = nil
    end

    for i = 1, #ui.quests do
        local quest = ui.quests[i]
        local id = quest and quest.id
        if id and ui.activeQuestIds[id] then
            quest.accepted = true
            quest.progress = quest.progress or 0
        else
            quest.accepted = nil
        end
    end

    if ui.activeQuestId and not ui.activeQuestIds[ui.activeQuestId] then
        pick_fallback_tracked()
    elseif not ui.activeQuestId then
        pick_fallback_tracked()
    end
end

return QuestTracker
