--- Quest Generator: Produces simple, generic credit-only station contracts

---@diagnostic disable-next-line: undefined-global
local love = love

local QuestGenerator = {}

local DEFAULT_CONTRACTS = {
    {
        id = "station_patrol",
        title = "Station Patrol",
        objective = "Destroy hostile ships that threaten the docking perimeter.",
        summary = "Assist station security by patrolling the nearby sector and eliminating raiders you encounter.",
        credits = 750,
    },
    {
        id = "salvage_run",
        title = "Salvage Run",
        objective = "Recover valuable scrap from defeated enemies or derelict hulks.",
        summary = "Collect salvageable materials in the sector and return them to the station quartermaster.",
        credits = 620,
    },
    {
        id = "trade_escort",
        title = "Escort Traders",
        objective = "Guard civilian haulers while they depart the station.",
        summary = "Provide covering fire for outbound freighters until the area is clear of immediate threats.",
        credits = 680,
    },
    {
        id = "asteroid_clearance",
        title = "Asteroid Clearance",
        objective = "Break apart hazardous asteroids drifting near traffic lanes.",
        summary = "Use ship weapons to fracture nearby asteroids so that shuttle traffic remains safe.",
        credits = 540,
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
    }
end

--- Generates a table of quest offers for the supplied station.
---@param _ context table
---@param _ station table
---@param options table|nil
---@return table quests
function QuestGenerator.generate(_, _, options)
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

return QuestGenerator
