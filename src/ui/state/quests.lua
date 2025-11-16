-- Quest Management
-- Handles station quest generation, tracking, and state synchronization

local core = require("src.ui.state.core")
local QuestGenerator = require("src.stations.quest_generator")

local resolve_state_pair = core.resolve_state_pair

local Quests = {}

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

function Quests.refresh(state)
    local resolved = resolve_state_pair(state)
    if not resolved then
        return
    end

    regenerate_station_quests(resolved)
end

function Quests.ensure(state)
    local resolved = resolve_state_pair(state)
    if not (resolved and resolved.stationUI) then
        return
    end

    local stationUI = resolved.stationUI
    local station = resolved.stationDockTarget
    local signature = resolve_station_signature(station)

    if not stationUI.quests or stationUI._lastStationSignature ~= signature then
        regenerate_station_quests(resolved)
    end
end

return Quests
