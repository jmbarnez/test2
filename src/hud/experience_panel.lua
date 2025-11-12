local theme = require("src.ui.theme")
local Util = require("src.hud.util")
local PlayerManager = require("src.player.manager")

---@diagnostic disable-next-line: undefined-global
local love = love

local ExperiencePanel = {}

local function get_time()
    local loveTimer = love and love.timer
    if loveTimer and loveTimer.getTime then
        return loveTimer.getTime()
    end
    return os.time()
end

local function ease_out_cubic(t)
    t = Util.clamp01(t or 0)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function resolve_gain(state)
    if not state then
        return nil
    end

    local pilot = state.playerPilot
        or PlayerManager.getPilot(state)
        or PlayerManager.ensurePilot(state)

    if not (pilot and type(pilot.level) == "table") then
        return nil
    end

    local level = pilot.level
    local gain = level.lastGain

    if type(gain) ~= "table" then
        return nil
    end

    local now = get_time()
    local createdAt = tonumber(gain.createdAt or gain.timestamp or 0) or 0
    local visibleDuration = tonumber(gain.visibleDuration or gain.duration or 0) or 0
    local expiresAt = tonumber(gain.expiresAt or 0) or 0

    if expiresAt <= 0 then
        if createdAt > 0 and visibleDuration > 0 then
            expiresAt = createdAt + visibleDuration
        elseif gain.timestamp then
            local baseDuration = tonumber(gain.duration or 0) or 0
            if baseDuration > 0 then
                expiresAt = (tonumber(gain.timestamp) or 0) + baseDuration
            end
        end
    end

    if expiresAt > 0 and now >= expiresAt then
        level.lastGain = nil
        return nil
    end

    return gain
end

