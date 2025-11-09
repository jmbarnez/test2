local Transport = require("src.network.transport")
local Snapshot = require("src.network.snapshot")
local PlayerManager = require("src.player.manager")
local UIStateManager = require("src.ui.state_manager")
local Intent = require("src.input.intent")
local Prediction = require("src.network.prediction")
local json = require("libs.json")

local love = love

local NetworkManager = {}
NetworkManager.__index = NetworkManager

local function encode_message(message)
    local ok, result = pcall(json.encode, message)
    if ok then
        return result
    end
end

local function decode_message(data)
    local ok, decoded = pcall(json.decode, data)
    if ok then
        return decoded
    end
end

local function format_address(host, port)
    host = host or "127.0.0.1"
    port = type(port) == "number" and port or (tonumber(port) or 22122)
    return string.format("%s:%d", host, port)
end

function NetworkManager.new(config)
    config = config or {}
    local constants = require("src.constants.game")

    local self = setmetatable({
        state = assert(config.state, "NetworkManager requires a gameplay state reference"),
        snapshotInterval = config.snapshotInterval or (1.0 / (constants.network.snapshot_rate or 10)),
        intentInterval = config.intentInterval or (1.0 / (constants.network.intent_rate or 20)),
        snapshotTimer = 0,
        intentTimer = 0,
        connected = false,
        host = config.host or "127.0.0.1",
        port = tonumber(config.port) or 22122,
    }, NetworkManager)

    self.client = Transport.createClient({
        host = self.host,
        port = self.port,
        channels = config.channels or 2,
        onConnect = function(peer)
            self.connected = true
            Prediction.initialize(self.state)
            if config.onConnect then
                config.onConnect(peer)
            end
        end,
        onDisconnect = function(peer, code)
            self.connected = false
            if config.onDisconnect then
                config.onDisconnect(peer, code)
            end
        end,
        onReceive = function(data, channel)
            self:handleMessage(data, channel)
        end,
        onTimeout = function(peer)
            self.connected = false
            if config.onTimeout then
                config.onTimeout(peer)
            end
        end,
    })

    if config.autoConnect ~= false then
        self:connect()
    end

    return self
end

function NetworkManager:connect()
    if self.client then
        self.client.address = format_address(self.host, self.port)
        self.client:connect()
    end
end

function NetworkManager:disconnect(code)
    if self.client and self.client.peer then
        self.client:disconnect(code)
    end
    self.connected = false
end

function NetworkManager:shutdown()
    self:disconnect()
    if self.client and self.client.host then
        pcall(function() self.client.host:destroy() end)
    end
    self.client = nil
end

function NetworkManager:handleMessage(data, _channel)
    local message = decode_message(data)
    if type(message) ~= "table" or not message.type then
        return
    end

    if message.type == "player_assigned" and message.playerId then
        self.state.localPlayerId = message.playerId

        local localShip = PlayerManager.getCurrentShip(self.state)
        if localShip then
            localShip.playerId = message.playerId
            PlayerManager.attachShip(self.state, localShip, nil, message.playerId)
        end
        Intent.ensure(self.state, message.playerId)
    elseif message.type == "snapshot" and message.payload then
        -- Server reconciliation for local player
        if message.payload.players and self.state.localPlayerId then
            local serverPlayerData = message.payload.players[self.state.localPlayerId]
            if serverPlayerData then
                Prediction.reconcile(self.state, serverPlayerData, message.payload.tick or 0)
            end
        end
        
        Snapshot.apply(self.state, message.payload)
    elseif message.type == "intent" and message.playerId and message.payload then
        self:applyRemoteIntent(message.playerId, message.payload)
    elseif message.type == "chat" and message.payload then
        local text = message.payload.text
        if type(text) == "string" and text ~= "" then
            UIStateManager.addChatMessage(self.state, message.playerId or "server", text)
        end
    end
end

function NetworkManager:applyRemoteIntent(playerId, payload)
    local container = Intent.ensureContainer(self.state)
    if not container then
        return
    end

    local intent = container[playerId]
    if not intent then
        intent = {}
        container[playerId] = intent
    end

    intent.moveX = payload.moveX or 0
    intent.moveY = payload.moveY or 0
    intent.moveMagnitude = payload.moveMagnitude or 0
    intent.aimX = payload.aimX or intent.aimX or 0
    intent.aimY = payload.aimY or intent.aimY or 0
    intent.hasAim = payload.hasAim ~= nil and payload.hasAim or (intent.hasAim or false)
    intent.firePrimary = payload.firePrimary or false
    intent.fireSecondary = payload.fireSecondary or false
end

function NetworkManager:sendSnapshot()
    if not self.connected or not self.client then
        return
    end

    local snapshot = Snapshot.capture(self.state)
    if not snapshot then
        return
    end

    local payload = encode_message({
        type = "snapshot",
        payload = snapshot,
    })

    if payload then
        self.client:send(payload, 0, true)
    end
end

function NetworkManager:sendLocalIntent()
    if not self.connected or not self.client or not self.state.localPlayerId then
        return
    end

    local intents = self.state.playerIntents
    local intent = intents and intents[self.state.localPlayerId]
    if not intent then
        return
    end

    -- Record input for client-side prediction
    Prediction.recordInput(self.state, intent)
    Prediction.recordState(self.state)

    local payload = encode_message({
        type = "intent",
        playerId = self.state.localPlayerId,
        payload = {
            moveX = intent.moveX,
            moveY = intent.moveY,
            moveMagnitude = intent.moveMagnitude,
            aimX = intent.aimX,
            aimY = intent.aimY,
            hasAim = intent.hasAim,
            firePrimary = intent.firePrimary,
            fireSecondary = intent.fireSecondary,
        },
    })

    if payload then
        self.client:send(payload, 0, true)
    end
end

function NetworkManager:update(dt)
    if not self.client then
        return
    end

    self.client:update(0)

    if not self.connected then
        return
    end

    self.intentTimer = self.intentTimer + dt
    if self.intentTimer >= self.intentInterval then
        self.intentTimer = self.intentTimer - self.intentInterval
        self:sendLocalIntent()
    end

    self.snapshotTimer = self.snapshotTimer + dt
    if self.snapshotTimer >= self.snapshotInterval then
        self.snapshotTimer = self.snapshotTimer - self.snapshotInterval
        self:sendSnapshot()
    end
end

function NetworkManager:sendChatMessage(text)
    if type(text) ~= "string" then
        return
    end

    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return
    end

    if self.connected and self.client and self.client.peer then
        local clipped = trimmed:sub(1, 200)
        local payload = encode_message({
            type = "chat",
            payload = {
                text = clipped,
            },
        })

        if payload then
            self.client:send(payload, 0, true)
        end
    else
        UIStateManager.addChatMessage(self.state, self.state and self.state.localPlayerId or "local", trimmed)
    end
end

function NetworkManager:setAddress(host, port)
    if host then
        self.host = host
    end
    if port then
        self.port = tonumber(port) or self.port
    end

    if self.client then
        self.client.address = format_address(self.host, self.port)
    end
end

function NetworkManager:getAddress()
    return self.host, self.port
end

return NetworkManager
