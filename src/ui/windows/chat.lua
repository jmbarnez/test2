local theme = require("src.ui.theme")
local UIStateManager = require("src.ui.state_manager")
local utf8 = require("utf8")

local love = love

local chat_window = {}

local WINDOW_WIDTH = 360
local WINDOW_MARGIN = 16
local BACKGROUND_COLOR = { 0, 0, 0, 0.35 }
local BORDER_COLOR = { 1, 1, 1, 0.12 }
local INPUT_BACKGROUND_COLOR = { 1, 1, 1, 0.18 }
local INPUT_BORDER_COLOR_ACTIVE = { 1, 1, 1, 0.85 }
local INPUT_BORDER_COLOR_INACTIVE = { 1, 1, 1, 0.5 }
local TEXT_COLOR = { 1, 1, 1, 0.92 }
local PADDING = 8
local MAX_MESSAGE_LENGTH = 200
local MESSAGE_FADE_DURATION = 8.0
local MESSAGE_FADE_TIME = 2.0

local function get_chat_state(context)
    return context and context.chatUI
end

local function draw_text_with_glow(text, x, y, wrapWidth, align, color, alpha)
    local r = color[1] or TEXT_COLOR[1]
    local g = color[2] or TEXT_COLOR[2]
    local b = color[3] or TEXT_COLOR[3]
    local baseAlpha = (color[4] or TEXT_COLOR[4]) * alpha

    local glowAlpha = baseAlpha * 0.45
    local glowR = math.min(r * 1.2 + 0.08, 1)
    local glowG = math.min(g * 1.2 + 0.08, 1)
    local glowB = math.min(b * 1.2 + 0.08, 1)
    local offsets = {
        { -1.5, 0 },
        { 1.5, 0 },
        { 0, -1.5 },
        { 0, 1.5 },
    }

    love.graphics.setColor(glowR, glowG, glowB, glowAlpha)
    for i = 1, #offsets do
        local off = offsets[i]
        love.graphics.printf(text, x + off[0 + 1], y + off[1 + 1], wrapWidth, align)
    end

    local baseR = math.min(r * 0.5 + 0.5, 1)
    local baseG = math.min(g * 0.5 + 0.5, 1)
    local baseB = math.min(b * 0.5 + 0.5, 1)
    love.graphics.setColor(baseR, baseG, baseB, baseAlpha)
    love.graphics.printf(text, x, y, wrapWidth, align)
end

local function set_text_input_enabled(enabled)
    if love and love.keyboard and love.keyboard.setTextInput then
        love.keyboard.setTextInput(enabled)
    end
end

local function format_timestamp(timestamp)
    if not timestamp then
        return ""
    end
    local time = os.date("*t", timestamp)
    return string.format("[%02d:%02d]", time.hour, time.min)
end

local function calculate_message_alpha(message, currentTime)
    if not message.timestamp or not currentTime then
        return 1.0
    end
    
    local age = currentTime - message.timestamp
    if age < MESSAGE_FADE_DURATION then
        return 1.0
    end
    
    local fadeAge = age - MESSAGE_FADE_DURATION
    if fadeAge >= MESSAGE_FADE_TIME then
        return 0.0
    end
    
    return 1.0 - (fadeAge / MESSAGE_FADE_TIME)
end

local function collect_wrapped_lines(font, messages, maxVisible, wrapWidth, currentTime)
    if not font then
        return {}
    end

    local lines = {}
    local messageCount = #messages
    if messageCount == 0 then
        return lines
    end

    local startIndex = math.max(1, messageCount - (maxVisible or messageCount) + 1)
    for i = startIndex, messageCount do
        local message = messages[i]
        if message then
            local alpha = calculate_message_alpha(message, currentTime)
            if alpha > 0.01 then
                local author = message.playerId or "?"
                local text = message.text or ""
                local timestamp = format_timestamp(message.timestamp)
                local combined = string.format("%s %s: %s", timestamp, author, text)
                local color = message.color
                local _, wrapped = font:getWrap(combined, wrapWidth)
                for j = 1, #wrapped do
                    lines[#lines + 1] = {
                        text = wrapped[j],
                        alpha = alpha,
                        color = color,
                    }
                end
            end
        end
    end

    return lines
end

local function trim_text(text)
    if type(text) ~= "string" then
        return ""
    end
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if #trimmed > MAX_MESSAGE_LENGTH then
        trimmed = trimmed:sub(1, MAX_MESSAGE_LENGTH)
    end
    return trimmed
end

local function send_chat_message(context, rawText)
    local trimmed = trim_text(rawText)
    if trimmed == "" then
        return
    end

    local sent = false

    local manager = context and context.networkManager
    if manager and manager.sendChatMessage and manager.connected then
        manager:sendChatMessage(trimmed)
        sent = true
    end

    local server = context and context.networkServer
    if server and server.handleChatMessage then
        local author = (context and context.localPlayerId)
            or (context and context.player and context.player.playerId)
        server:handleChatMessage(author, trimmed)
        sent = true
    end

    if not sent then
        UIStateManager.addChatMessage(context, (context and context.localPlayerId) or "local", trimmed)
    end
