--- Quest Generator: Produces simple, generic credit-only station contracts

---@diagnostic disable-next-line: undefined-global
local love = love

local QuestGenerator = {}

local DEFAULT_CONTRACTS = {
    {
        id = "mining_operation",
        title = "Mining Operation",
        objective = "Destroy asteroids to clear the sector.",
        summary = "The station needs raw materials. Destroy asteroids in the area to extract ore and minerals.",
        credits = 500,
        type = "mining",
        target = 5,
    },
    {
        id = "heavy_mining",
        title = "Heavy Mining Contract",
        objective = "Destroy a large number of asteroids.",
        summary = "A major construction project requires substantial mineral resources. Clear out asteroid fields.",
        credits = 1200,
        type = "mining",
        target = 12,
    },
    {
        id = "hostile_elimination",
        title = "Hostile Elimination",
        objective = "Destroy enemy ships threatening the station.",
        summary = "Raiders have been spotted in the sector. Eliminate hostile vessels to secure the area.",
        credits = 800,
        type = "hunting",
        target = 3,
    },
    {
        id = "sector_defense",
        title = "Sector Defense",
        objective = "Eliminate multiple enemy threats.",
        summary = "A large enemy force is approaching. Destroy hostile ships to defend the station perimeter.",
        credits = 1500,
        type = "hunting",
        target = 6,
    },
}

local function pick_random_index(max)
    if love and love.math and love.math.random then
        return love.math.random(1, max)
    end
    return math.random(1, max)
end

local function duplicate_contract(template, suffix)
    return {
        id = string.format("%s_%d", template.id, suffix),
        title = template.title,
        objective = template.objective,
        summary = template.summary,
        rewardCredits = template.credits,
        type = template.type,
        target = template.target,
        progress = 0,
    }
end

--- Generates a table of quest offers for the supplied station.
---@param context table
---@param station table
---@param options table|nil
---@return table quests
function QuestGenerator.generate(context, station, options)
    options = options or {}
    local desired = math.max(1, math.floor(options.count or 3))
    local quests = {}
    local remaining = {}

    for i = 1, #DEFAULT_CONTRACTS do
        remaining[i] = i
    end

    local contract_count = math.min(desired, #DEFAULT_CONTRACTS)
    for i = 1, contract_count do
        local pick = pick_random_index(#remaining)
        local template_index = remaining[pick]
        local template = DEFAULT_CONTRACTS[template_index]
        remaining[pick] = remaining[#remaining]
        remaining[#remaining] = nil

        quests[#quests + 1] = duplicate_contract(template, pick_random_index(9000) + 999)
    end

    return quests
end

--- Formats a human-readable reward string for UI display.
---@param quest table
---@return string
function QuestGenerator.rewardLabel(quest)
    if not quest then
        return ""
    end

    local credits = quest.rewardCredits or 0
    if credits <= 0 then
        return ""
    end

    return string.format("%d credits", credits)
end

--- Formats quest progress for UI display.
---@param quest table
---@return string
function QuestGenerator.progressLabel(quest)
    if not quest then
        return ""
    end

    local progress = quest.progress or 0
    local target = quest.target or 0
    if target <= 0 then
        return ""
    end

    return string.format("%d / %d", progress, target)
end

return QuestGenerator
