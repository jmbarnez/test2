local window = require("src.ui.window")
local theme = require("src.ui.theme")
local Server = require("src.network.server")
local PlayerManager = require("src.player.manager")
local constants = require("src.constants.game")
local tiny = require("libs.tiny")

local love = love

local multiplayer_window = {}

local function split_address(address)
    if type(address) ~= "string" then
        return constants.network.host, constants.network.port
    end

    local host, port = address:match("([^:]+):?(%d*)")
    host = host ~= "" and host or constants.network.host
    port = tonumber(port) or constants.network.port
    return host, port
end

local function format_address(host, port)
    return string.format("%s:%d", host or constants.network.host, tonumber(port) or constants.network.port)
end

local function draw_button(x, y, w, h, label, isActive)
    local theme_colors = theme.colors or {}
    local colors = theme_colors.button or {
        background = { 0.08, 0.12, 0.18, 0.95 },
        border = { 0.25, 0.45, 0.7, 1 },
        active_border = { 0.35, 0.65, 1, 1 },
        text = { 1, 1, 1, 0.92 },
    }

    colors.background = colors.background or { 0.08, 0.12, 0.18, 0.95 }
    colors.border = colors.border or { 0.25, 0.45, 0.7, 1 }
    colors.active_border = colors.active_border or { 0.35, 0.65, 1, 1 }
    colors.text = colors.text or { 1, 1, 1, 0.92 }

    local font = theme.get_fonts().body

    love.graphics.setFont(font)
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(isActive and colors.active_border or colors.border)
    love.graphics.setLineWidth(1.6)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 4, 4)

    love.graphics.setColor(colors.text)
    local textWidth = font:getWidth(label)
    local textHeight = font:getHeight()
    love.graphics.print(label, x + (w - textWidth) * 0.5, y + (h - textHeight) * 0.5)
end

local function handle_button(input, rect)
    if not input or not rect then
        return false
    end

    local mx, my = input.x, input.y
    local just_pressed = input.just_pressed

    if mx and my and mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h then
        if just_pressed then
            return true
        end
    end

    return false
end

local function draw_text_input(frame, context)
    local fonts = theme.get_fonts()
    love.graphics.setFont(fonts.body)

    local state = context.multiplayerUI
    state.inputActive = state.inputActive or false

    local label = "Server Address"
    local labelY = frame.content.y + 6
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(label, frame.content.x, labelY)

    local inputY = labelY + fonts.body:getHeight() + 6
    local inputHeight = 28
    local inputWidth = frame.content.width

    local mx, my = love.mouse.getPosition()
    local hovered = mx >= frame.content.x and mx <= frame.content.x + inputWidth and my >= inputY and my <= inputY + inputHeight

    if state._requestInputActivate then
        state.inputActive = true
        state._requestInputActivate = nil
    end

    local active = state.inputActive

    love.graphics.setColor(active and 0.2 or 0.1, 0.2, 0.3, 0.75)
    love.graphics.rectangle("fill", frame.content.x, inputY, inputWidth, inputHeight, 4, 4)
    love.graphics.setColor(active and 0.6 or (hovered and 0.4 or 0.25), 0.8, 1, 0.9)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", frame.content.x + 0.5, inputY + 0.5, inputWidth - 1, inputHeight - 1, 4, 4)

    local caret = ""
    if active and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        caret = "_"
    end

    love.graphics.setColor(1, 1, 1, 1)
    local display = (state.addressInput or format_address(constants.network.host, constants.network.port)) .. caret
    love.graphics.print(display, frame.content.x + 8, inputY + (inputHeight - fonts.body:getHeight()) * 0.5)

    return {
        x = frame.content.x,
        y = inputY,
        w = inputWidth,
        h = inputHeight,
    }, active, hovered
end

local function ensure_status(state, message)
    state.status = message or state.status or ""
end

local function close_text_input(state)
    state.inputActive = false
    love.keyboard.setTextInput(false)
end

local function get_manager(context)
    return context and context.networkManager
