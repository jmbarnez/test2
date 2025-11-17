---Weapon behavior system initialization
---Registers fallback behaviors for backward compatibility with fireMode
local BehaviorRegistry = require("src.weapons.behavior_registry")
local base_hitscan = require("src.weapons.behaviors.base_hitscan")
local base_projectile = require("src.weapons.behaviors.base_projectile")
local base_cloud = require("src.weapons.behaviors.base_cloud")

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

-- Register fallback behaviors for fireMode compatibility
-- This allows weapons without registered behaviors to still work
BehaviorRegistry:registerFallback("hitscan", base_hitscan)
BehaviorRegistry:registerFallback("projectile", base_projectile)
BehaviorRegistry:registerFallback("cloud", base_cloud)

auto_register_behaviors("src/weapons/behaviors", "src.weapons.behaviors")

return BehaviorRegistry
