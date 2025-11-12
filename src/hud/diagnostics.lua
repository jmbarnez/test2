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
    local acceleration = 0
    local position = { x = 0, y = 0 }
    local angle = 0
    local angular_velocity = 0
    
    if player and player.body then
        local vx, vy = player.body:getLinearVelocity()
        speed = vector.length(vx, vy)
        
        -- Get acceleration from velocity change
        local prev_vx = player.prev_vx or vx
        local prev_vy = player.prev_vy or vy
        local dt = love.timer.getDelta()
        if dt > 0 then
            local ax = (vx - prev_vx) / dt
            local ay = (vy - prev_vy) / dt
            acceleration = vector.length(ax, ay)
        end
        player.prev_vx = vx
        player.prev_vy = vy
        
        position.x, position.y = player.body:getPosition()
        angle = player.body:getAngle()
        angular_velocity = player.body:getAngularVelocity()
    end

    local fps = love.timer.getFPS()
    local dt = love.timer.getDelta()
    local memory_usage = collectgarbage("count")
    local graphics_stats = love.graphics.getStats()

    -- Core metrics
    lines[#lines + 1] = string.format("FPS: %d (%.2fms)", fps, dt * 1000)
    lines[#lines + 1] = string.format("Memory: %.1f KB", memory_usage)
    
    -- Player diagnostics
    lines[#lines + 1] = string.format("Speed: %.1f px/s", speed)
    lines[#lines + 1] = string.format("Accel: %.1f px/s²", acceleration)
    lines[#lines + 1] = string.format("Pos: (%.0f, %.0f)", position.x, position.y)
    lines[#lines + 1] = string.format("Angle: %.1f° (%.2f rad/s)", math.deg(angle), angular_velocity)
    
    -- Graphics diagnostics
    lines[#lines + 1] = string.format("Draw calls: %d", graphics_stats.drawcalls)
    lines[#lines + 1] = string.format("Texture mem: %.1f KB", graphics_stats.texturememory / 1024)
    
    -- System diagnostics
    lines[#lines + 1] = string.format("Canvas switches: %d", graphics_stats.canvasswitches)
    lines[#lines + 1] = string.format("Shader switches: %d", graphics_stats.shaderswitches)

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
