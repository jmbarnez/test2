local StatusPanel = require("src.hud.status_panel")
local ExperiencePanel = require("src.hud.experience_panel")
local CurrencyPanel = require("src.hud.currency_panel")
local Minimap = require("src.hud.minimap")
local WeaponPanel = require("src.hud.weapon_panel")
local TargetPanel = require("src.hud.target_panel")
local AbilityPanel = require("src.hud.ability_panel")
local StationPrompt = require("src.hud.station_prompt")

local Hud = {}

function Hud.draw(context, player)
    StatusPanel.draw(player)
    ExperiencePanel.draw(context, player)
    CurrencyPanel.draw(context)
    TargetPanel.draw(context, player)
    Minimap.draw(context, player)
    WeaponPanel.draw(context, player)
    AbilityPanel.draw(context, player)
    StationPrompt.draw(context, player)
end

return Hud
