local StatusPanel = require("src.hud.status_panel")
local ExperiencePanel = require("src.hud.experience_panel")
local Minimap = require("src.hud.minimap")
local Hotbar = require("src.hud.hotbar")
local TargetPanel = require("src.hud.target_panel")
local AbilityPanel = require("src.hud.ability_panel")
local StationPrompt = require("src.hud.station_prompt")
local QuestOverlay = require("src.hud.quest_overlay")

local Hud = {}

function Hud.draw(context, player)
    StatusPanel.draw(player)
    ExperiencePanel.draw(context, player)
    TargetPanel.draw(context, player)
    local minimap_rect = Minimap.draw(context, player)
    if minimap_rect then
        QuestOverlay.draw(context, minimap_rect)
    end
    Hotbar.draw(context, player)
    AbilityPanel.draw(context, player)
    StationPrompt.draw(context, player)
end

return Hud
