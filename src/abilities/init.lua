---Ability system initialization
---Registers all ability behaviors and provides easy access

local BehaviorRegistry = require("src.abilities.behavior_registry")

local function auto_register_behaviors(directory, namespace)
    if not (love and love.filesystem and love.filesystem.getDirectoryItems and love.filesystem.getInfo) then
        return
    end

    local files = love.filesystem.getDirectoryItems(directory)
    if not files then
        return
    end

    for _, filename in ipairs(files) do
        if filename:sub(-4) == ".lua" then
            local info = love.filesystem.getInfo(directory .. "/" .. filename)
            if info and info.type == "file" then
                local basename = filename:sub(1, -5)
                if basename ~= "init" and not basename:match("^base_") then
                    local moduleName = string.format("%s.%s", namespace, basename)
                    local ok, behavior = pcall(require, moduleName)
                    if ok and type(behavior) == "table" then
                        local key = behavior.key or behavior.id or behavior.constantKey or basename
                        if type(key) == "string" and key ~= "" then
                            BehaviorRegistry:register(key, behavior)
                        end
                    end
                end
            end
        end
    end
end

-- Base behaviors
local base_afterburner = require("src.abilities.behaviors.base_afterburner")
local base_dash = require("src.abilities.behaviors.base_dash")
local base_temporal_field = require("src.abilities.behaviors.base_temporal_field")

-- Register fallbacks for backward compatibility
BehaviorRegistry:registerFallback("afterburner", {
    update = base_afterburner.update,
    activate = base_afterburner.activate,
    deactivate = base_afterburner.deactivate,
})

BehaviorRegistry:registerFallback("dash", {
    update = base_dash.update,
    activate = base_dash.activate,
    deactivate = base_dash.deactivate,
})

BehaviorRegistry:registerFallback("temporal_field", {
    update = base_temporal_field.update,
    activate = base_temporal_field.activate,
    deactivate = base_temporal_field.deactivate,
})

auto_register_behaviors("src/abilities/behaviors", "src.abilities.behaviors")

return {
    BehaviorRegistry = BehaviorRegistry,
    base_afterburner = base_afterburner,
    base_dash = base_dash,
    base_temporal_field = base_temporal_field,
}
