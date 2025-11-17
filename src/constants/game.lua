-- ============================================================================
-- GAME CONSTANTS
-- ============================================================================
-- Central configuration file for all game-wide constants and settings.
-- This file defines parameters for rendering, physics, world generation,
-- and gameplay mechanics. Entity-specific defaults belong in their blueprints.
-- ============================================================================
local constants = {}

local function safe_require(module_name)
    local ok, module = pcall(require, module_name)
    if ok and type(module) == "table" then
        return module
    end
    return nil
end

local mappings = {
    love = "src.constants.love_config",
    window = "src.constants.window",
    view = "src.constants.view",
    physics = "src.constants.physics",
    world = "src.constants.world",
    asteroids = "src.constants.asteroids",
    player = "src.constants.player",
    enemies = "src.constants.enemies",
    ui = "src.constants.ui",
    render = "src.constants.render",
    stars = "src.constants.stars",
    damage = "src.constants.damage",
    economy = "src.constants.economy",
    progression = "src.constants.progression",
    audio = "src.constants.audio",
    performance = "src.constants.performance",
    debug = "src.constants.debug",
    quests = "src.constants.quests",
}

for key, module_name in pairs(mappings) do
    constants[key] = safe_require(module_name)
end

return constants