end

local function set_status(state, text)
    state.status = text or ""
end

local function host_game(context)
    local state = context.multiplayerUI
    local host, port = split_address(state.addressInput or "")
    state.addressInput = format_address(host, port)
    close_text_input(state)

    if context.networkServer then
        context.networkServer:shutdown()
        context.networkServer = nil
    end

    -- Disconnect any existing client connection first
    local manager = get_manager(context)
    if manager then
        manager:disconnect()
    end

    -- Remove any existing local ship to avoid duplicates when switching roles
    local currentShip = PlayerManager.getCurrentShip(context)
    if currentShip then
        if currentShip.body and not currentShip.body:isDestroyed() then
            currentShip.body:destroy()
        end
        if context.world then
            pcall(function() context.world:remove(currentShip) end)
        end
        PlayerManager.clearShip(context, currentShip)
    end

    local ok, err = pcall(function()
        context.networkServer = Server.new({
            state = context,
            host = host,
            port = port,
        })
    end)

    if not ok then
        set_status(state, string.format("Host failed: %s", tostring(err)))
        context.networkServer = nil
        return
    end

    -- Listen-server: also connect as a client to unify flow
    context.netRole = 'server'
    if context.spawnerSystem then tiny.activate(context.spawnerSystem) end
    if context.enemySpawnerSystem then tiny.activate(context.enemySpawnerSystem) end
    if context.enemyAISystem then tiny.activate(context.enemyAISystem) end
    local manager = get_manager(context)
    if manager then
        manager:disconnect()
        manager:setAddress("127.0.0.1", port)
        pcall(function() manager:connect() end)
    end
    set_status(state, string.format("Hosting on %s:%d", host, port))
end

local function join_game(context)
    local state = context.multiplayerUI
    local host, port = split_address(state.addressInput or "")
    if not host or host == "" or host == "0.0.0.0" then
        host = "127.0.0.1"
    end
    state.addressInput = format_address(host, port)
    close_text_input(state)

    -- Joining as a client: ensure any local server is shut down
    if context.networkServer then
        context.networkServer:shutdown()
        context.networkServer = nil
    end

    -- Remove any existing local ship to avoid duplicates; server will spawn on connect
    local currentShip = PlayerManager.getCurrentShip(context)
    if currentShip then
        if currentShip.body and not currentShip.body:isDestroyed() then
            currentShip.body:destroy()
        end
        if context.world then
            pcall(function() context.world:remove(currentShip) end)
        end
        PlayerManager.clearShip(context, currentShip)
    end

    -- Mark role and deactivate server-only systems if present
    context.netRole = 'client'
    if context.spawnerSystem then tiny.deactivate(context.spawnerSystem) end
    if context.enemySpawnerSystem then tiny.deactivate(context.enemySpawnerSystem) end
    if context.enemyAISystem then tiny.deactivate(context.enemyAISystem) end
    context.worldSynced = false

    local manager = get_manager(context)
    if not manager then
        set_status(state, "Client manager unavailable")
        return
    end

    manager:disconnect()
    manager:setAddress(host, port)
    local ok, err = pcall(function()
        manager:connect()
    end)

    if not ok then
        set_status(state, string.format("Join failed: %s", tostring(err)))
        return
    end

    set_status(state, string.format("Connecting to %s:%d...", host, port))
end

local function process_requests(context)
    local state = context.multiplayerUI
    if state._hostRequested then
        state._hostRequested = nil
        host_game(context)
    end
    if state._joinRequested then
        state._joinRequested = nil
        join_game(context)
    end
end