end

function chat_window.draw(context)
    local state = get_chat_state(context)
    if not (state and state.visible) then
        return
    end

    local messages = state.messages or {}
    local showInput = state.inputActive or (state.inputBuffer and state.inputBuffer ~= "")

    local fonts = theme.get_fonts()
    local font = fonts.small or fonts.body
    if not font then
        return
    end

    local currentTime = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local width = state.width or WINDOW_WIDTH
    local wrapWidth = width - PADDING * 2
    local lines = collect_wrapped_lines(font, messages, state.maxVisible or 6, wrapWidth, currentTime)
    local hasMessages = #lines > 0

    if not hasMessages then
        lines = { { text = "Press Enter to chat", alpha = 0.55, color = TEXT_COLOR } }
    end

    local lineHeight = font:getHeight()
    local inputHeight = showInput and (lineHeight + PADDING) or 0
    local totalHeight = (#lines * lineHeight) + inputHeight + PADDING * 2
    if totalHeight < lineHeight + PADDING * 2 then
        totalHeight = lineHeight + PADDING * 2
    end

    local bottomY = love.graphics.getHeight() - WINDOW_MARGIN
    local x = WINDOW_MARGIN
    local y = bottomY - totalHeight

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setFont(font)

    love.graphics.setColor(BACKGROUND_COLOR)
    love.graphics.rectangle("fill", x, y, width, totalHeight, 6, 6)

    love.graphics.setColor(BORDER_COLOR)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, totalHeight - 1, 6, 6)

    local textBottom = bottomY - PADDING - inputHeight
    local currentY = textBottom

    for i = #lines, 1, -1 do
        currentY = currentY - lineHeight
        local line = lines[i]
        local lineText = type(line) == "table" and line.text or line
        local lineAlpha = type(line) == "table" and line.alpha or 1.0
        local lineColor = type(line) == "table" and line.color or nil
        local baseColor = lineColor or TEXT_COLOR
        draw_text_with_glow(lineText, x + PADDING, currentY, wrapWidth, "left", baseColor, lineAlpha)
    end

    if showInput then
        local inputBoxY = bottomY - PADDING - inputHeight + PADDING * 0.5
        local caret = ""
        if state.inputActive and love.timer and love.timer.getTime then
            if math.floor(love.timer.getTime() * 2) % 2 == 0 then
                caret = "_"
            end
        end

        local display = state.inputBuffer or ""
        if state.inputActive then
            display = display .. caret
        end

        love.graphics.setColor(INPUT_BACKGROUND_COLOR)
        love.graphics.rectangle("fill", x + PADDING, inputBoxY, wrapWidth, lineHeight + PADDING * 0.5, 4, 4)

        love.graphics.setColor(state.inputActive and INPUT_BORDER_COLOR_ACTIVE or INPUT_BORDER_COLOR_INACTIVE)
        love.graphics.rectangle("line", x + PADDING - 1, inputBoxY - 1, wrapWidth + 2, lineHeight + PADDING * 0.5 + 2, 4, 4)

        love.graphics.setColor(TEXT_COLOR)
        love.graphics.printf(display, x + PADDING + 4, inputBoxY + (PADDING * 0.25), wrapWidth - 8, "left")
    end

    love.graphics.pop()

    if context and context.uiInput and state.inputActive then
        context.uiInput.keyboardCaptured = true
    end
end

function chat_window.textinput(context, text)
    local state = get_chat_state(context)
    if not (state and state.visible and state.inputActive) then
        return false
    end

    state.inputBuffer = (state.inputBuffer or "") .. text
    if #state.inputBuffer > MAX_MESSAGE_LENGTH then
        state.inputBuffer = state.inputBuffer:sub(1, MAX_MESSAGE_LENGTH)
    end

    return true
end

function chat_window.keypressed(context, key)
    local state = get_chat_state(context)
    if not (state and state.visible) then
        return false
    end

    if UIStateManager.isDeathUIVisible and UIStateManager.isDeathUIVisible(context) and not state.inputActive then
        return false
    end

    if key == "return" or key == "kpenter" then
        if state.inputActive then
            local buffer = state.inputBuffer or ""
            state.inputBuffer = ""
            state.inputActive = false
            set_text_input_enabled(false)
            send_chat_message(context, buffer)
        else
            state.inputActive = true
            set_text_input_enabled(true)
            if context and context.uiInput then
                context.uiInput.keyboardCaptured = true
            end
        end
        return true
    elseif key == "backspace" then
        if state.inputActive then
            local buffer = state.inputBuffer or ""
            local byteoffset = utf8.offset(buffer, -1)
            if byteoffset then
                state.inputBuffer = buffer:sub(1, byteoffset - 1)
            end
            return true
        end
    elseif key == "escape" then
        if state.inputActive then
            state.inputBuffer = ""
            state.inputActive = false
            set_text_input_enabled(false)
            return true
        end
    end

    return false
end

return chat_window
