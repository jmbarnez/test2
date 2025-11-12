-- PlayerSkills: Manages player skill progression, XP, and leveling
-- Handles skill trees, experience gain, level-ups, and skill state

local table_util = require("src.util.table")
local deep_copy = table_util.deep_copy

---@diagnostic disable-next-line: undefined-global
local love = love

local PlayerSkills = {}

-- Default skill tree structure
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

--- Normalizes level data from various formats
---@param levelData number|table|nil The level data to normalize
---@return table|nil Normalized level table with 'current' field
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

--- Ensures a pilot has a complete skill tree structure
---@param pilot table The pilot data to ensure skills for
function PlayerSkills.ensureSkillTree(pilot)
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
                    -- Fill in missing fields from defaults
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

                -- Ensure skill integrity
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

--- Resolves a specific skill from the pilot's skill tree
---@param pilot table The pilot data
---@param categoryId string The skill category ID
---@param skillId string The skill ID within the category
---@return table|nil The skill data, or nil if not found
local function resolve_skill(pilot, categoryId, skillId)
    if not pilot then
        return nil
    end

    PlayerSkills.ensureSkillTree(pilot)

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

--- Adds experience points to a skill and handles level-ups
---@param pilot table The pilot data
---@param categoryId string The skill category ID
---@param skillId string The skill ID
---@param amount number The amount of XP to add
---@return boolean success Whether XP was added successfully
---@return boolean leveledUp Whether the skill leveled up
function PlayerSkills.addXP(pilot, categoryId, skillId, amount)
    amount = tonumber(amount) or 0
    if not (pilot and categoryId and skillId) or amount <= 0 then
        return false, false
    end

    local skill = resolve_skill(pilot, categoryId, skillId)
    if not skill then
        return false, false
    end

    local xpBefore = math.max(0, skill.xp or 0)
    local xpRequiredBefore = math.max(1, skill.xpRequired or 100)
    local levelBefore = math.max(1, skill.level or 1)

    skill.xp = math.max(0, xpBefore + amount)

    local leveledUp = false
    local level = levelBefore
    local xpRequired = xpRequiredBefore
    local levelsGained = 0

    -- Handle cascading level-ups
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

    -- Update pilot's level data for UI display
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

    -- Calculate progress bars for animation
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

    -- Create/update XP gain notification data
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

    -- Populate gain notification data
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

--- Gets a specific skill's data
---@param pilot table The pilot data
---@param categoryId string The skill category ID
---@param skillId string The skill ID
---@return table|nil The skill data
function PlayerSkills.getSkill(pilot, categoryId, skillId)
    return resolve_skill(pilot, categoryId, skillId)
end

--- Applies level data to a pilot
---@param pilot table The pilot data
---@param levelData number|table|nil The level data to apply
---@return table|nil The pilot data
function PlayerSkills.applyLevel(pilot, levelData)
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

    PlayerSkills.ensureSkillTree(pilot)

    return pilot
end

return PlayerSkills