function multiplayer_window.draw(context)
    if not context or not context.multiplayerUI then
        return false
    end

    local state = context.multiplayerUI
    if not state.visible then
        return
    end

    local fonts = theme.get_fonts()
    local width = 360
    local height = 220
    local x = (love.graphics.getWidth() - width) * 0.5
    local y = (love.graphics.getHeight() - height) * 0.5

    love.graphics.push("all")
    love.graphics.origin()

    local mouse_x, mouse_y = love.mouse.getPosition()
    local is_mouse_down = love.mouse.isDown(1)
    local just_pressed = is_mouse_down and not state._was_mouse_down
    state._was_mouse_down = is_mouse_down

    local frame = window.draw_frame {
        x = x,
        y = y,
        width = width,
        height = height,
        title = "Multiplayer",
        fonts = fonts,
        state = state,
        input = {
            x = mouse_x,
            y = mouse_y,
            is_down = is_mouse_down,
            just_pressed = just_pressed,
        },
    }

    multiplayer_window.captureInput(context)

    local inputRect, inputActive, hovered = draw_text_input(frame, context)

    if hovered and just_pressed then
        state.inputActive = true
        if context.uiInput then
            context.uiInput.keyboardCaptured = true
        end
    elseif not hovered and just_pressed then
        state.inputActive = false
    end

    local buttonWidth = (frame.content.width - 12) * 0.5
    local buttonHeight = 32
    local buttonY = inputRect.y + inputRect.h + 16

    local hostRect = {
        x = frame.content.x,
        y = buttonY,
        w = buttonWidth,
        h = buttonHeight,
    }
    local joinRect = {
        x = frame.content.x + buttonWidth + 12,
        y = buttonY,
        w = buttonWidth,
        h = buttonHeight,
    }

    draw_button(hostRect.x, hostRect.y, hostRect.w, hostRect.h, "Host", false)
    draw_button(joinRect.x, joinRect.y, joinRect.w, joinRect.h, "Join", false)

    if handle_button({ x = mouse_x, y = mouse_y, just_pressed = just_pressed }, hostRect) then
        state._hostRequested = true
    elseif handle_button({ x = mouse_x, y = mouse_y, just_pressed = just_pressed }, joinRect) then
        state._joinRequested = true
    end

    ensure_status(state)
    if state.status ~= "" then
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setFont(fonts.small)
        love.graphics.print(state.status, frame.content.x, buttonY + buttonHeight + 16)
    end

    if inputActive then
        love.keyboard.setTextInput(true)
    else
        love.keyboard.setTextInput(false)
    end

    process_requests(context)

    if frame.close_clicked then
        state.visible = false
        state.dragging = false
        close_text_input(state)
    end

    love.graphics.pop()
end

function multiplayer_window.textinput(context, text)
    if not context or not context.multiplayerUI then
        return
    end

    local state = context.multiplayerUI
    if not state.visible or not state.inputActive then
        return
    end

    state.addressInput = (state.addressInput or "") .. text
end

function multiplayer_window.keypressed(context, key)
    if not context or not context.multiplayerUI then
        return
    end

    local state = context.multiplayerUI
    if not state.visible then
        if key == "f5" then
            state.visible = true
            if not state.addressInput or state.addressInput == "" then
                state.addressInput = format_address("127.0.0.1", constants.network.port)
            end
            ensure_status(state, "")
            return true
        end
        return false
    end

    if key == "escape" then
        state.visible = false
        love.keyboard.setTextInput(false)
        return true
    end

    if key == "backspace" and state.inputActive then
        local str = state.addressInput or ""
        state.addressInput = str:sub(1, #str - 1)
        return true
    end

    if key == "f5" then
        state.visible = false
        love.keyboard.setTextInput(false)
        return
    end

    if key == "return" and state.inputActive then
        state.inputActive = false
        love.keyboard.setTextInput(false)
        return true
    end

    return false
end

function multiplayer_window.captureInput(context)
    if not context or not context.multiplayerUI then
        return
    end
    if context.uiInput then
        context.uiInput.mouseCaptured = true
        if context.multiplayerUI.inputActive then
            context.uiInput.keyboardCaptured = true
        end
    end
end

function multiplayer_window.parseAddress(address)
    return split_address(address)
end

function multiplayer_window.formatAddress(host, port)
    return format_address(host, port)
end

return multiplayer_window
