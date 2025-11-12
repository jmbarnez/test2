local StatusPanel = require("src.hud.status_panel")
local ExperiencePanel = require("src.hud.experience_panel")
local Minimap = require("src.hud.minimap")
local Diagnostics = require("src.hud.diagnostics")
local WeaponPanel = require("src.hud.weapon_panel")
local TargetPanel = require("src.hud.target_panel")

local Hud = {}

function Hud.draw(context, player)
    StatusPanel.draw(player)
    ExperiencePanel.draw(context, player)
    TargetPanel.draw(context, player)
    Minimap.draw(context, player)
    Diagnostics.draw(context, player)
    WeaponPanel.draw(context, player)
end

return Hud