function ExperiencePanel.draw(context, player)
    context = context or {}
    local state = context.state or context

    local gain = resolve_gain(state)
    if not gain then
        return
    end

    local fonts = theme.get_fonts()
    if not fonts then
        return
    end

    local hud_colors = theme.colors.hud or {}
    local palette = theme.palette or {}
    local spacing = theme.spacing or {}
    local set_color = theme.utils.set_color

    local now = get_time()
    local createdAt = tonumber(gain.createdAt or gain.timestamp or 0) or 0
    if createdAt <= 0 then
        createdAt = now
    end

    local visibleDuration = tonumber(gain.visibleDuration or gain.duration or 0) or 3.0
    if visibleDuration <= 0 then
        visibleDuration = 3.0
    end

    local animStart = tonumber(gain.animStart or createdAt) or createdAt
    local animDuration = tonumber(gain.animDuration or 0) or 1.05
    if animDuration <= 0 then
        animDuration = 1.05
    end

    local animElapsed = now - animStart
    local t = Util.clamp01(animElapsed / animDuration)
    local eased = ease_out_cubic(t)

    local elapsedSinceCreate = now - createdAt
    local alpha = 1
    if visibleDuration > 0 then
        local fadeWindow = math.min(0.75, visibleDuration * 0.35)
        local fadeStart = visibleDuration - fadeWindow
        if fadeStart < 0 then
            fadeStart = 0
        end
        if elapsedSinceCreate >= fadeStart then
            local fadeT = Util.clamp01((elapsedSinceCreate - fadeStart) / math.max(fadeWindow, 0.0001))
            alpha = 1 - fadeT
        end
    end
    alpha = math.max(0, math.min(1, alpha))

    local progressStart = Util.clamp01(gain.progressStart or gain.progressFrom or 0)
    local progressEnd = Util.clamp01(gain.progressEnd or gain.progressTo or 0)
    local progress = progressStart + (progressEnd - progressStart) * eased
    progress = Util.clamp01(progress)

    local levelFrom = math.max(1, math.floor((gain.levelFrom or 1) + 0.5))
    local levelTo = math.max(levelFrom, math.floor((gain.levelTo or levelFrom) + 0.5))
    local leveledUp = gain.leveledUp and levelTo > levelFrom

    local skillLabel = gain.skill or "Skill"
    local xpAfter = math.max(0, math.floor((gain.xpAfter or 0) + 0.5))
    local xpRequired = math.max(1, math.floor((gain.xpRequiredAfter or gain.xpRequiredBefore or 100) + 0.5))
    local xpAmount = math.floor((gain.amount or 0) + 0.5)

    local width = 240
    local height = 84
    local padding = math.min(10, spacing.window_padding or 10)
    local screenWidth = love.graphics.getWidth()

    local minimapDiameter = 120
    local minimapMargin = 24
    local gap = 16
    local minimapLeft = screenWidth - minimapDiameter - minimapMargin
    local baseY = 28
    local offsetY = (1 - eased) * 20
    local x = minimapLeft - width - gap
    if x < minimapMargin then
        x = minimapMargin
    end
    local y = baseY - offsetY

    love.graphics.push("all")
    love.graphics.origin()

    love.graphics.setColor(0, 0, 0, 0.28 * alpha)
    love.graphics.rectangle("fill", x, y + 2, width, height)

    local panelColor = hud_colors.status_panel or { 0.05, 0.06, 0.09, 0.95 }
    set_color({ panelColor[1], panelColor[2], panelColor[3], (panelColor[4] or 1) * alpha })
    love.graphics.rectangle("fill", x, y, width, height)

    local borderColor = hud_colors.status_border or { 0.2, 0.26, 0.34, 0.9 }
    love.graphics.setLineWidth(1)
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * alpha)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)

    local textColor = hud_colors.status_text or { 0.85, 0.89, 0.93, 1 }
    local mutedColor = hud_colors.status_muted or { 0.46, 0.52, 0.58, 1 }
    local accent = palette.accent or { 0.46, 0.64, 0.72, 1 }

    local cursorY = y + padding
    local textX = x + padding
    local textWidth = width - padding * 2

    local titleFont = fonts.body or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)

    local title
    if leveledUp then
        title = string.format("%s Level Up", skillLabel)
    else
        title = string.format("%s Progress", skillLabel)
    end
    love.graphics.printf(title, textX, cursorY, textWidth, "left")

    cursorY = cursorY + titleFont:getHeight() + 4

    local metaFont = fonts.small or titleFont
    love.graphics.setFont(metaFont)
    love.graphics.setColor(mutedColor[1], mutedColor[2], mutedColor[3], alpha)

    local amountPrefix = xpAmount >= 0 and "+" or ""
    local amountText = string.format("%s%d XP", amountPrefix, xpAmount)

    local leftMeta
    if leveledUp then
        leftMeta = string.format("Lv %d → %d", levelFrom, levelTo)
    else
        local targetPercent = math.floor(Util.clamp01(gain.progressEnd or progressEnd or 0) * 100 + 0.5)
        leftMeta = string.format("%d%% to next", math.max(0, targetPercent))
    end

    love.graphics.print(leftMeta, textX, cursorY)
    love.graphics.printf(amountText, textX, cursorY, textWidth, "right")

    cursorY = cursorY + metaFont:getHeight() + 6

    local barHeight = 10
    local barWidth = textWidth

    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.35 * alpha)
    love.graphics.rectangle("fill", textX, cursorY, barWidth, barHeight)

    if progress > 0 then
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.9 * alpha)
        love.graphics.rectangle("fill", textX + 1, cursorY + 1, (barWidth - 2) * progress, barHeight - 2)
    end

    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * alpha)
    love.graphics.rectangle("line", textX + 0.5, cursorY + 0.5, barWidth - 1, barHeight - 1)

    cursorY = cursorY + barHeight + 4

    local progressFont = fonts.tiny or metaFont
    love.graphics.setFont(progressFont)
    local percentText = string.format("%d%%", math.floor(progress * 100 + 0.5))
    local xpText = string.format("%d / %d XP", xpAfter, xpRequired)

    love.graphics.setColor(mutedColor[1], mutedColor[2], mutedColor[3], alpha)
    love.graphics.print(percentText, textX, cursorY)
    love.graphics.printf(xpText, textX, cursorY, textWidth, "right")

    love.graphics.pop()
end

return ExperiencePanel
