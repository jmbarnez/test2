local theme = require("src.ui.theme")
local vector = require("src.util.vector")

---@diagnostic disable-next-line: undefined-global
local love = love

local hud_colors = theme.colors.hud

local Diagnostics = {}

local LINE_SPACING = 4

local function build_lines(context, player)
    local lines = {}

    local speed = 0
    if player and player.body then
        local vx, vy = player.body:getLinearVelocity()
        speed = vector.length(vx, vy)
    end

    local fps = love.timer.getFPS()

    lines[#lines + 1] = string.format("Speed: %.1f px/s", speed)
    lines[#lines + 1] = string.format("FPS: %d", fps)

    if context and context.performanceStats then
        for _, entry in ipairs(context.performanceStats) do
            lines[#lines + 1] = tostring(entry)
        end
    end

    return lines
end

function Diagnostics.draw(context, player)
    local lines = build_lines(context, player)
    if #lines == 0 then
        return
    end

    local screenWidth = love.graphics.getWidth()
    local minimap_size = 120
    local margin = 20
    local x = screenWidth - minimap_size - margin
    local y = margin + minimap_size + 10

    local fonts = theme.get_fonts()
    local font = fonts.small or love.graphics.getFont()
    local lineHeight = font:getHeight() + LINE_SPACING

    love.graphics.setFont(font)
    love.graphics.setColor(hud_colors.diagnostics or { 0.68, 0.78, 0.92, 1 })

    for i = 1, #lines do
        love.graphics.print(lines[i], x, y + (i - 1) * lineHeight)
    end
end

return Diagnostics
